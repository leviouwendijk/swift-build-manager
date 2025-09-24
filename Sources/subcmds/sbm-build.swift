import ArgumentParser

import Foundation
import Executable

struct Build: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "build",
        abstract: "Build a Swift package (debug/release) and optionally deploy to '~/sbm-bin/'."
    )

    // removed release flag, default is release now

    @Flag(name: [.customShort("d"), .long], help: "Build in debug mode.")
    var debug = false

    @Flag(name: [.customShort("l"), .long], help: "Keep artifacts in .build (no deploy).")
    var local = false

    @Option(name: [.customShort("p"), .long], help: "Project directory (defaults to CWD).")
    var project: String?

    @Option(name: [.customShort("o"), .long], help: "Destination path for deployed binary (defaults to ~/sbm-bin).")
    var destination: String?

    // --- ADDITION: selection flags ---
    @Option(name: .long, parsing: .upToNextOption, help: "Deploy only these targets (comma-separated or repeatable).")
    var targets: [String] = []

    @Option(name: .long, parsing: .upToNextOption, help: "Skip these targets (comma-separated or repeatable).")
    var skipTargets: [String] = []

    @Flag(name: .long, help: "Deploy CLI-like targets only (name/path contains cli/tool/cmd).")
    var cliOnly = false

    @Flag(name: .long, help: "Keep app-like targets (name/path contains app/application).")
    var keepApps = false

    @Option(name: .long, parsing: .upToNextOption, help: "Per-target destination mapping 'name=/path'. Repeatable.")
    var map: [String] = []

    // no longer needed
    // func validate() throws {
    //     guard !(release && debug) else {
    //         throw ValidationError("Choose exactly one of --release/-r or --debug/-d.")
    //     }
    // }

    private func parseCSVish(_ values: [String]) -> [String] {
        values.flatMap { $0.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) } }
        .filter { !$0.isEmpty }
    }

    private func defaultSBMBin() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = "\(home)/sbm-bin"
        try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        return path
    }

    private func parseMap(_ pairs: [String]) -> [String: URL] {
        var out: [String: URL] = [:]
        for pair in pairs {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            out[parts[0]] = URL(fileURLWithPath: parts[1])
        }
        return out
    }

    func run() async throws {
        let dirURL = URL(fileURLWithPath: project ?? FileManager.default.currentDirectoryPath)
        let destRoot = URL(fileURLWithPath: destination ?? defaultSBMBin())
        let mode: Executable.Build.Config.Mode = (debug ? .debug : .release)
        let config = Executable.Build.Config(mode: mode)

        _ = try await Executable.Build.build(at: dirURL, config: config)
        guard !local else { return }

        let detailed = try await Executable.TargetsDetailed.list(in: dirURL)
        let allNames = detailed.map { $0.name }

        let included = parseCSVish(targets)
        let excluded = parseCSVish(skipTargets)

        var selected: [String]
        if !included.isEmpty {
            selected = allNames.filter { included.contains($0) }
        } else if cliOnly {
            selected = detailed.filter { $0.role == .cli }.map { $0.name }
        } else {
            selected = allNames
        }

        if keepApps {
            let apps = Set(detailed.filter { $0.role == .app }.map { $0.name })
            selected.removeAll { apps.contains($0) }
        }
        if !excluded.isEmpty {
            selected.removeAll { excluded.contains($0) }
        }

        let perMap = parseMap(map)

        try Executable.Deploy.selected(
            from: dirURL,
            config: config,
            to: destRoot,
            targets: selected,
            perTargetDestinations: perMap
        )
    }
}
