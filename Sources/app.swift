import Executable

@main
enum SBM {
    static func main() async {
        await SwiftBuildManagerCommand.main()
    }
}
