import SwiftUI

struct ProblemDetailView: View {
    let problem: WatchProblem
    @EnvironmentObject var session: WatchSessionManager
    @State private var isSending = false
    @State private var showConfirmation = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    Circle()
                        .fill(colorForStatus(problem.status))
                        .frame(width: 12, height: 12)
                    Text("Strip \(problem.strip)")
                        .font(.headline)
                }

                Text(problem.symptom)
                    .font(.subheadline)

                Text("Reported by \(problem.originatorName)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(problem.formattedStartTime)
                    .font(.caption2)
                    .foregroundColor(.secondary)

                // Responders
                if !problem.responders.isEmpty {
                    Divider()
                    Text("Responding:")
                        .font(.caption)
                        .foregroundColor(.orange)
                    ForEach(problem.responders) { responder in
                        Text("  \(responder.name)")
                            .font(.caption2)
                    }
                }

                // Resolution
                if let resolution = problem.resolution {
                    Divider()
                    Label(resolution, systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                    if let resolvedBy = problem.resolvedBy {
                        Text("by \(resolvedBy)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // Messages (last 3)
                if !problem.messages.isEmpty {
                    Divider()
                    Text("Messages:")
                        .font(.caption)
                    ForEach(problem.messages.suffix(3)) { msg in
                        Text(msg.text)
                            .font(.caption2)
                            .padding(.vertical, 1)
                    }
                }

                // "On my way" button
                if !problem.isResolved {
                    Divider()
                    Button(action: { sendOnMyWay() }) {
                        HStack {
                            if isSending {
                                ProgressView()
                                    .frame(width: 16, height: 16)
                            } else {
                                Image(systemName: "figure.walk")
                            }
                            Text("On my way")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(isSending || !session.isPhoneReachable)
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal)
        }
        .navigationTitle("Strip \(problem.strip)")
        .overlay {
            if showConfirmation {
                VStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green)
                    Text("Sent!")
                        .font(.headline)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private func sendOnMyWay() {
        isSending = true
        errorMessage = nil

        session.goOnMyWay(problemId: problem.id) { success, error in
            isSending = false
            if success {
                withAnimation {
                    showConfirmation = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation {
                        showConfirmation = false
                    }
                }
            } else {
                errorMessage = error ?? "Failed to send"
            }
        }
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
