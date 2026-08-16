import Foundation
import plate
import ArgumentParser
import Executable
import Indentation
import Terminal

struct Build:
    AsyncParsableCommand
{
    static let configuration = CommandConfiguration(
        commandName: "build",
        abstract: "Build a Swift package (debug/release) and optionally deploy to '~/sbm-bin/'."
    )

    @Flag(
        name: [
            .customShort("d"),
            .long,
        ],
        help: "Build in debug mode."
    )
    var debug = false

    @Flag(
        name: [
            .customShort("l"),
            .long,
        ],
        help: "Keep artifacts in .build (no deploy)."
    )
    var local = false

    @Flag(
        name: [
            .customShort("r"),
            .long,
        ],
        help: "Keep artifacts in .build (no deploy)."
    )
    var repo = false

    @Flag(
        name: [.long],
        help: "Keep artifacts in .build (no deploy)."
    )
    var noMove = false

    @Option(
        name: [
            .customShort("p"),
            .long,
        ],
        help: "Project directory (defaults to CWD)."
    )
    var project: String?

    @Option(
        name: [
            .customShort("o"),
            .long,
        ],
        help: "Destination path for deployed binary (defaults to ~/sbm-bin)."
    )
    var destination: String?

    @Option(
        name: .long,
        parsing: .upToNextOption,
        help: "Deploy only these executable products (comma-separated or repeatable)."
    )
    var products: [String] = []

    @Option(
        name: .customLong("targets"),
        parsing: .upToNextOption,
        help: "Deprecated compatibility selector: select products by executable target name."
    )
    var legacyTargets: [String] = []

    @Option(
        name: .long,
        parsing: .upToNextOption,
        help: "Skip these executable products (comma-separated or repeatable)."
    )
    var skipProducts: [String] = []

    @Option(
        name: .customLong("skip-targets"),
        parsing: .upToNextOption,
        help: "Deprecated compatibility selector: skip products by executable target name."
    )
    var legacySkipTargets: [String] = []

    @Flag(
        name: .long,
        help: "Deploy products backed by CLI-like executable targets only."
    )
    var cliOnly = false

    @Flag(
        name: .long,
        help: "Keep products backed by app-like targets in .build instead of deploying them."
    )
    var keepApps = false

    @Option(
        name: .long,
        parsing: .upToNextOption,
        help: "Per-product destination mapping 'name=/path'. Legacy target names remain accepted."
    )
    var map: [String] = []

    @Flag(
        help: .hidden
    )
    var pklInvoked = false

    private func parseCSVish(
        _ values: [String]
    ) -> [String] {
        values
            .flatMap {
                $0
                    .split(
                        separator: ","
                    )
                    .map {
                        String($0)
                            .trimmingCharacters(
                                in: .whitespaces
                            )
                    }
            }
            .filter {
                !$0.isEmpty
            }
    }

    private func defaultSBMBin() -> String {
        let home =
            FileManager
                .default
                .homeDirectoryForCurrentUser
                .path

        let path =
            "\(home)/sbm-bin"

        try? FileManager.default.createDirectory(
            atPath: path,
            withIntermediateDirectories: true
        )

        return path
    }

    private func parseMap(
        _ pairs: [String]
    ) -> [String: URL] {
        var output: [String: URL] = [:]

        for pair in pairs {
            let parts = pair
                .split(
                    separator: "=",
                    maxSplits: 1
                )
                .map(
                    String.init
                )

            guard parts.count == 2 else {
                continue
            }

            output[
                parts[0]
            ] = URL(
                fileURLWithPath: parts[1]
            )
        }

        return output
    }

    func run() async throws {
        var effectiveArgv: [String] =
            InvocationArgs.argv
            ?? Array(
                CommandLine.arguments.dropFirst()
            )

        if !userProvidedAnyFlagsOrOptions() {
            if
                let pklURL = try? BuildObjectConfiguration
                    .traverseForBuildObjectPkl(
                        from: URL(
                            fileURLWithPath:
                                FileManager.default.currentDirectoryPath
                        )
                    ),
                let configuration = try? BuildObjectConfiguration(
                    from: pklURL
                ),
                !pklInvoked,
                configuration.compile.use == true
            {
                let quoted = configuration
                    .compile
                    .arguments
                    .map {
                        String(
                            reflecting: $0
                        )
                        .replacingOccurrences(
                            of: " ",
                            with: "( )"
                        )
                    }
                    .joined(
                        separator: " "
                    )

                print(
                    "Detected preconfigured build instructions, intercepting build commands."
                )

                printi(
                    "(You provided no overriding flags or options)."
                )

                print()

                printi(
                    "Arguments found: \(quoted)"
                )

                let command =
                    "sbm ".ansi(.bold)
                    + quoted.replacingOccurrences(
                        of: "\"",
                        with: ""
                    )

                printi(
                    "Invocation (simulated): \(command)"
                )

                var forwarded =
                    configuration.compile.arguments

                if
                    let first = forwarded.first?.lowercased(),
                    first == "build"
                        || first == "sbm"
                {
                    forwarded.removeFirst()
                }

                if !forwarded.contains(
                    "--pkl-invoked"
                ) {
                    forwarded.append(
                        "--pkl-invoked"
                    )
                }

                effectiveArgv = forwarded

                try await InvocationArgs.$argv.withValue(
                    forwarded
                ) {
                    let command = try Build.parse(
                        forwarded
                    )

                    try await command.run()
                }

                return
            }
        }

        let dirURL = URL(
            fileURLWithPath:
                project
                ?? FileManager.default.currentDirectoryPath
        )

        let destRoot = URL(
            fileURLWithPath:
                destination
                ?? defaultSBMBin()
        )

        let mode: Executable.Build.Config.Mode =
            debug
            ? .debug
            : .release

        let config = Executable.Build.Config(
            mode: mode
        )

        let executableProducts =
            try await Executable.Products.executables(
                in: dirURL
            )

        let detailedTargets =
            try await Executable.TargetsDetailed.list(
                in: dirURL
            )

        let targetRoles = Dictionary(
            uniqueKeysWithValues:
                detailedTargets.map {
                    (
                        $0.name,
                        $0.role
                    )
                }
        )

        let includedProductNames = Set(
            parseCSVish(
                products
            )
        )

        let includedLegacyTargetNames = Set(
            parseCSVish(
                legacyTargets
            )
        )

        let excludedProductNames = Set(
            parseCSVish(
                skipProducts
            )
        )

        let excludedLegacyTargetNames = Set(
            parseCSVish(
                legacySkipTargets
            )
        )

        let knownProductNames = Set(
            executableProducts.map(
                \.name
            )
        )

        let knownTargetNames = Set(
            executableProducts.flatMap(
                \.targets
            )
        )

        let unknownIncludedProducts =
            includedProductNames.subtracting(
                knownProductNames
            )

        guard unknownIncludedProducts.isEmpty else {
            throw ValidationError(
                """
                Unknown executable product(s): \
                \(unknownIncludedProducts.sorted().joined(separator: ", ")).
                """
            )
        }

        let unknownIncludedTargets =
            includedLegacyTargetNames.subtracting(
                knownTargetNames
            )

        guard unknownIncludedTargets.isEmpty else {
            throw ValidationError(
                """
                Unknown executable target(s): \
                \(unknownIncludedTargets.sorted().joined(separator: ", ")). \
                If this is a product name, use --products.
                """
            )
        }

        let unknownExcludedProducts =
            excludedProductNames.subtracting(
                knownProductNames
            )

        guard unknownExcludedProducts.isEmpty else {
            throw ValidationError(
                """
                Unknown executable product(s) in --skip-products: \
                \(unknownExcludedProducts.sorted().joined(separator: ", ")).
                """
            )
        }

        let unknownExcludedTargets =
            excludedLegacyTargetNames.subtracting(
                knownTargetNames
            )

        guard unknownExcludedTargets.isEmpty else {
            throw ValidationError(
                """
                Unknown executable target(s) in --skip-targets: \
                \(unknownExcludedTargets.sorted().joined(separator: ", ")).
                """
            )
        }

        var selectedProducts: [
            ExecutableProduct
        ]

        if
            !includedProductNames.isEmpty
            || !includedLegacyTargetNames.isEmpty
        {
            selectedProducts =
                executableProducts.filter {
                    product in

                    includedProductNames.contains(
                        product.name
                    )
                    || product.targets.contains {
                        includedLegacyTargetNames.contains(
                            $0
                        )
                    }
                }
        } else if cliOnly {
            selectedProducts =
                executableProducts.filter {
                    product in

                    product.targets.contains {
                        targetRoles[
                            $0
                        ] == .cli
                    }
                }
        } else {
            selectedProducts =
                executableProducts
        }

        if keepApps {
            selectedProducts.removeAll {
                product in

                product.targets.contains {
                    targetRoles[
                        $0
                    ] == .app
                }
            }
        }

        if
            !excludedProductNames.isEmpty
            || !excludedLegacyTargetNames.isEmpty
        {
            selectedProducts.removeAll {
                product in

                excludedProductNames.contains(
                    product.name
                )
                || product.targets.contains {
                    excludedLegacyTargetNames.contains(
                        $0
                    )
                }
            }
        }

        let selectedProductNames =
            selectedProducts.map(
                \.name
            )

        let rawDestinationMap =
            parseMap(
                map
            )

        var perProductDestinations: [
            String: URL
        ] = [:]

        for product in executableProducts {
            if let destination =
                rawDestinationMap[
                    product.name
                ]
            {
                perProductDestinations[
                    product.name
                ] = destination

                continue
            }

            for target in product.targets {
                guard let destination =
                    rawDestinationMap[
                        target
                    ]
                else {
                    continue
                }

                perProductDestinations[
                    product.name
                ] = destination

                break
            }
        }

        let usesDefaultProductSelection =
            includedProductNames.isEmpty
            && includedLegacyTargetNames.isEmpty
            && excludedProductNames.isEmpty
            && excludedLegacyTargetNames.isEmpty
            && !cliOnly
            && !keepApps

        let productSummary: String

        if usesDefaultProductSelection {
            productSummary =
                "all executable products"
        } else if selectedProductNames.isEmpty {
            productSummary =
                "none"
        } else {
            productSummary =
                selectedProductNames.joined(
                    separator: ", "
                )
        }

        let sourceSummary =
            pklInvoked
            ? "build-object.pkl"
            : "direct invocation"

        let banner = TerminalBlock(
            title:
                "Building \(dirURL.lastPathComponent)",
            fields: [
                TerminalField(
                    "mode",
                    config.buildDirComponent
                ),
                TerminalField(
                    "products",
                    productSummary
                ),
                TerminalField(
                    "project",
                    dirURL.path
                ),
                TerminalField(
                    "source",
                    sourceSummary
                ),
            ],
            theme: TerminalTheme(
                title: .bold,
                heading: .bold,
                label: .init(
                    .brightBlack
                ),
                value: .none,
                caption: .init(
                    .brightBlack
                ),
                success: .init(
                    .green
                ),
                warning: .init(
                    .yellow
                ),
                failure: .init(
                    .red
                ),
                cursor: .bold,
                disabled: .dim
            ),
            layout: TerminalBlockLayout(
                fieldIndent: 4,
                labelWidth: .fixed(
                    8
                ),
                labelValueSpacing: 2,
                blankLinesAfter: 0
            )
        )

        print()

        print(
            banner.render(
                stream: .standardOutput
            ),
            terminator: ""
        )

        print()

        fflush(
            stdout
        )

        _ = try await Executable.Build.build(
            at: dirURL,
            config: config,
            argv_audit: effectiveArgv
        )

        guard !local else {
            return
        }

        guard !repo else {
            return
        }

        guard !noMove else {
            return
        }

        try Executable.Deploy.selected(
            from: dirURL,
            config: config,
            to: destRoot,
            products: selectedProductNames,
            perProductDestinations:
                perProductDestinations
        )
    }
}

extension Build {
    private func userProvidedAnyFlagsOrOptions()
        -> Bool
    {
        debug
            || local
            || repo
            || noMove
            || project != nil
            || destination != nil
            || !products.isEmpty
            || !legacyTargets.isEmpty
            || !skipProducts.isEmpty
            || !legacySkipTargets.isEmpty
            || cliOnly
            || keepApps
            || !map.isEmpty
    }
}
