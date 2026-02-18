import AVFoundation
import Foundation
import Dependencies
import DependenciesMacros

// MARK: - AudioFileWriterClient

/// Client for writing audio data to files
@DependencyClient
public struct AudioFileWriterClient: Sendable {
    /// Start writing audio frames to a file at the given URL
    /// - Parameters:
    ///   - url: The file URL to write to
    ///   - format: The audio format configuration
    public var startWriting: @Sendable (_ url: URL, _ format: AudioFormatConfig) async throws -> Void

    /// Append audio frame data to the current file
    public var appendFrame: @Sendable (_ frame: AudioFrame) async throws -> Void

    /// Finish writing and close the file
    /// - Returns: The total bytes written
    public var finishWriting: @Sendable () async throws -> Int

    /// Cancel writing and delete the partial file
    public var cancelWriting: @Sendable () async -> Void

    /// Check if currently writing
    public var isWriting: @Sendable () async -> Bool = { false }
}

extension AudioFileWriterClient: DependencyKey {
    public static var liveValue: AudioFileWriterClient { .live() }

    public static var previewValue: Self {
        Self(
            startWriting: { _, _ in },
            appendFrame: { _ in },
            finishWriting: { 0 },
            cancelWriting: { },
            isWriting: { false }
        )
    }

    public static var testValue: Self { Self() }
}

extension DependencyValues {
    public var audioFileWriterClient: AudioFileWriterClient {
        get { self[AudioFileWriterClient.self] }
        set { self[AudioFileWriterClient.self] = newValue }
    }
}

// MARK: - Live Implementation

/// Actor that manages audio file writing state
public actor LiveAudioFileWriter {
    private var audioFile: ExtendedAudioFile?
    private var currentFileURL: URL?
    private var totalBytesWritten: Int = 0
    private var format: AudioFormatConfig?

    public init() {}

    public func startWriting(url: URL, format: AudioFormatConfig) throws {
        guard audioFile == nil else {
            throw AudioFileWriterError.alreadyWriting
        }

        let ext = url.pathExtension.lowercased()
        let isAAC = ext == "m4a" || ext == "aac"

        var extAudioFile: ExtAudioFileRef?

        if isAAC {
            // Output format: AAC — let the encoder fill in packet details
            var outputASBD = AudioStreamBasicDescription(
                mSampleRate: format.sampleRate,
                mFormatID: kAudioFormatMPEG4AAC,
                mFormatFlags: 0,
                mBytesPerPacket: 0,
                mFramesPerPacket: 1024,
                mBytesPerFrame: 0,
                mChannelsPerFrame: format.channels,
                mBitsPerChannel: 0,
                mReserved: 0
            )

            let createStatus = ExtAudioFileCreateWithURL(
                url as CFURL,
                kAudioFileM4AType,
                &outputASBD,
                nil,
                AudioFileFlags.eraseFile.rawValue,
                &extAudioFile
            )

            guard createStatus == noErr, let file = extAudioFile else {
                throw AudioFileWriterError.failedToCreateFile(createStatus)
            }

            // Client format: Float32 PCM (what we feed in)
            var clientASBD = AudioStreamBasicDescription(
                mSampleRate: format.sampleRate,
                mFormatID: kAudioFormatLinearPCM,
                mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
                mBytesPerPacket: UInt32(MemoryLayout<Float>.size) * format.channels,
                mFramesPerPacket: 1,
                mBytesPerFrame: UInt32(MemoryLayout<Float>.size) * format.channels,
                mChannelsPerFrame: format.channels,
                mBitsPerChannel: UInt32(MemoryLayout<Float>.size * 8),
                mReserved: 0
            )

            let clientStatus = ExtAudioFileSetProperty(
                file,
                kExtAudioFileProperty_ClientDataFormat,
                UInt32(MemoryLayout<AudioStreamBasicDescription>.size),
                &clientASBD
            )

            guard clientStatus == noErr else {
                ExtAudioFileDispose(file)
                throw AudioFileWriterError.failedToCreateFile(clientStatus)
            }

            self.audioFile = ExtendedAudioFile(ref: file)
        } else {
            // Uncompressed PCM path (CAF / WAV)
            var asbd = AudioStreamBasicDescription(
                mSampleRate: format.sampleRate,
                mFormatID: kAudioFormatLinearPCM,
                mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
                mBytesPerPacket: UInt32(MemoryLayout<Float>.size) * format.channels,
                mFramesPerPacket: 1,
                mBytesPerFrame: UInt32(MemoryLayout<Float>.size) * format.channels,
                mChannelsPerFrame: format.channels,
                mBitsPerChannel: UInt32(MemoryLayout<Float>.size * 8),
                mReserved: 0
            )

            let fileType: AudioFileTypeID = ext == "caf"
                ? kAudioFileCAFType
                : kAudioFileWAVEType

            let createStatus = ExtAudioFileCreateWithURL(
                url as CFURL,
                fileType,
                &asbd,
                nil,
                AudioFileFlags.eraseFile.rawValue,
                &extAudioFile
            )

            guard createStatus == noErr, let file = extAudioFile else {
                throw AudioFileWriterError.failedToCreateFile(createStatus)
            }

            self.audioFile = ExtendedAudioFile(ref: file)
        }

        self.currentFileURL = url
        self.format = format
        self.totalBytesWritten = 0
    }

    public func appendFrame(_ frame: AudioFrame) throws {
        guard let audioFile = audioFile, let format = format else {
            throw AudioFileWriterError.notWriting
        }

        let bytesPerFrame = Int(MemoryLayout<Float>.size) * Int(format.channels)
        let frameCount = frame.data.count / bytesPerFrame

        guard frameCount > 0 else { return }

        try frame.data.withUnsafeBytes { buffer in
            var audioBufferList = AudioBufferList(
                mNumberBuffers: 1,
                mBuffers: AudioBuffer(
                    mNumberChannels: format.channels,
                    mDataByteSize: UInt32(frame.data.count),
                    mData: UnsafeMutableRawPointer(mutating: buffer.baseAddress)
                )
            )

            let status = ExtAudioFileWrite(audioFile.ref, UInt32(frameCount), &audioBufferList)
            guard status == noErr else {
                throw AudioFileWriterError.writeFailed(status)
            }
        }

        totalBytesWritten += frame.data.count
    }

    public func finishWriting() throws -> Int {
        guard let audioFile = audioFile else {
            throw AudioFileWriterError.notWriting
        }

        let status = ExtAudioFileDispose(audioFile.ref)
        guard status == noErr else {
            throw AudioFileWriterError.failedToClose(status)
        }

        let bytesWritten = totalBytesWritten
        self.audioFile = nil
        self.currentFileURL = nil
        self.format = nil
        self.totalBytesWritten = 0

        return bytesWritten
    }

    public func cancelWriting() {
        guard let audioFile = audioFile else { return }

        let fileURL = currentFileURL

        // Dispose the audio file handle
        ExtAudioFileDispose(audioFile.ref)

        // Reset state
        self.audioFile = nil
        self.currentFileURL = nil
        self.format = nil
        self.totalBytesWritten = 0

        // Delete the partial file
        if let url = fileURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    public var isWriting: Bool {
        audioFile != nil
    }
}

// MARK: - Supporting Types

/// Errors that can occur during audio file writing
public enum AudioFileWriterError: Error, Equatable, Sendable {
    case alreadyWriting
    case notWriting
    case failedToCreateFile(OSStatus)
    case writeFailed(OSStatus)
    case failedToClose(OSStatus)
}

/// Wrapper to make ExtAudioFileRef manageable
private final class ExtendedAudioFile: @unchecked Sendable {
    let ref: ExtAudioFileRef

    init(ref: ExtAudioFileRef) {
        self.ref = ref
    }
}

// MARK: - Live Factory

extension AudioFileWriterClient {
    /// Creates a live AudioFileWriterClient using ExtAudioFile
    public static func live() -> Self {
        let writer = LiveAudioFileWriter()

        return Self(
            startWriting: { url, format in
                try await writer.startWriting(url: url, format: format)
            },
            appendFrame: { frame in
                try await writer.appendFrame(frame)
            },
            finishWriting: {
                try await writer.finishWriting()
            },
            cancelWriting: {
                await writer.cancelWriting()
            },
            isWriting: {
                await writer.isWriting
            }
        )
    }
}
