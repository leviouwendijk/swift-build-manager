import Foundation
import ArgumentParser

enum InvocationArgs {
    @TaskLocal static var argv: [String]? = nil
}

// if not in tasklocal:
enum CLI {
    static let argv: [String] = Array(CommandLine.arguments.dropFirst()) // trim sbm
}

