import Testing
import Foundation
@testable import Persistence

// MARK: - Passthrough Tests

@Test func testPassthroughReturnsDataUnchanged() async {
    let client = ProfileImageClient.passthrough
    let input = Data([0x01, 0x02, 0x03, 0x04])

    let result = await client.normalize(input, 256, 0.8)

    #expect(result == input)
}

@Test func testPassthroughIgnoresParameters() async {
    let client = ProfileImageClient.passthrough
    let input = Data([0xFF, 0xFE, 0xFD])

    // Different parameters should not affect passthrough
    let result1 = await client.normalize(input, 100, 0.5)
    let result2 = await client.normalize(input, 500, 1.0)

    #expect(result1 == input)
    #expect(result2 == input)
}

// MARK: - Always Fails Tests

@Test func testAlwaysFailsReturnsNil() async {
    let client = ProfileImageClient.alwaysFails
    let input = Data([0x89, 0x50, 0x4E, 0x47]) // PNG magic bytes

    let result = await client.normalize(input, 256, 0.8)

    #expect(result == nil)
}

// MARK: - Fixed Result Tests

@Test func testFixedReturnsConfiguredData() async {
    let expectedData = Data([0xAA, 0xBB, 0xCC])
    let client = ProfileImageClient.fixed(expectedData)

    let result = await client.normalize(Data([0x01, 0x02]), 256, 0.8)

    #expect(result == expectedData)
}

@Test func testFixedWithNilReturnsNil() async {
    let client = ProfileImageClient.fixed(nil)

    let result = await client.normalize(Data([0x01, 0x02]), 256, 0.8)

    #expect(result == nil)
}

// MARK: - Custom Implementation Tests

/// Actor for capturing normalize call parameters in a Sendable-safe way
private actor NormalizeCallCapture {
    var callCount = 0
    var capturedData: Data?
    var capturedMaxDimension: Int?
    var capturedQuality: Double?

    func record(data: Data, maxDimension: Int, quality: Double) {
        callCount += 1
        capturedData = data
        capturedMaxDimension = maxDimension
        capturedQuality = quality
    }
}

@Test func testCustomNormalizeImplementation() async {
    let capture = NormalizeCallCapture()

    let client = ProfileImageClient(
        normalize: { data, maxDimension, quality in
            await capture.record(data: data, maxDimension: maxDimension, quality: quality)
            return Data([0xDE, 0xAD, 0xBE, 0xEF])
        }
    )

    let input = Data([0x01, 0x02, 0x03])
    let result = await client.normalize(input, 512, 0.9)

    let callCount = await capture.callCount
    let capturedData = await capture.capturedData
    let capturedMaxDimension = await capture.capturedMaxDimension
    let capturedQuality = await capture.capturedQuality

    #expect(callCount == 1)
    #expect(capturedData == input)
    #expect(capturedMaxDimension == 512)
    #expect(capturedQuality == 0.9)
    #expect(result == Data([0xDE, 0xAD, 0xBE, 0xEF]))
}
