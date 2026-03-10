import Foundation

struct WatchProblem: Codable, Identifiable {
    let id: Int
    let strip: String
    let symptom: String
    let status: String // "new", "en_route", "resolved"
    let originatorName: String
    let startTime: String // ISO 8601
    let responders: [Responder]
    let messages: [Message]
    let resolution: String?
    let resolvedBy: String?
    let resolvedAt: String?
    let notes: String?

    struct Responder: Codable, Identifiable {
        let name: String
        let respondedAt: String

        var id: String { name + respondedAt }
    }

    struct Message: Codable, Identifiable {
        let text: String
        let createdAt: String

        var id: String { createdAt + text.prefix(20) }
    }

    var isResolved: Bool { status == "resolved" }

    var formattedStartTime: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: startTime) else {
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: startTime) else { return "" }
            return Self.timeFormatter.string(from: date)
        }
        return Self.timeFormatter.string(from: date)
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
}
