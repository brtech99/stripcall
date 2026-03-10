import SwiftUI

struct ContentView: View {
    @EnvironmentObject var session: WatchSessionManager

    var body: some View {
        NavigationStack {
            if session.problems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.green)
                    Text("No active problems")
                        .font(.headline)
                    if !session.isPhoneReachable {
                        Label("iPhone not connected", systemImage: "iphone.slash")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                ProblemListView()
            }
        }
    }
}
