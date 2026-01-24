import ArgumentParser
import Foundation

@main
struct DocGen: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Generate documentation from schema definitions"
    )

    @Option(name: .shortAndLong, help: "Input schema directory")
    var input: String = "schema"

    @Option(name: .shortAndLong, help: "Output documentation directory")
    var output: String = "docs"

    func run() throws {
        print("DocGen: Generating docs from \(input) to \(output)")
        // Doc generation implementation will be added later
    }
}
