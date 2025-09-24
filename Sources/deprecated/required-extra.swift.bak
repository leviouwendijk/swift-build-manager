import Foundation

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

