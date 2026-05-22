//
//  Tree+prettyPrint.swift
//  CodeEditSourceEditor
//
//  Created by Khan Winter on 3/16/23.
//

import SwiftTreeSitter

#if DEBUG
private func prettyPrintTree(rootNode: Node?) {
    guard let cursor = rootNode?.treeCursor else {
        print("NO ROOT NODE")
        return
    }
    guard cursor.currentNode != nil else {
        print("NO CURRENT NODE")
        return
    }

    func p(_ cursor: TreeCursor, depth: Int) {
        guard let node = cursor.currentNode else {
            return
        }

        let visible = node.isNamed

        if visible {
            print(String(repeating: " ", count: depth * 2), terminator: "")
            if let fieldName = cursor.currentFieldName {
                print(fieldName, ": ", separator: "", terminator: "")
            }
            print("(", node.nodeType ?? "NONE", " ", node.range, " ", separator: "", terminator: "")
        }

        if cursor.goToFirstChild() {
            while true {
                if cursor.currentNode != nil && cursor.currentNode!.isNamed {
                    print("")
                }

                p(cursor, depth: depth + 1)

                if !cursor.gotoNextSibling() {
                    break
                }
            }

            if !cursor.gotoParent() {
                fatalError("Could not go to parent, this tree may be invalid.")
            }
        }

        if visible {
            print(")", terminator: depth == 1 ? "\n": "")
        }
    }

    if cursor.currentNode?.childCount == 0 {
        if !cursor.currentNode!.isNamed {
            print("{\(cursor.currentNode!.nodeType ?? "NONE")}")
        } else {
            print("\"\(cursor.currentNode!.nodeType ?? "NONE")\"")
        }
    } else {
        p(cursor, depth: 1)
    }
}

extension Tree {
    func prettyPrint() {
        prettyPrintTree(rootNode: rootNode)
    }
}

extension MutableTree {
    func prettyPrint() {
        prettyPrintTree(rootNode: rootNode)
    }
}
#endif
