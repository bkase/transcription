import AVFoundation

// MARK: - AudioEngineProtocol

/// Protocol abstracting AVAudioEngine for testing
public protocol AudioEngineProtocol: AnyObject, Sendable {
    var audioInputNode: AudioInputNodeProtocol { get }
    func start() throws
    func stop()
    func prepare()
}

/// Protocol abstracting AVAudioInputNode for testing
public protocol AudioInputNodeProtocol: AnyObject, Sendable {
    func installTap(
        onBus bus: AVAudioNodeBus,
        bufferSize: AVAudioFrameCount,
        format: AVAudioFormat?,
        block: @escaping AVAudioNodeTapBlock
    )
    func removeTap(onBus bus: AVAudioNodeBus)
    var outputFormat: @Sendable (AVAudioNodeBus) -> AVAudioFormat { get }
}

// MARK: - AVAudioEngine Conformance

extension AVAudioEngine: @retroactive @unchecked Sendable {}

extension AVAudioEngine: AudioEngineProtocol {
    public var audioInputNode: AudioInputNodeProtocol {
        self.inputNode
    }
}

extension AVAudioInputNode: @retroactive @unchecked Sendable {}

extension AVAudioInputNode: AudioInputNodeProtocol {
    public var outputFormat: @Sendable (AVAudioNodeBus) -> AVAudioFormat {
        { [self] bus in self.outputFormat(forBus: bus) }
    }
}
