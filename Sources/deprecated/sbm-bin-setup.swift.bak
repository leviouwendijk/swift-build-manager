import Foundation

func setupSBMBinDirectory() -> String {
    let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
    let sbmBinPath = homeDirectory.appendingPathComponent("sbm-bin").path

    if !FileManager.default.fileExists(atPath: sbmBinPath) {
        do {
            try FileManager.default.createDirectory(atPath: sbmBinPath, withIntermediateDirectories: true, attributes: nil)
            print("Created sbm-bin directory at \(sbmBinPath)")
        } catch {
            print("Error: Could not create sbm-bin directory: \(error)".ansi(.red))
            exit(1)
        }
    }

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
                print("Error: Could not modify \(shellConfigPath): \(error)".ansi(.red))
                exit(1)
            }
        }
    }
    
    return sbmBinPath
}

func setupSBMLibraryDirectory() -> String {
    let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
    let sbmLibraryPath = homeDirectory.appendingPathComponent("sbm-bin/modules").path
    let sbmBinPath = homeDirectory.appendingPathComponent("sbm-bin").path // Ensure sbm-bin exists
    
    let fileManager = FileManager.default
    
    // Ensure sbm-bin and sbm-bin/modules exist
    do {
        if !fileManager.fileExists(atPath: sbmBinPath) {
            try fileManager.createDirectory(atPath: sbmBinPath, withIntermediateDirectories: true)
            print("Created sbm-bin directory at \(sbmBinPath)".ansi(.green))
        }

        if !fileManager.fileExists(atPath: sbmLibraryPath) {
            try fileManager.createDirectory(atPath: sbmLibraryPath, withIntermediateDirectories: true)
            print("Created sbm-bin/modules directory at \(sbmLibraryPath)".ansi(.green))
        }
    } catch {
        print("Error: Could not create directories: \(error)".ansi(.red))
        exit(1)
    }

    // Define the shell configuration file to modify
    let shellConfigPath = homeDirectory.appendingPathComponent(".zshrc").path  // Change to `.bashrc` if needed
    let exportPathLine = "export SWIFT_INCLUDE_PATHS=\"$HOME/sbm-bin/modules:$SWIFT_INCLUDE_PATHS\"\n"
    
    // Check if `.zshrc` exists and already contains the required export line
    if let shellConfigContents = try? String(contentsOfFile: shellConfigPath), !shellConfigContents.contains(exportPathLine) {
        // Append export line safely
        do {
            let fileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: shellConfigPath))
            fileHandle.seekToEndOfFile()
            if let data = exportPathLine.data(using: .utf8) {
                fileHandle.write(data)
                print("Added sbm-bin/modules to SWIFT_INCLUDE_PATHS in \(shellConfigPath)".ansi(.yellow))
                print("Please run 'source ~/.zshrc' to update your Swift module path or restart your terminal.".ansi(.yellow))
            }
            fileHandle.closeFile()
        } catch {
            do {
                try exportPathLine.write(toFile: shellConfigPath, atomically: true, encoding: .utf8)
                print("Added sbm-bin/modules to SWIFT_INCLUDE_PATHS in \(shellConfigPath)".ansi(.yellow))
                print("Please run 'source ~/.zshrc' to update your Swift module path or restart your terminal.".ansi(.yellow))
            } catch {
                print("Error: Could not modify \(shellConfigPath): \(error)".ansi(.red))
                exit(1)
            }
        }
    }

    return sbmLibraryPath
}
