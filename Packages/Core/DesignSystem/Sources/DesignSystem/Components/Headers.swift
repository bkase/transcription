import SwiftUI

// MARK: - Page Header

/// Page header with kicker text and title.
/// Used at the top of main screens (e.g., "ARCHIVE" / "Timeline").
public struct PageHeader: View {
    private let kicker: String
    private let title: String

    public init(kicker: String, title: String) {
        self.kicker = kicker
        self.title = title
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: VaporSpacing.xs) {
            Text(kicker.uppercased())
                .font(.system(size: 11, weight: .light))
                .tracking(2)
                .foregroundColor(VaporColor.textTertiary)

            Text(title)
                .font(.system(size: 28, weight: .thin))
                .tracking(-0.5)
                .foregroundColor(VaporColor.textPrimary)
        }
    }
}

// MARK: - Date Header

/// Section date header for timeline grouping.
/// Displays date text in uppercase with letter spacing.
public struct DateHeader: View {
    private let text: String

    public init(_ text: String) {
        self.text = text
    }

    /// Create a date header for "Today"
    public static var today: DateHeader {
        DateHeader("TODAY")
    }

    /// Create a date header for "Yesterday"
    public static var yesterday: DateHeader {
        DateHeader("YESTERDAY")
    }

    /// Create a date header from a Date
    public static func date(_ date: Date, relativeTo referenceDate: Date = Date()) -> DateHeader {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return .today
        } else if calendar.isDateInYesterday(date) {
            return .yesterday
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d"
            return DateHeader(formatter.string(from: date).uppercased())
        }
    }

    public var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .medium))
            .tracking(2)
            .foregroundColor(VaporColor.textTertiary)
    }
}

// MARK: - Avatar

/// Circular avatar component for user profile.
/// Displays image if provided, or shows initials/placeholder.
public struct Avatar: View {
    public enum Size {
        case small   // 24pt
        case medium  // 32pt
        case large   // 44pt

        var diameter: CGFloat {
            switch self {
            case .small: return 24
            case .medium: return 32
            case .large: return 44
            }
        }

        var fontSize: CGFloat {
            switch self {
            case .small: return 10
            case .medium: return 12
            case .large: return 16
            }
        }
    }

    private let image: Image?
    private let initials: String?
    private let size: Size

    public init(image: Image? = nil, initials: String? = nil, size: Size = .medium) {
        self.image = image
        self.initials = initials
        self.size = size
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(VaporColor.haze)
                .frame(width: size.diameter, height: size.diameter)
                .overlay(
                    Circle()
                        .strokeBorder(VaporColor.fog, lineWidth: 1)
                )

            if let image = image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.diameter, height: size.diameter)
                    .clipShape(Circle())
            } else if let initials = initials {
                Text(initials.prefix(2).uppercased())
                    .font(.system(size: size.fontSize, weight: .medium))
                    .foregroundColor(VaporColor.textSecondary)
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
struct PageHeader_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading, spacing: 32) {
            PageHeader(kicker: "Archive", title: "Timeline")
            PageHeader(kicker: "Recording", title: "Architecture Review")
            PageHeader(kicker: "People", title: "Directory")
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VaporColor.mist)
    }
}

struct DateHeader_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading, spacing: 16) {
            DateHeader.today
            DateHeader.yesterday
            DateHeader("JANUARY 12")
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VaporColor.mist)
    }
}

struct Avatar_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 16) {
            Avatar(size: .small)
            Avatar(size: .medium)
            Avatar(size: .large)
            Avatar(initials: "JD", size: .medium)
        }
        .padding(24)
        .background(VaporColor.mist)
    }
}
#endif
