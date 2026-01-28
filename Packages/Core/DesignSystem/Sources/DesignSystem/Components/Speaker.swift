import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - Speaker Color

/// Color assigned to a speaker for visual identification.
/// Maps to Vapor accent colors.
public enum SpeakerColor: String, CaseIterable, Sendable {
    case sky
    case lavender
    case deep
    case dusk

    public var color: Color {
        switch self {
        case .sky: return VaporColor.sky
        case .lavender: return VaporColor.lavender
        case .deep: return VaporColor.deep
        case .dusk: return VaporColor.dusk
        }
    }

    /// Get a speaker color by index (cycles through available colors)
    public static func forIndex(_ index: Int) -> SpeakerColor {
        let colors = SpeakerColor.allCases
        return colors[index % colors.count]
    }
}

// MARK: - Speaker Unset

/// Chip for an unassigned speaker slot.
/// Shows an icon and "Speaker N" label with border styling.
public struct SpeakerUnset: View {
    private let number: Int
    private let color: SpeakerColor

    public init(number: Int, color: SpeakerColor = .sky) {
        self.number = number
        self.color = color
    }

    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 12))
                .foregroundColor(color.color)

            Text("Speaker \(number)")
                .font(.system(size: 10, weight: .medium))
                .tracking(0.5)
                .foregroundColor(color.color)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.color.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(color.color, lineWidth: 1)
        )
    }
}

// MARK: - Speaker Set

/// Minimal chip for an assigned speaker.
/// Shows a colored dot and speaker name in uppercase.
public struct SpeakerSet: View {
    private let name: String
    private let color: SpeakerColor

    public init(name: String, color: SpeakerColor = .sky) {
        self.name = name
        self.color = color
    }

    public var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color.color)
                .frame(width: 6, height: 6)

            Text(name.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundColor(color.color)
        }
    }
}

// MARK: - Speaker Option

/// An option row in the speaker picker modal.
/// Shows a colored dot and person name.
public struct SpeakerOption: View {
    private let name: String
    private let color: SpeakerColor
    private let isSelected: Bool

    public init(name: String, color: SpeakerColor, isSelected: Bool = false) {
        self.name = name
        self.color = color
        self.isSelected = isSelected
    }

    public var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color.color)
                .frame(width: 8, height: 8)

            Text(name)
                .font(.system(size: 14, weight: .light))
                .foregroundColor(VaporColor.textPrimary)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(VaporColor.deep)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(isSelected ? VaporColor.haze : Color.clear)
        .contentShape(Rectangle())
    }
}

/// Preview variant for snapshot testing.
public struct SpeakerOptionPreview: View {
    private let name: String
    private let color: SpeakerColor
    private let isSelected: Bool

    public init(name: String, color: SpeakerColor, isSelected: Bool = false) {
        self.name = name
        self.color = color
        self.isSelected = isSelected
    }

    public var body: some View {
        SpeakerOption(name: name, color: color, isSelected: isSelected)
    }
}

// MARK: - Current User Option

/// Option row for the current user (yourself) in the speaker picker modal.
/// Shows "You" label with optional avatar image and selection state.
public struct CurrentUserOption: View {
    private let name: String
    private let avatarData: Data?
    private let isSelected: Bool

    public init(name: String, avatarData: Data? = nil, isSelected: Bool = false) {
        self.name = name
        self.avatarData = avatarData
        self.isSelected = isSelected
    }

    private var initials: String {
        let components = name.split(separator: " ")
        let first = components.first?.prefix(1) ?? ""
        let last = components.count > 1 ? components.last?.prefix(1) ?? "" : ""
        return String(first + last).uppercased()
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Avatar (image or initials)
            avatarView

            // Name with "You" indicator
            VStack(alignment: .leading, spacing: 2) {
                Text("You")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(VaporColor.textPrimary)

                Text(name)
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(VaporColor.textSecondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(VaporColor.deep)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(isSelected ? VaporColor.haze : Color.clear)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var avatarView: some View {
        Group {
            #if os(iOS)
            if let data = avatarData,
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
            } else {
                initialsView
            }
            #else
            initialsView
            #endif
        }
    }

    private var initialsView: some View {
        ZStack {
            Circle()
                .fill(VaporColor.sky)
                .frame(width: 32, height: 32)

            Text(initials)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(VaporColor.cloud)
        }
    }
}

/// Preview variant for snapshot testing.
public struct CurrentUserOptionPreview: View {
    private let name: String
    private let avatarData: Data?
    private let isSelected: Bool

    public init(name: String, avatarData: Data? = nil, isSelected: Bool = false) {
        self.name = name
        self.avatarData = avatarData
        self.isSelected = isSelected
    }

    public var body: some View {
        CurrentUserOption(name: name, avatarData: avatarData, isSelected: isSelected)
    }
}

// MARK: - New Speaker Option

/// Option row for creating a new person in the speaker picker.
public struct NewSpeakerOption: View {
    public init() {}

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 14))
                .foregroundColor(VaporColor.deep)

            Text("Add new person...")
                .font(.system(size: 14, weight: .light))
                .foregroundColor(VaporColor.deep)

            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .contentShape(Rectangle())
    }
}

// MARK: - Person Card

/// Card showing a person's info with avatar, name, and conversation count.
public struct PersonCard: View {
    private let name: String
    private let initials: String
    private let conversationCount: Int
    private let color: SpeakerColor

    public init(
        name: String,
        initials: String? = nil,
        conversationCount: Int,
        color: SpeakerColor = .sky
    ) {
        self.name = name
        self.initials = initials ?? Self.generateInitials(from: name)
        self.conversationCount = conversationCount
        self.color = color
    }

    private static func generateInitials(from name: String) -> String {
        let components = name.split(separator: " ")
        let first = components.first?.prefix(1) ?? ""
        let last = components.count > 1 ? components.last?.prefix(1) ?? "" : ""
        return String(first + last).uppercased()
    }

    public var body: some View {
        HStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(color.color)
                    .frame(width: 44, height: 44)

                Text(initials)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(VaporColor.cloud)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(VaporColor.textPrimary)

                Text("\(conversationCount) conversation\(conversationCount == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(VaporColor.textTertiary)
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(VaporColor.textTertiary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(VaporColor.cloud)
                .shadow(
                    color: Color.black.opacity(0.03),
                    radius: 8,
                    y: 2
                )
        )
    }
}

/// Preview variant for snapshot testing.
public struct PersonCardPreview: View {
    private let name: String
    private let initials: String?
    private let conversationCount: Int
    private let color: SpeakerColor

    public init(
        name: String,
        initials: String? = nil,
        conversationCount: Int,
        color: SpeakerColor = .sky
    ) {
        self.name = name
        self.initials = initials
        self.conversationCount = conversationCount
        self.color = color
    }

    public var body: some View {
        PersonCard(
            name: name,
            initials: initials,
            conversationCount: conversationCount,
            color: color
        )
    }
}

// MARK: - Speaker Name Input

/// Input field for entering a speaker's name with save button.
public struct SpeakerNameInput: View {
    @Binding var name: String
    let onSave: () -> Void

    public init(name: Binding<String>, onSave: @escaping () -> Void) {
        self._name = name
        self.onSave = onSave
    }

    public var body: some View {
        HStack(spacing: 8) {
            TextField("Name", text: $name)
                .font(.system(size: 14, weight: .light))
                .foregroundColor(VaporColor.textPrimary)
                .textFieldStyle(.plain)

            Button(action: onSave) {
                Text("Save")
                    .font(.system(size: 13))
                    .foregroundColor(VaporColor.cloud)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(
                        Capsule()
                            .fill(VaporColor.sky)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.5))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(VaporColor.sky, lineWidth: 1)
        )
    }
}

/// Preview variant for snapshot testing (non-interactive).
public struct SpeakerNameInputPreview: View {
    private let nameText: String

    public init(name: String) {
        self.nameText = name
    }

    public var body: some View {
        HStack(spacing: 8) {
            Text(nameText)
                .font(.system(size: 14, weight: .light))
                .foregroundColor(VaporColor.textPrimary)

            Spacer()

            Text("Save")
                .font(.system(size: 13))
                .foregroundColor(VaporColor.cloud)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(
                    Capsule()
                        .fill(VaporColor.sky)
                )
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.5))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(VaporColor.sky, lineWidth: 1)
        )
    }
}

// MARK: - Speaker Picker Modal

/// Modal for selecting or creating a speaker assignment.
public struct SpeakerPickerModal<Content: View>: View {
    private let title: String
    private let onClose: () -> Void
    private let content: () -> Content

    public init(
        title: String = "Assign Speaker",
        onClose: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.onClose = onClose
        self.content = content
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(VaporColor.textPrimary)

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16))
                        .foregroundColor(VaporColor.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .overlay(
                Rectangle()
                    .fill(VaporColor.fog)
                    .frame(height: 1),
                alignment: .bottom
            )

            // Content
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(.vertical, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(VaporColor.cloud)
                .shadow(
                    color: Color.black.opacity(0.12),
                    radius: 32,
                    y: 8
                )
        )
    }
}

/// Section header label for the speaker picker modal.
public struct SpeakerPickerSectionLabel: View {
    private let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .medium))
            .tracking(1.5)
            .foregroundColor(VaporColor.textTertiary)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)
    }
}

/// Preview variant for snapshot testing.
public struct SpeakerPickerModalPreview: View {
    private let existingSpeakers: [(name: String, color: SpeakerColor, isSelected: Bool)]
    private let showNewOption: Bool

    public init(
        existingSpeakers: [(name: String, color: SpeakerColor, isSelected: Bool)] = [],
        showNewOption: Bool = true
    ) {
        self.existingSpeakers = existingSpeakers
        self.showNewOption = showNewOption
    }

    public var body: some View {
        SpeakerPickerModal(onClose: {}) {
            // Existing speakers section
            if !existingSpeakers.isEmpty {
                SpeakerPickerSectionLabel("Existing Speakers")

                ForEach(Array(existingSpeakers.enumerated()), id: \.offset) { _, speaker in
                    SpeakerOption(
                        name: speaker.name,
                        color: speaker.color,
                        isSelected: speaker.isSelected
                    )
                }

                // Divider
                Rectangle()
                    .fill(VaporColor.fog)
                    .frame(height: 1)
                    .padding(.vertical, 4)
            }

            // Create new section
            if showNewOption {
                SpeakerPickerSectionLabel("Create New")
                NewSpeakerOption()
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
struct SpeakerUnset_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            SpeakerUnset(number: 1)
            SpeakerUnset(number: 2, color: .lavender)
            SpeakerUnset(number: 3, color: .deep)
        }
        .padding(24)
        .background(VaporColor.mist)
    }
}

struct SpeakerSet_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            SpeakerSet(name: "Sarah")
            SpeakerSet(name: "Marcus", color: .lavender)
            SpeakerSet(name: "Alex", color: .deep)
        }
        .padding(24)
        .background(VaporColor.mist)
    }
}

struct PersonCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            PersonCard(name: "Sarah Chen", conversationCount: 12)
            PersonCard(name: "Marcus Kim", conversationCount: 1, color: .lavender)
        }
        .padding(24)
        .background(VaporColor.mist)
    }
}

struct SpeakerPickerModal_Previews: PreviewProvider {
    static var previews: some View {
        SpeakerPickerModalPreview(
            existingSpeakers: [
                (name: "Sarah Chen", color: .sky, isSelected: false),
                (name: "Marcus Kim", color: .lavender, isSelected: true)
            ]
        )
        .padding(24)
        .background(VaporColor.mist)
    }
}
#endif
