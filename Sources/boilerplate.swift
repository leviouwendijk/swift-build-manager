import Foundation

enum Alignment {
    case left
    case right
}

protocol Alignable {
    func align(_ side: Alignment,_ width: Int) -> String
}

extension String: Alignable {
    func align(_ side: Alignment,_ width: Int) -> String {
        let padding = max(0, width - self.count)

        switch side {
        case .left:
            let paddedText = self + String(repeating: ".", count: padding)
            return paddedText
        case .right:
            let paddedText = String(repeating: ".", count: padding) + self
            return paddedText
        }
    }
}

struct Subcommand {
    let command: String
    let details: String
}

let commandWidth = 40
let detailsWidth = 60

extension Subcommand: CustomStringConvertible {
    var description: String {
        command.align(.left, commandWidth) + details.align(.right, detailsWidth) 
    }
}

enum ANSIColor: String {
    case reset = "\u{001B}[0m"
    case bold = "\u{001B}[1m"
    case dim = "\u{001B}[2m"
    case italic = "\u{001B}[3m"
    case underline = "\u{001B}[4m"
    case black = "\u{001B}[30m"
    case red = "\u{001B}[31m"
    case green = "\u{001B}[32m"
    case yellow = "\u{001B}[33m"
    case blue = "\u{001B}[34m"
    case magenta = "\u{001B}[35m"
    case cyan = "\u{001B}[36m"
    case white = "\u{001B}[37m"
    case brightBlack = "\u{001B}[90m" // or gray
    case brightRed = "\u{001B}[91m"
    case brightGreen = "\u{001B}[92m"
    case brightYellow = "\u{001B}[93m"
    case brightBlue = "\u{001B}[94m"
    case brightMagenta = "\u{001B}[95m"
    case brightCyan = "\u{001B}[96m"
    case brightWhite = "\u{001B}[97m"
}

protocol StringANSIFormattable {
    func ansi(_ colors: ANSIColor...) -> String
}

extension String: StringANSIFormattable {
    func ansi(_ colors: ANSIColor...) -> String {
        let colorCodes = colors.map { $0.rawValue }.joined()
        return "\(colorCodes)\(self)\(ANSIColor.reset.rawValue)"
    }
}

protocol Returnable {
    mutating func rtn(_ repetitions: Int)
}

extension String: Returnable {
    mutating func rtn(_ repetitions: Int = 1) {
        for _ in 0..<repetitions {
            self.append("\n")
        }
    }
}


