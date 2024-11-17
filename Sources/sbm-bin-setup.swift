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

