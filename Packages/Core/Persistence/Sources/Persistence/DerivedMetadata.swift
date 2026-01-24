import Foundation

// MARK: - Derived Metadata Helpers

/// Helpers to compute cached session metadata from segments
public enum DerivedMetadata {
    /// Compute preview text from transcript segments.
    /// Takes the first few words from the earliest final segments.
    /// - Parameters:
    ///   - segments: Transcript segments ordered by startMs
    ///   - maxLength: Maximum character length for preview (default 100)
    /// - Returns: Preview text or nil if no final segments exist
    public static func previewText(
        from segments: [TranscriptSegmentRecord],
        maxLength: Int = 100
    ) -> String? {
        // Filter to final segments only and sort by start time
        let finalSegments = segments
            .filter { $0.isFinal }
            .sorted { $0.startMs < $1.startMs }

        guard !finalSegments.isEmpty else { return nil }

        // Concatenate text until we reach max length
        var result = ""
        for segment in finalSegments {
            let trimmedText = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedText.isEmpty else { continue }

            if result.isEmpty {
                result = trimmedText
            } else {
                result += " " + trimmedText
            }

            if result.count >= maxLength {
                break
            }
        }

        // Truncate to max length with ellipsis if needed
        if result.count > maxLength {
            let endIndex = result.index(result.startIndex, offsetBy: maxLength)
            result = String(result[..<endIndex]).trimmingCharacters(in: .whitespaces) + "..."
        }

        return result.isEmpty ? nil : result
    }

    /// Compute total duration from transcript segments.
    /// Uses the max endMs from all final segments.
    /// - Parameter segments: Transcript segments
    /// - Returns: Duration in milliseconds, or nil if no final segments
    public static func durationMs(from segments: [TranscriptSegmentRecord]) -> Int? {
        let finalSegments = segments.filter { $0.isFinal }
        guard !finalSegments.isEmpty else { return nil }

        return finalSegments.map(\.endMs).max()
    }

    /// Count unique speakers from transcript segments.
    /// - Parameter segments: Transcript segments
    /// - Returns: Number of unique machine speaker IDs in final segments
    public static func speakerCount(from segments: [TranscriptSegmentRecord]) -> Int {
        let finalSegments = segments.filter { $0.isFinal }
        let speakerIds = Set(finalSegments.compactMap(\.machineSpeakerId))
        return speakerIds.count
    }

    /// Compute all derived metadata at once for efficiency.
    /// - Parameters:
    ///   - segments: Transcript segments
    ///   - maxPreviewLength: Maximum preview text length
    /// - Returns: Tuple of (previewText, durationMs, speakerCount)
    public static func computeAll(
        from segments: [TranscriptSegmentRecord],
        maxPreviewLength: Int = 100
    ) -> (previewText: String?, durationMs: Int?, speakerCount: Int) {
        let finalSegments = segments.filter { $0.isFinal }

        // Preview text
        let sortedFinal = finalSegments.sorted { $0.startMs < $1.startMs }
        var preview = ""
        for segment in sortedFinal {
            let trimmedText = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedText.isEmpty else { continue }

            if preview.isEmpty {
                preview = trimmedText
            } else {
                preview += " " + trimmedText
            }

            if preview.count >= maxPreviewLength {
                break
            }
        }

        if preview.count > maxPreviewLength {
            let endIndex = preview.index(preview.startIndex, offsetBy: maxPreviewLength)
            preview = String(preview[..<endIndex]).trimmingCharacters(in: .whitespaces) + "..."
        }

        let previewText: String? = preview.isEmpty ? nil : preview

        // Duration
        let durationMs = finalSegments.map(\.endMs).max()

        // Speaker count
        let speakerIds = Set(finalSegments.compactMap(\.machineSpeakerId))
        let speakerCount = speakerIds.count

        return (previewText, durationMs, speakerCount)
    }
}
