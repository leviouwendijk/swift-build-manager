import Foundation

func getPackageName(from directory: String) -> String? {
    let packageSwiftPath = URL(fileURLWithPath: directory).appendingPathComponent("Package.swift").path
    guard let packageContents = try? String(contentsOfFile: packageSwiftPath) else {
        print("Error: Could not read Package.swift.".ansi(.red))
        return nil
    }

    let packageNameRegex = try! NSRegularExpression(pattern: #"name:\s*"([^"]+)""#, options: [])
    if let match = packageNameRegex.firstMatch(in: packageContents, options: [], range: NSRange(location: 0, length: packageContents.utf16.count)),
       let nameRange = Range(match.range(at: 1), in: packageContents) {
        return String(packageContents[nameRange])
    }

    return nil
}

func buildAndDeployLibrary(targetDirectory: String, buildType: BuildType, local: Bool) {
    let buildString = buildType.directoryString()

    guard let libraryName = getPackageName(from: targetDirectory) else {
        print("Error: Could not determine package name.".ansi(.red))
        // return
        exit(1)
    }

    let buildCommand = """
    swift build -c \(buildString) \
        -Xswiftc -enable-library-evolution \
        -Xswiftc -emit-module-interface-path \
        -Xswiftc .build/\(buildString)/Modules/\(libraryName).swiftinterface \
        -Xswiftc -emit-library \
        -Xswiftc -emit-module
    """
    print("Building library...")

    guard runShellCommand(buildCommand, in: targetDirectory) else {
        print("Error: Build failed.".ansi(.red))
        // return
        exit(1)
    }

    let modulePath = URL(fileURLWithPath: targetDirectory)
        .appendingPathComponent(".build/\(buildString)/Modules/")

    // let projectRoot = URL(fileURLWithPath: targetDirectory) // previous root

    let libRoot = URL(fileURLWithPath: targetDirectory)
        .appendingPathComponent(".build/\(buildString)/")  // Root where .dylib/.a are stored

    let baseModulesPath = URL(fileURLWithPath: setupSBMLibraryDirectory()).appendingPathComponent(libraryName)
    let fileManager = FileManager.default

    // Ensure the library's specific directory exists (INLINE CREATION)
    try? fileManager.createDirectory(atPath: baseModulesPath.path, withIntermediateDirectories: true)

    do {
        // Collect module files from `.build/.../Modules/`
        let moduleFiles = try fileManager.contentsOfDirectory(atPath: modulePath.path)
            .filter {
                $0.hasSuffix(".swiftmodule") || $0.hasSuffix(".swiftdoc") ||
                $0.hasSuffix(".abi.json") || $0.hasSuffix(".swiftsourceinfo") ||
                $0.hasSuffix(".swiftinterface")
            }

        // Collect library files from **project root**
        let libraryFiles = try fileManager.contentsOfDirectory(atPath: libRoot.path)
            .filter { $0.hasSuffix(".dylib") || $0.hasSuffix(".a") }

        guard !moduleFiles.isEmpty || !libraryFiles.isEmpty else {
            print("Error: No module or library files found.".ansi(.red))
            // return
            exit(1)
        }

        if !local {
            // Move module files
            for file in moduleFiles {
                let sourceURL = modulePath.appendingPathComponent(file)
                let destinationURL = baseModulesPath.appendingPathComponent(file)

                try? fileManager.removeItem(at: destinationURL)
                try fileManager.copyItem(at: sourceURL, to: destinationURL)

                print("Module file moved: \(file)".ansi(.brightBlack, .bold))
            }

            // Move library files
            for file in libraryFiles {
                let sourceURL = libRoot.appendingPathComponent(file)
                let destinationURL = baseModulesPath.appendingPathComponent(file)

                try? fileManager.removeItem(at: destinationURL)
                try fileManager.copyItem(at: sourceURL, to: destinationURL)

                print("Library file moved: \(file)".ansi(.brightBlack, .bold))
            }

            // Store metadata for tracking the library
            let metadataPath = baseModulesPath.appendingPathComponent("library.metadata")
            let metadataContent = "ProjectRootPath=\(targetDirectory)\n"
            try metadataContent.write(to: metadataPath, atomically: true, encoding: .utf8)
            print("Metadata file created at ".ansi(.brightBlack) + "\(metadataPath.path)".ansi(.brightBlack, .bold))
        } else {
            print("Build retained locally".ansi(.brightBlack))
        }

    } catch {
        print("Error: Could not move module or library files: \(error)".ansi(.red))
        // return
        exit(1)
    }

    print("\nLibrary build complete!".ansi(.green))
    if local {
        print("\n'\(libraryName)' is now locally available.".ansi(.green))
    } else {
        print("\nModules are now in sbm-bin/modules/\(libraryName)/.".ansi(.green))
    }
}
