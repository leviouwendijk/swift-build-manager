import Foundation

enum BuildType: String {
    case debug = "-d"
    case release = "-r"
    
    static func fromArgument(_ arg: String) -> BuildType? {
        switch arg.lowercased() {
        case "-d", "-debug":
            return .debug
        case "-r", "-release":
            return .release
        default:
            return nil
        }
    }
    
    func directoryString() -> String {
        switch self {
        case .debug:
            return "debug"
        case .release:
            return "release"
        }
    }
}

// Utility to run shell commands
@discardableResult
func runShellCommand(_ command: String, in directory: String = FileManager.default.currentDirectoryPath) -> Bool {
    let task = Process()
    task.launchPath = "/bin/bash"
    task.arguments = ["-c", command]
    task.currentDirectoryPath = directory
    
    let outputPipe = Pipe()
    task.standardOutput = outputPipe
    task.standardError = outputPipe
    
    let outputHandle = outputPipe.fileHandleForReading
    outputHandle.readabilityHandler = { fileHandle in
        // Read data as it becomes available
        let data = fileHandle.availableData
        if let output = String(data: data, encoding: .utf8)?.ansi(.brightBlack) {
            let colorizedOutput = output
                .replacingOccurrences(of: "production", with: "production".ansi(.bold))
                .replacingOccurrences(of: "debugging", with: "debugging".ansi(.bold))
                .replacingOccurrences(of: "error", with: "error".ansi(.red))
                .replacingOccurrences(of: "Build complete!", with: "Build complete!".ansi(.green))
                .replacingOccurrences(of: "warning", with: "warning".ansi(.yellow))
            print(colorizedOutput, terminator: "")
        }
    }
    
    task.launch()
    task.waitUntilExit()
    outputHandle.readabilityHandler = nil  // Remove the handler after the task exits
    
    return task.terminationStatus == 0
}

// Locate the executable target name from Package.swift based on package name or first available target
func getTargetNames(from directory: String) -> [String]? {
    let packageSwiftPath = URL(fileURLWithPath: directory).appendingPathComponent("Package.swift").path
    guard let packageContents = try? String(contentsOfFile: packageSwiftPath) else {
        print("Error: Could not read Package.swift.".ansi(.red))
        return nil
    }
    
    // Capture the package name
    let packageNameRegex = try! NSRegularExpression(pattern: #"name:\s*"([^"]+)""#, options: [])
    var packageName: String?
    if let packageMatch = packageNameRegex.firstMatch(in: packageContents, options: [], range: NSRange(location: 0, length: packageContents.utf16.count)),
       let nameRange = Range(packageMatch.range(at: 1), in: packageContents) {
        packageName = String(packageContents[nameRange])
    }
    print("Package identifier: ".ansi(.brightBlack) + "\(packageName ?? "nil")".ansi(.brightBlack, .bold))

    // Capture executable target names
    let targetNameRegex = try! NSRegularExpression(pattern: #"executableTarget\s*\(\s*name:\s*"([^"]+)""#, options: [])
    var targetNames: [String] = []
    targetNameRegex.enumerateMatches(in: packageContents, options: [], range: NSRange(location: 0, length: packageContents.utf16.count)) { match, _, _ in
        if let match = match, let targetRange = Range(match.range(at: 1), in: packageContents) {
            targetNames.append(String(packageContents[targetRange]))
        }
    }

    if targetNames.isEmpty {
        print("Error: No executable targets found in Package.swift.".ansi(.red))
        return nil
    }

    return targetNames
}

func removeBinaryAndMetadata(for targetDirectory: String, in destinationPath: String) {
    guard let targetNames = getTargetNames(from: targetDirectory) else {
        print("Error: Could not determine executable target names.".ansi(.red))
        return
    }
    
    for targetName in targetNames {
        let binaryPath = URL(fileURLWithPath: destinationPath).appendingPathComponent(targetName)
        let metadataPath = binaryPath.deletingLastPathComponent().appendingPathComponent("\(targetName).metadata")
        
        do {
            // Remove the binary
            if FileManager.default.fileExists(atPath: binaryPath.path) {
                try FileManager.default.removeItem(at: binaryPath)
                print("Removed binary: \(binaryPath.path)".ansi(.brightBlack, .bold))
            } else {
                print("Binary not found: \(binaryPath.path)".ansi(.yellow))
            }
            
            // Remove the metadata file
            if FileManager.default.fileExists(atPath: metadataPath.path) {
                try FileManager.default.removeItem(at: metadataPath)
                print("Removed metadata: \(metadataPath.path)".ansi(.brightBlack, .bold))
            } else {
                print("Metadata file not found: \(metadataPath.path)".ansi(.yellow))
            }
        } catch {
            print("Error: Failed to remove binary or metadata file: \(error)".ansi(.red))
        }
    }
}

func buildWithoutDeploy(targetDirectory: String, buildType: BuildType) {
    let buildCommand = buildType == .debug ? "swift build -c debug" : "swift build -c release"
    print("Building project locally...")
    guard runShellCommand(buildCommand, in: targetDirectory) else {
        print("Error: Build failed.".ansi(.red))
        return
    }
    print("")
    print("Build complete. Binary kept in project directory, and not moved to sbm-bin.".ansi(.green))
}

func buildAndDeploy(targetDirectory: String, buildType: BuildType, destinationPath: String) {
    let buildCommand = buildType == .debug ? "swift build -c debug" : "swift build -c release"
    print("Building project...")
    guard runShellCommand(buildCommand, in: targetDirectory) else {
        print("Error: Build failed.".ansi(.red))
        return
    }

    print("") 

    print("Moving binary to " + "sbm-bin".ansi(.italic) + "...")
    let projectFolderName = URL(fileURLWithPath: targetDirectory).lastPathComponent
    guard let targetNames = getTargetNames(from: targetDirectory) else {
        print("Error: Could not determine executable target names.".ansi(.red))
        return
    }
    
    for targetName in targetNames {
        print("")
        let buildPath = buildType == .debug ? ".build/debug/\(targetName)" : ".build/release/\(targetName)"
        let sourceURL = URL(fileURLWithPath: targetDirectory).appendingPathComponent(buildPath)
        let destinationURL = URL(fileURLWithPath: destinationPath).appendingPathComponent(targetName)
        
        // Step 3: Replace the binary at the destination path
        var binaryExists: Bool = false
        var binaryPlaced: Bool = false
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                binaryExists = true
                print("\(destinationURL.path)".ansi(.brightBlack, .bold) + " already exists. Replacing it...".ansi(.brightBlack))
            }
            
            if let replacedURL = try FileManager.default.replaceItemAt(destinationURL, withItemAt: sourceURL) {
                print("Binary ".ansi(.brightBlack) + ( binaryExists ? "re".ansi(.brightBlack) : "" ) + "placed at ".ansi(.brightBlack) + "\(replacedURL.path)".ansi(.bold, .brightBlack))
                binaryPlaced = true
            } else {
                print("Binary replaced, but no new URL was returned.".ansi(.brightBlack))
            }
        } catch {
            print("Error: Failed to replace binary at ".ansi(.brightBlack) + "\(destinationPath.ansi(.brightBlack, .bold)): \(error)".ansi(.red))
            return
        }
        
        // Step 4: Create metadata file with project root information
        let metadataPath = destinationURL.deletingLastPathComponent().appendingPathComponent("\(targetName).metadata")
        let metadataContent = "ProjectRootPath=\(targetDirectory)\n"
        
        do {
            try metadataContent.write(to: metadataPath, atomically: true, encoding: .utf8)
            print("Metadata file created at ".ansi(.brightBlack) + "\(metadataPath.path)".ansi(.brightBlack, .bold))
        } catch {
            print("Error: Failed to write metadata file: \(error)".ansi(.red))
            print("Ensure metadata is properly written! This ensures project root path is accessible to updates.".ansi(.red))
        }

        print("")

        let successOut = "\(targetName) ".ansi(.bold) + "is now an executable binary for " + "\(projectFolderName)".ansi(.italic)
        let successOutSpaced = """
                \(successOut)
            """
        let errorOut = "Failed to move \(targetName) binary to sbm-bin, retrace steps.".ansi(.red)

        binaryPlaced ? print(successOutSpaced) : print(errorOut)
    }
}

func cleanBuild(for targetDirectory: String) {
    let cleanCommand = "swift package clean"
    print("Cleaning build artifacts in project directory: \(targetDirectory)".ansi(.brightBlack))
    
    guard runShellCommand(cleanCommand, in: targetDirectory) else {
        print("")
        print("Error: Failed to clean build artifacts.".ansi(.red))
        return
    }

    print("")
    
    print("Clean successful!".ansi(.green))
}

struct Binary {
    let name: String
    let path: URL
    let metadata: [String: Any]? // Dictionary to hold metadata information
}

func getBinaries() -> [Binary] {
    var binaries: [Binary] = []

    let sbmBinariesLocation = URL(fileURLWithPath: setupSBMBinDirectory())
    
    let fileManager = FileManager.default
    do {
        let directoryContents = try fileManager.contentsOfDirectory(at: sbmBinariesLocation, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        
        let filenames = Set(directoryContents.map { $0.lastPathComponent })
        
        for fileURL in directoryContents {
            let fileName = fileURL.lastPathComponent
            guard !fileName.contains(".metadata") else { continue }
            
            let metadataFileName = "\(fileName).metadata"
            if filenames.contains(metadataFileName) {
                let metadataFileURL = sbmBinariesLocation.appendingPathComponent(metadataFileName)
                var metadata: [String: String]? = nil
                
                // Read and parse plain text metadata
                if let data = try? String(contentsOf: metadataFileURL) {
                    var parsedMetadata: [String: String] = [:]
                    data.split(separator: "\n").forEach { line in
                        let keyValue = line.split(separator: "=", maxSplits: 1)
                        if keyValue.count == 2 {
                            let key = String(keyValue[0]).trimmingCharacters(in: .whitespacesAndNewlines)
                            let value = String(keyValue[1]).trimmingCharacters(in: .whitespacesAndNewlines)
                            parsedMetadata[key] = value
                        }
                    }
                    metadata = parsedMetadata
                } else {
                    print("Warning: Failed to read metadata file for \(fileName).".ansi(.yellow))
                }
                
                let binary = Binary(name: fileName, path: fileURL, metadata: metadata)
                binaries.append(binary)
            }
        }
    } catch {
        print("Error reading contents of directory: \(error)".ansi(.red))
    }
    
    return binaries
}

enum Presentation {
    case list
    case detailed
}

func hasMetadataFile(_ metadata: [String: Any]?) -> Bool {
    return metadata != nil && !(metadata?.isEmpty ?? true)
}

func seeBinaries(_ presentation: Presentation) {
    let binaries = getBinaries()

    var output = ""

    switch presentation {
        case .detailed:
        for binary in binaries {
            output.append("\(binary.name)".ansi(.bold))
            output.rtn()
            output.append("\(binary.path)".ansi(.brightBlack))
            output.rtn()
            output.append("\(binary.metadata ?? ["Metadata": "NA"])".ansi(.brightBlack))
            output.rtn(2)
        }
        case .list:
        for binary in binaries {
            let binaryString = "\(binary.name)".ansi(.bold)
            let hasMetadata = hasMetadataFile(binary.metadata)
            let outputLine = hasMetadata
                ? binaryString
                : binaryString + " (missing \(binary.name).metadata)"
            output.append(outputLine)
            output.rtn()
        }
    }
    print(output)
}

func main() {
    print("")
    let arguments = CommandLine.arguments
    let firstArg = arguments.count >= 2 ? arguments[1] : ""

    switch firstArg { 
        case "-h", "-help":
        showAvailableCommands()


        case "-rm":
        let projectDirectory = arguments.count > 2 ? arguments[2] : FileManager.default.currentDirectoryPath
        let destinationPath = setupSBMBinDirectory()
        removeBinaryAndMetadata(for: projectDirectory, in: destinationPath)
        
        case "-clean":
        let projectDirectory = arguments.count > 2 ? arguments[2] : FileManager.default.currentDirectoryPath
        cleanBuild(for: projectDirectory)
        
        case "-bin":
        if arguments.count > 2 {
            let secondArg = arguments[2]

            if secondArg == "-detail" {
                seeBinaries(.detailed)
            }
        } else {
            seeBinaries(.list)
        }
        
        default: 
            guard arguments.count >= 2 else {
                print("Usage: sbm -d|-r [project-directory] [destination-path (optional)]")
                exit(1)
            }

            guard let buildType = BuildType.fromArgument(arguments[1]) else {
                print("Invalid build type. Use -d|-debug for debug or -r|-release for release.")
                exit(1)
            }

            let isLibraryBuild = arguments.contains("--lib") || arguments.contains("--library")
            let isLocalBuild = arguments.contains("-l") || arguments.contains("-local")
            
            // Determine the project directory and destination path
            let projectDirectory = arguments.count > 2 && arguments[2].first != "-" ? arguments[2] : FileManager.default.currentDirectoryPath
            let destinationPath = arguments.count > 3 ? arguments[3] : setupSBMBinDirectory()

            if isLibraryBuild {
                if isLocalBuild {
                    buildAndDeployLibrary(targetDirectory: projectDirectory, buildType: buildType, local: false)
                } else {
                    buildAndDeployLibrary(targetDirectory: projectDirectory, buildType: buildType, local: true)
                }
            } else {
                if isLocalBuild {
                    buildWithoutDeploy(targetDirectory: projectDirectory, buildType: buildType)
                } else {
                    buildAndDeploy(targetDirectory: projectDirectory, buildType: buildType, destinationPath: destinationPath)
                }
            }
    }
    print("")
}

main()
