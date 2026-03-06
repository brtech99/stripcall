import WatchConnectivity
import Combine

/// Manages WatchConnectivity session on the watch side.
/// Receives problem data from iPhone and sends "On my way" actions back.
class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSessionManager()

    @Published var problems: [WatchProblem] = []
    @Published var isPhoneReachable: Bool = false
    @Published var lastUpdateTime: Date? = nil

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        DispatchQueue.main.async {
            self.isPhoneReachable = session.isReachable
        }
        // Load cached data from last received context
        if let context = WCSession.default.receivedApplicationContext as? [String: Any],
           let json = context["problemsJson"] as? String {
            parseAndUpdateProblems(json)
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isPhoneReachable = session.isReachable
        }
    }

    /// Receive updated problem data from iPhone via applicationContext.
    func session(_ session: WCSession,
                 didReceiveApplicationContext applicationContext: [String: Any]) {
        if let json = applicationContext["problemsJson"] as? String {
            parseAndUpdateProblems(json)
        }
    }

    /// Send "On my way" action to iPhone.
    func goOnMyWay(problemId: Int, completion: @escaping (Bool, String?) -> Void) {
        guard WCSession.default.isReachable else {
            completion(false, "iPhone not reachable")
            return
        }

        WCSession.default.sendMessage(
            ["action": "goOnMyWay", "problemId": problemId],
            replyHandler: { reply in
                let success = reply["success"] as? Bool ?? false
                let error = reply["error"] as? String
                DispatchQueue.main.async {
                    completion(success, error)
                }
            },
            errorHandler: { error in
                DispatchQueue.main.async {
                    completion(false, error.localizedDescription)
                }
            }
        )
    }

    private func parseAndUpdateProblems(_ jsonString: String) {
        guard let data = jsonString.data(using: .utf8) else { return }
        do {
            let decoded = try JSONDecoder().decode([WatchProblem].self, from: data)
            DispatchQueue.main.async {
                self.problems = decoded
                self.lastUpdateTime = Date()
            }
        } catch {
            print("WatchSession: Failed to decode problems: \(error)")
        }
    }
}
