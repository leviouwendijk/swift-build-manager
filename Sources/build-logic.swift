import Foundation
import Interfaces
import plate

func buildOnly(targetDirectory: String, buildType: BuildType) async throws {
    let buildCmd = buildType == .debug ? "swift build -c debug" : "swift build -c release"
    print("Building project locally...")
    guard await runShellCommand(buildCmd, in: targetDirectory) else {
        throw NSError(domain: "sbm.build", code: 1, userInfo: [NSLocalizedDescriptionKey: "Build failed"])
    }
    print("\nBuild complete. Binary kept in project directory, not moved to sbm-bin.".ansi(.green))
}

func buildAndDeploy(targetDirectory: String, buildType: BuildType, destinationPath: String) async throws {
    let buildCmd = buildType == .debug ? "swift build -c debug" : "swift build -c release"
    print("Building project...")
    guard await runShellCommand(buildCmd, in: targetDirectory) else {
        throw NSError(domain: "sbm.build", code: 1, userInfo: [NSLocalizedDescriptionKey: "Build failed"])
    }

    print("\nMoving binary to " + "sbm-bin".ansi(.italic) + "...")
    let projectFolderName = URL(fileURLWithPath: targetDirectory).lastPathComponent
    guard let targetNames = await getTargetNames(from: targetDirectory) else {
        throw NSError(domain: "sbm.deploy", code: 2, userInfo: [NSLocalizedDescriptionKey: "No executable targets found"])
    }

    for targetName in targetNames {
        print("")
        let buildPath = (buildType == .debug ? ".build/debug/" : ".build/release/") + targetName
        let sourceURL = URL(fileURLWithPath: targetDirectory).appendingPathComponent(buildPath)
        let destinationURL = URL(fileURLWithPath: destinationPath).appendingPathComponent(targetName)

        var binaryExists = false
        var binaryPlaced = false
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                binaryExists = true
                print("\(destinationURL.path)".ansi(.brightBlack, .bold) + " already exists. Replacing it...".ansi(.brightBlack))
            }
            if let replacedURL = try FileManager.default.replaceItemAt(destinationURL, withItemAt: sourceURL) {
                print("Binary ".ansi(.brightBlack) + (binaryExists ? "re".ansi(.brightBlack) : "") +
                      "placed at ".ansi(.brightBlack) + "\(replacedURL.path)".ansi(.bold, .brightBlack))
                binaryPlaced = true
            } else {
                print("Binary replaced, but no new URL was returned.".ansi(.brightBlack))
            }
        } catch {
            throw NSError(domain: "sbm.deploy", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to replace binary: \(error)"])
        }

        // metadata
        let metadataPath = destinationURL.deletingLastPathComponent().appendingPathComponent("\(targetName).metadata")
        let metadataContent = "ProjectRootPath=\(targetDirectory)\n"
        do {
            try metadataContent.write(to: metadataPath, atomically: true, encoding: .utf8)
            print("Metadata file created at ".ansi(.brightBlack) + "\(metadataPath.path)".ansi(.brightBlack, .bold))
        } catch {
            print("Warning: Failed to write metadata file: \(error)".ansi(.yellow))
        }

        print("")
        let successOut = "\(targetName) ".ansi(.bold) + "is now an executable binary for " + "\(projectFolderName)".ansi(.italic)
        let successOutSpaced = "\n        \(successOut)\n    "
        let errorOut = "Failed to move \(targetName) binary to sbm-bin, retrace steps.".ansi(.red)
        print(binaryPlaced ? successOutSpaced : errorOut)
    }
}

func cleanBuild(for targetDirectory: String) async throws {
    let cmd = "swift package clean"
    print("Cleaning build artifacts in project directory: \(targetDirectory)".ansi(.brightBlack))
    guard await runShellCommand(cmd, in: targetDirectory) else {
        throw NSError(domain: "sbm.clean", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to clean build artifacts"])
    }
    print("\nClean successful!".ansi(.green))
}
