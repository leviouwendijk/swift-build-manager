// updates older build-object.pkl legacyobjects to new build-object.pkl structure
import Foundation
import ArgumentParser
import plate

struct Modernize: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "modernize",
        abstract: "Upgrade legacy build-object.pkl to the new schema"
    )

    @Flag(name: .long, help: "Write a .bak file before overwriting")
    var backup: Bool = true

    func run() throws {
        let url = try BuildObjectConfiguration.traverseForBuildObjectPkl(
            from: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        )
        let text = try String(contentsOf: url, encoding: .utf8)
        let parser = PklParser(text)

        if let modern = try? parser.parseBuildObject() {
            print("Already modern: \(modern.name) (\(url.path))")
            return
        }

        parser.reset()

        print("Trying to parse legacy object…")
        let legacy = try parser.parseLegacyBuildObject()
        let modern = legacy.modernize()
        if backup {
            let bak = url.deletingPathExtension().appendingPathExtension("pkl.bak")
            try FileManager.default.copyItem(at: url, to: bak)
        }
        try modern.write(to: url)
        print("Modernized \(legacy.name) at \(url.path)")
    }
}
