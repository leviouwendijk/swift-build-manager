import Foundation
import ArgumentParser
import Executable
import plate

struct RenewRepositories: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "renew-repositories",
        abstract: "Traverse a workspace and run ObjectRenewer on all detected Git repos.",
        aliases: ["renew", "rr"]
    )

    @Option(
        name: [.customShort("r"), .long],
        help: "Root directory to scan (defaults to current working directory)."
    )
    var root: String?

    @Option(
        name: .long,
        help: "Maximum directory depth to scan relative to root (0 = only root). Defaults to 6."
    )
    var maxDepth: Int = 6

    @Flag(
        name: .long,
        help: "Safe mode: do not discard local commits / dirty worktrees (only relevant if upstream criteria is enabled)."
    )
    var safe: Bool = false

    @Flag(
        name: .long,
        help: "Dry run: only list detected projects without updating them."
    )
    var dryRun: Bool = false

    func run() async throws {
        let fm = FileManager.default
        let rootPath = root ?? fm.currentDirectoryPath

        // avoid touching upstream, assuming you will use syncer for rsyncing
        let criteria = ObjectComparisonCriteria(
            upstream: false,
            compiled: true
        )

        print("RenewRepositories".ansi(.bold))
        print("Root: \(rootPath)".ansi(.brightBlack))
        print("Max depth: \(maxDepth)".ansi(.brightBlack))
        print("Safe mode: \(safe ? "ON".ansi(.yellow) : "off".ansi(.brightBlack))")
        print("Dry run: \(dryRun ? "ON".ansi(.yellow) : "off".ansi(.brightBlack))")
        print("Criteria: upstream=\(criteria.upstream), compiled=\(criteria.compiled)".ansi(.brightBlack))
        print()

        let objects = try ObjectRenewer.discover(
            rootPath: rootPath,
            maxDepth: maxDepth,
            criteria: criteria
        )

        if objects.isEmpty {
            print("No build-object.pkl projects detected under root.".ansi(.yellow))
            return
        }

        print("Discovered \(objects.count) projects:\n".ansi(.brightBlack))
        for obj in objects {
            let compDesc: String
            switch obj.compilable {
            case .some(true):  compDesc = "compilable"
            case .some(false): compDesc = "non-compilable"
            case .none:        compDesc = "compilable (default)"
            }

            print("• ".ansi(.brightBlack) + obj.path.ansi(.bold) + "  [\(compDesc)]".ansi(.brightBlack))
        }

        print()

        if dryRun {
            print("Dry run enabled; skipping ObjectRenewer.update().".ansi(.yellow))
            return
        }

        print("Running ObjectRenewer.update on discovered projects…".ansi(.brightBlack))
        print()

        try await ObjectRenewer.update(objects: objects, safe: safe)
    }
}
