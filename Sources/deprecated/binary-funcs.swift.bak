import Foundation
import Interfaces
import plate

func removeBinaryAndMetadata(for targetDirectory: String, in destinationPath: String) async {
    guard let targetNames = await getTargetNames(from: targetDirectory) else {
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
