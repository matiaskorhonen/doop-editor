import Foundation

extension String {
    func getFirstLines(_ lines: Int = 1, maxLength: Int = 512) -> String {
        var string = ""
        var foundLines = 0
        var totalLength = 0
        for char in self.lazy {
            if char.isNewline {
                foundLines += 1
            }
            totalLength += 1
            if foundLines >= lines || totalLength >= maxLength {
                break
            }
            string.append(char)
        }
        return string
    }

    func getLastLines(_ lines: Int = 1, maxLength: Int = 512) -> String {
        var string = ""
        var foundLines = 0
        var totalLength = 0
        for char in self.lazy.reversed() {
            if char.isNewline {
                foundLines += 1
            }
            totalLength += 1
            if foundLines >= lines || totalLength >= maxLength {
                break
            }
            string = String(char) + string
        }
        return string
    }
}
