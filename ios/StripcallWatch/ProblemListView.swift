import SwiftUI

struct ProblemListView: View {
    @EnvironmentObject var session: WatchSessionManager

    var body: some View {
        List {
            ForEach(session.problems) { problem in
                NavigationLink(destination: ProblemDetailView(problem: problem)) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(colorForStatus(problem.status))
                            .frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Strip \(problem.strip)")
                                .font(.headline)
                                .lineLimit(1)
                            Text(problem.symptom)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .navigationTitle("Problems")
    }

    private func colorForStatus(_ status: String) -> Color {
        switch status {
        case "new": return .red
        case "en_route": return .yellow
        case "resolved": return .green
        default: return .gray
        }
    }
}
