import ExecutableLegacy

@main
enum SBM {
    static func main() async {
        await SwiftBuildManagerMigrationCommand.main()
    }
}
