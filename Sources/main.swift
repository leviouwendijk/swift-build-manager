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
}

// Utility to run shell commands
@discardableResult
func runShellCommand(_ command: String, in directory: String = FileManager.default.currentDirectoryPath) -> Bool {
    let task = Process()
    task.launchPath = "/bin/bash"
    task.arguments = ["-c", command]
    task.currentDirectoryPath = directory
    task.launch()
    task.waitUntilExit()
    
    return task.terminationStatus == 0
}

func setupSBMBinDirectory() -> String {
    let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
    let sbmBinPath = homeDirectory.appendingPathComponent("sbm-bin").path

    // Step 1: Create sbm-bin if it doesn't exist
    if !FileManager.default.fileExists(atPath: sbmBinPath) {
        do {
            try FileManager.default.createDirectory(atPath: sbmBinPath, withIntermediateDirectories: true, attributes: nil)
            print("Created sbm-bin directory at \(sbmBinPath)")
        } catch {
            print("Error: Could not create sbm-bin directory: \(error)")
            exit(1)
        }
    }

    // Step 2: Check if sbm-bin is in PATH, and add it if not
    let shellConfigPath = homeDirectory.appendingPathComponent(".zshrc").path  // Adjust for bash if needed
    let exportPathLine = "export PATH=\"$HOME/sbm-bin:$PATH\"\n"
    
    if let shellConfigContents = try? String(contentsOfFile: shellConfigPath), !shellConfigContents.contains(exportPathLine) {
        // Open the file for appending and write the export line
        if let fileHandle = FileHandle(forWritingAtPath: shellConfigPath) {
            fileHandle.seekToEndOfFile()
            if let data = exportPathLine.data(using: .utf8) {
                fileHandle.write(data)
                print("Added sbm-bin to PATH in \(shellConfigPath)")
                print("Please run 'source ~/.zshrc' to update your PATH or restart your terminal.")
            }
            fileHandle.closeFile()
        } else {
            // If unable to open, fallback to simple file append
            do {
                try exportPathLine.write(toFile: shellConfigPath, atomically: true, encoding: .utf8)
                print("Added sbm-bin to PATH in \(shellConfigPath)")
                print("Please run 'source ~/.zshrc' to update your PATH or restart your terminal.")
            } catch {
                print("Error: Could not modify \(shellConfigPath): \(error)")
                exit(1)
            }
        }
    }
    
    return sbmBinPath
}

// Locate the binary target name from Package.swift
func getTargetName(from directory: String) -> String? {
    let packageSwiftPath = URL(fileURLWithPath: directory).appendingPathComponent("Package.swift").path
    guard let packageContents = try? String(contentsOfFile: packageSwiftPath) else {
        print("Error: Could not read Package.swift.")
        return nil
    }
    
    // A simple regex to find the first target name in Package.swift
    let targetNameRegex = try! NSRegularExpression(pattern: #"name:\s*"(\w+)""#, options: [])
    if let match = targetNameRegex.firstMatch(in: packageContents, options: [], range: NSRange(location: 0, length: packageContents.count)) {
        if let targetRange = Range(match.range(at: 1), in: packageContents) {
            return String(packageContents[targetRange])
        }
    }
    
    print("Error: Could not locate a target name in Package.swift.")
    return nil
}

func buildAndDeploy(targetDirectory: String, buildType: BuildType, destinationPath: String) {
    // Step 1: Build the project
    let buildCommand = buildType == .debug ? "swift build -c debug" : "swift build -c release"
    print("Building project...")
    guard runShellCommand(buildCommand, in: targetDirectory) else {
        print("Error: Build failed.")
        return
    }
    
    // Step 2: Locate the binary
    guard let targetName = getTargetName(from: targetDirectory) else {
        print("Error: Could not determine target name.")
        return
    }
    
    let buildPath = buildType == .debug ? ".build/debug/\(targetName)" : ".build/release/\(targetName)"
    let sourceURL = URL(fileURLWithPath: targetDirectory).appendingPathComponent(buildPath)
    let destinationURL = URL(fileURLWithPath: destinationPath).appendingPathComponent(targetName)
    
    // Step 3: Replace the binary at the destination path
    do {
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            print("Warning: \(destinationURL.path) already exists. Replacing it.")
        }
        
        if let replacedURL = try FileManager.default.replaceItemAt(destinationURL, withItemAt: sourceURL) {
            print("Binary replaced at \(replacedURL.path)")
        } else {
            print("Binary replaced, but no new URL was returned.")
        }
    } catch {
        print("Error: Failed to replace binary at \(destinationPath): \(error)")
    }
}

func main() {
    // Main execution
    let arguments = CommandLine.arguments

    guard arguments.count >= 2 else {
        print("Usage: sbm -d|-r [project-directory] [destination-path (optional)]")
        exit(1)
    }

    guard let buildType = BuildType.fromArgument(arguments[1]) else {
        print("Invalid build type. Use -d|-debug for debug or -r|-release for release.")
        exit(1)
    }

    // Determine the project directory and destination path
    let projectDirectory = arguments.count > 2 && arguments[2].first != "-" ? arguments[2] : FileManager.default.currentDirectoryPath
    let destinationPath = arguments.count > 3 ? arguments[3] : setupSBMBinDirectory()

    buildAndDeploy(targetDirectory: projectDirectory, buildType: buildType, destinationPath: destinationPath)
}

main()

// sbm -d|-r (defaults)
// sbm -d|-r /project/path (specifying another argument will be assumed as project)
// sbm -d|-r /project/path /destination/path (specifying yet another arg will be placed as destination for binaries)




