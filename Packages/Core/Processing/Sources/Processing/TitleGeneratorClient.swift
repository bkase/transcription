import Foundation
import Dependencies
import DependenciesMacros

// MARK: - TitleGeneratorClient

/// Client for generating session titles from transcript text using on-device LLM (iOS 18.4+)
@DependencyClient
public struct TitleGeneratorClient: Sendable {
    /// Generate a title from transcript text. Returns nil if unavailable (e.g., older iOS).
    public var generateTitle: @Sendable (_ transcriptText: String) async throws -> String?
    /// Check if title generation is available on this device/OS
    public var isAvailable: @Sendable () -> Bool = { false }
}

extension TitleGeneratorClient: DependencyKey {
    public static var liveValue: Self {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            return Self.foundationModelsClient()
        } else {
            return Self.unavailableClient()
        }
        #else
        return Self.unavailableClient()
        #endif
    }

    public static var previewValue: Self {
        Self(
            generateTitle: { _ in nil },
            isAvailable: { false }
        )
    }

    public static var testValue: Self { Self() }

    /// Client that always returns unavailable (for platforms/iOS versions without Foundation Models)
    private static func unavailableClient() -> Self {
        Self(
            generateTitle: { _ in nil },
            isAvailable: { false }
        )
    }

    #if os(iOS)
    @available(iOS 26.0, *)
    private static func foundationModelsClient() -> Self {
        // Import FoundationModels dynamically to avoid compile errors on older iOS
        // The actual implementation uses Apple's Foundation Models framework
        Self(
            generateTitle: { text in
                // Dynamically load and use Foundation Models
                return try await generateTitleWithFoundationModels(text: text)
            },
            isAvailable: { true }
        )
    }
    #endif
}

// MARK: - Foundation Models Implementation

#if os(iOS)
import FoundationModels

@available(iOS 26.0, *)
private func generateTitleWithFoundationModels(text: String) async throws -> String? {
    // Prepare prompt - limit input to first 3000 chars for performance
    let truncatedText = String(text.prefix(3000))
    let prompt = """
        Create a brief 3-6 word title for this conversation transcript.
        Return only the title, no quotes or extra text.

        Transcript:
        \(truncatedText)
        """

    // Use Foundation Models API
    NSLog("[TitleGenerator] Starting title generation with Foundation Models")

    do {
        let session = LanguageModelSession()
        let response = try await session.respond(to: prompt)
        let title = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        NSLog("[TitleGenerator] Generated title: '%@'", title)
        return title
    } catch {
        NSLog("[TitleGenerator] Foundation Models error: %@", error.localizedDescription)
        throw error
    }
}
#endif

// MARK: - DependencyValues Extension

extension DependencyValues {
    public var titleGeneratorClient: TitleGeneratorClient {
        get { self[TitleGeneratorClient.self] }
        set { self[TitleGeneratorClient.self] = newValue }
    }
}
