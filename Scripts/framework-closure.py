#!/usr/bin/env python3
"""Resolve the set of frameworks that have to ship, by walking the actual link graph.

Anything a shipped framework loads at runtime has to ship too, and Xcode decides on its own
whether a SwiftPM dependency ends up absorbed into the framework that uses it or promoted to a
shared dynamic framework -- `InternalCollectionsUtilities` is absorbed when only
`CodeEditTextView` needs it and promoted once `CodeEditSourceEditor` needs it as well.
Discovering the set here means such a change breaks the build rather than the consumer.

Usage: framework-closure.py <installed-dir> <derived-build-dir> <root-module>...
Prints one tab-separated `name<TAB>path<TAB>comma,separated,deps` line per framework.
"""

import os
import re
import subprocess
import sys

RPATH = re.compile(r"@rpath/([A-Za-z_][A-Za-z0-9_]*)\.framework/")


def dependencies(path):
    binary = os.path.join(path, "Versions", "A",
                          os.path.basename(path).removesuffix(".framework"))
    if not os.path.exists(binary):
        binary = os.path.join(path, os.path.basename(path).removesuffix(".framework"))
    try:
        output = subprocess.run(["otool", "-L", binary], capture_output=True, text=True,
                                check=True).stdout
    except (subprocess.CalledProcessError, FileNotFoundError) as error:
        sys.exit("error: could not read the link graph of %s: %s" % (path, error))
    return sorted(set(RPATH.findall(output)))


def locate(name, installed, derived):
    # realpath throughout: Xcode's build products directory is full of symlinks into
    # UninstalledProducts, and a relative symlink breaks as soon as it is copied elsewhere.
    direct = os.path.join(installed, name + ".framework")
    if os.path.isdir(direct):
        return os.path.realpath(direct)
    # SwiftPM package products keep SKIP_INSTALL=YES, so a promoted one never reaches the
    # archive and has to be picked out of the build products instead.
    for base, dirs, _ in os.walk(derived):
        if os.path.basename(base) == "Release" and base.endswith(
                os.path.join("BuildProductsPath", "Release")):
            candidate = os.path.join(base, name + ".framework")
            if os.path.isdir(candidate):
                return os.path.realpath(candidate)
        dirs[:] = [d for d in dirs if not d.endswith(".framework")]
    return None


def main():
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    installed, derived = sys.argv[1], sys.argv[2]
    queue = list(sys.argv[3:])

    seen = []
    rows = []
    while queue:
        name = queue.pop(0)
        if name in seen:
            continue
        seen.append(name)

        path = locate(name, installed, derived)
        if path is None:
            sys.exit("error: %s.framework is loaded at runtime but was not built anywhere.\n"
                     "       Add it to the generated project, or stop the public API from "
                     "needing it." % name)

        deps = [d for d in dependencies(path) if d != name]
        queue.extend(deps)
        rows.append((name, path, ",".join(deps) or "-"))

    for row in rows:
        print("\t".join(row))


if __name__ == "__main__":
    main()
