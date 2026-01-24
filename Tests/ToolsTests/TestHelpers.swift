import Foundation

/// Shared test helper to find the project root directory
func findProjectRoot() throws -> URL {
    let fileManager = FileManager.default
    var searchDir = URL(fileURLWithPath: fileManager.currentDirectoryPath)

    for _ in 0..<10 {
        let claudeMD = searchDir.appendingPathComponent("CLAUDE.md")
        let gitDir = searchDir.appendingPathComponent(".git")
        if fileManager.fileExists(atPath: claudeMD.path) || isDirectory(atPath: gitDir.path) {
            return searchDir
        }
        searchDir = searchDir.deletingLastPathComponent()
    }

    throw TestHelperError.projectRootNotFound
}

/// Check if a path is a directory
func isDirectory(atPath path: String) -> Bool {
    var isDir: ObjCBool = false
    return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
}

enum TestHelperError: Error {
    case projectRootNotFound
    case fileNotFound(String)
}
