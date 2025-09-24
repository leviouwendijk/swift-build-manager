import Foundation
import plate
import Interfaces

func getTargetNames(from directory: String) async -> [String]? {
    do {
        let data = try await dumpPackageData(for: directory)
        let blob = SwiftPackageDumpBlob(raw: data)
        let reader = try SwiftPackageDumpReader(blob: blob)

        if let pkg = reader.packageName() {
            print("Package: \(pkg)".ansi(.brightBlack))
        }

        let names = reader.executableTargetNames()
        if names.isEmpty {
            print("Error: No executable targets found in dump-package output.".ansi(.red))
            return nil
        }
        return names
    } catch {
        print("Error reading dump-package JSON: \(error.localizedDescription)".ansi(.red))
        return nil
    }
}

func getPackageName(from directory: String) async -> String? {
    do {
        let data = try await dumpPackageData(for: directory)
        let blob = SwiftPackageDumpBlob(raw: data)
        let reader = try SwiftPackageDumpReader(blob: blob)

        if let pkg = reader.packageName() {
            print("Package: \(pkg)".ansi(.brightBlack))
            return pkg
        }
        return nil
    } catch {
        print("Error reading dump-package JSON: \(error.localizedDescription)".ansi(.red))
        return nil
    }
}
