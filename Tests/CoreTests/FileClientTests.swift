import Foundation
import Testing
import Dependencies
@testable import Export

/// Tests for the in-memory FileClient implementation
@Test func testInMemoryFileClient() async throws {
    // Create in-memory storage so we can inspect state
    let storage = InMemoryFileStorage()
    let fileClient = FileClient.inMemory(storage: storage)

    try await withDependencies {
        $0.fileClient = fileClient
    } operation: {
        @Dependency(\.fileClient) var client

        // Test temporaryDirectory returns expected path
        let tempDir = client.temporaryDirectory()
        #expect(tempDir.path == "/tmp/vapor-test", "temporaryDirectory should return configured path")

        // Test exists returns false for non-existent file
        let testURL = tempDir.appendingPathComponent("test.txt")
        #expect(!client.exists(testURL), "exists should return false for non-existent file")

        // Test write then read
        let testData = Data("Hello, World!".utf8)
        try await client.write(testData, testURL)
        #expect(client.exists(testURL), "exists should return true after write")

        let readData = try await client.read(testURL)
        #expect(readData == testData, "read should return written data")

        // Test createDirectory
        let dirURL = tempDir.appendingPathComponent("subdir")
        try await client.createDirectory(dirURL)
        #expect(client.exists(dirURL), "exists should return true for created directory")

        // Test delete file
        try await client.delete(testURL)
        #expect(!client.exists(testURL), "exists should return false after delete")

        // Test read throws for deleted file
        do {
            _ = try await client.read(testURL)
            Issue.record("read should throw for deleted file")
        } catch let error as FileClientError {
            if case .fileNotFound(let url) = error {
                #expect(url == testURL, "error should contain the correct URL")
            } else {
                Issue.record("Expected fileNotFound error, got \(error)")
            }
        }
    }
}

/// Tests that InMemoryFileStorage can handle multiple files
@Test func testInMemoryMultipleFiles() async throws {
    let storage = InMemoryFileStorage()
    let fileClient = FileClient.inMemory(storage: storage)

    try await withDependencies {
        $0.fileClient = fileClient
    } operation: {
        @Dependency(\.fileClient) var client
        let tempDir = client.temporaryDirectory()

        // Write multiple files
        let file1 = tempDir.appendingPathComponent("file1.txt")
        let file2 = tempDir.appendingPathComponent("file2.txt")
        let file3 = tempDir.appendingPathComponent("nested/file3.txt")

        try await client.write(Data("one".utf8), file1)
        try await client.write(Data("two".utf8), file2)
        try await client.write(Data("three".utf8), file3)

        // Verify all exist
        #expect(client.exists(file1), "file1 should exist")
        #expect(client.exists(file2), "file2 should exist")
        #expect(client.exists(file3), "file3 should exist")

        // Verify storage tracks all files
        let allPaths = storage.allFilePaths()
        #expect(allPaths.count == 3, "should have 3 files")

        // Delete one file
        try await client.delete(file2)
        #expect(!client.exists(file2), "file2 should not exist after delete")
        #expect(storage.allFilePaths().count == 2, "should have 2 files after delete")
    }
}

/// Tests that directory deletion removes nested files
@Test func testInMemoryDirectoryDelete() async throws {
    let storage = InMemoryFileStorage()
    let fileClient = FileClient.inMemory(storage: storage)

    try await withDependencies {
        $0.fileClient = fileClient
    } operation: {
        @Dependency(\.fileClient) var client
        let tempDir = client.temporaryDirectory()

        // Create directory structure
        let subdir = tempDir.appendingPathComponent("bundle")
        try await client.createDirectory(subdir)

        // Write files in subdirectory
        let file1 = subdir.appendingPathComponent("transcript.json")
        let file2 = subdir.appendingPathComponent("audio.caf")

        try await client.write(Data("{}".utf8), file1)
        try await client.write(Data([0x00]), file2)

        #expect(storage.allFilePaths().count == 2, "should have 2 files")

        // Delete directory - should remove all files
        try await client.delete(subdir)
        #expect(storage.allFilePaths().count == 0, "should have 0 files after directory delete")
    }
}

/// Tests reset functionality
@Test func testInMemoryReset() async throws {
    let storage = InMemoryFileStorage()
    let fileClient = FileClient.inMemory(storage: storage)

    try await withDependencies {
        $0.fileClient = fileClient
    } operation: {
        @Dependency(\.fileClient) var client
        let tempDir = client.temporaryDirectory()

        // Write some files
        try await client.write(Data("test".utf8), tempDir.appendingPathComponent("a.txt"))
        try await client.write(Data("test".utf8), tempDir.appendingPathComponent("b.txt"))
        try await client.createDirectory(tempDir.appendingPathComponent("dir"))

        #expect(storage.allFilePaths().count == 2, "should have 2 files before reset")

        // Reset storage
        storage.reset()

        #expect(storage.allFilePaths().count == 0, "should have 0 files after reset")
        #expect(!client.exists(tempDir.appendingPathComponent("a.txt")), "files should not exist after reset")
        #expect(!client.exists(tempDir.appendingPathComponent("dir")), "directories should not exist after reset")
    }
}

/// Tests that overwriting a file replaces content
@Test func testInMemoryOverwrite() async throws {
    let storage = InMemoryFileStorage()
    let fileClient = FileClient.inMemory(storage: storage)

    try await withDependencies {
        $0.fileClient = fileClient
    } operation: {
        @Dependency(\.fileClient) var client
        let tempDir = client.temporaryDirectory()
        let fileURL = tempDir.appendingPathComponent("overwrite.txt")

        // Write initial content
        try await client.write(Data("original".utf8), fileURL)
        var content = try await client.read(fileURL)
        #expect(String(data: content, encoding: .utf8) == "original", "should have original content")

        // Overwrite with new content
        try await client.write(Data("updated".utf8), fileURL)
        content = try await client.read(fileURL)
        #expect(String(data: content, encoding: .utf8) == "updated", "should have updated content")
    }
}

/// Tests custom temp directory
@Test func testInMemoryCustomTempDirectory() async throws {
    let customTempDir = URL(fileURLWithPath: "/custom/temp/path")
    let fileClient = FileClient.inMemory(tempDirectory: customTempDir)

    try await withDependencies {
        $0.fileClient = fileClient
    } operation: {
        @Dependency(\.fileClient) var client
        let tempDir = client.temporaryDirectory()
        #expect(tempDir == customTempDir, "should use custom temp directory")
    }
}
