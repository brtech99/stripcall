import WatchConnectivity
import Flutter

/// Manages WatchConnectivity session on the iPhone side.
/// Bridges Flutter MethodChannel ↔ WCSession to send problem data to watch
/// and receive "On my way" actions from watch.
///
/// When the watch sends "goOnMyWay", this class calls the Supabase edge
/// function directly via URLSession — no Flutter engine needed. This allows
/// it to work even when the iPhone is locked and Flutter is suspended.
class WatchSessionManager: NSObject, WCSessionDelegate {
    static let shared = WatchSessionManager()

    private var methodChannel: FlutterMethodChannel?

    // Cached credentials for native API calls (synced from Flutter)
    private var accessToken: String?
    private var userId: String?
    private var supabaseUrl: String?
    private var supabaseAnonKey: String?

    private let defaults = UserDefaults.standard

    func configure(with controller: FlutterViewController) {
        methodChannel = FlutterMethodChannel(
            name: "us.stripcall/watch",
            binaryMessenger: controller.binaryMessenger
        )

        methodChannel?.setMethodCallHandler { [weak self] call, result in
            switch call.method {
            case "updateProblems":
                if let args = call.arguments as? [String: Any],
                   let jsonString = args["problemsJson"] as? String {
                    self?.sendProblemsToWatch(jsonString)
                    result(nil)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing problemsJson", details: nil))
                }
            case "syncCredentials":
                if let args = call.arguments as? [String: Any] {
                    self?.accessToken = args["accessToken"] as? String
                    self?.userId = args["userId"] as? String
                    self?.supabaseUrl = args["supabaseUrl"] as? String
                    self?.supabaseAnonKey = args["supabaseAnonKey"] as? String
                    // Persist for process restart scenarios
                    self?.defaults.set(self?.accessToken, forKey: "sc_accessToken")
                    self?.defaults.set(self?.userId, forKey: "sc_userId")
                    self?.defaults.set(self?.supabaseUrl, forKey: "sc_supabaseUrl")
                    self?.defaults.set(self?.supabaseAnonKey, forKey: "sc_supabaseAnonKey")
                    result(nil)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing credentials", details: nil))
                }
            case "isWatchReachable":
                if WCSession.isSupported() {
                    result(WCSession.default.isReachable)
                } else {
                    result(false)
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        // Load any persisted credentials
        loadPersistedCredentials()

        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    private func loadPersistedCredentials() {
        if accessToken == nil { accessToken = defaults.string(forKey: "sc_accessToken") }
        if userId == nil { userId = defaults.string(forKey: "sc_userId") }
        if supabaseUrl == nil { supabaseUrl = defaults.string(forKey: "sc_supabaseUrl") }
        if supabaseAnonKey == nil { supabaseAnonKey = defaults.string(forKey: "sc_supabaseAnonKey") }
    }

    /// Send problem data to watch via updateApplicationContext (guaranteed latest delivery).
    private func sendProblemsToWatch(_ jsonString: String) {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated,
              WCSession.default.isPaired,
              WCSession.default.isWatchAppInstalled else { return }

        do {
            try WCSession.default.updateApplicationContext([
                "problemsJson": jsonString,
                "timestamp": Date().timeIntervalSince1970
            ])
        } catch {
            print("WatchSession: Failed to update context: \(error)")
        }
    }

    // MARK: - WCSessionDelegate (iPhone side)

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        print("WatchSession iOS: activated, state=\(activationState.rawValue)")
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate for watch switching scenarios
        WCSession.default.activate()
    }

    /// Receive "On my way" action from watch.
    /// Calls the Supabase edge function directly — works even when Flutter is suspended.
    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        if let action = message["action"] as? String, action == "goOnMyWay",
           let problemId = message["problemId"] as? Int {

            // Load persisted credentials if needed
            loadPersistedCredentials()

            if let url = supabaseUrl, let anonKey = supabaseAnonKey,
               let token = accessToken, let uid = userId {
                callGoOnMyWayEdgeFunction(
                    problemId: problemId,
                    userId: uid,
                    supabaseUrl: url,
                    anonKey: anonKey,
                    accessToken: token,
                    replyHandler: replyHandler
                )
            } else {
                print("WatchSession: No cached credentials, falling back to Flutter")
                forwardToFlutter(problemId: problemId, replyHandler: replyHandler)
            }
        } else {
            replyHandler(["success": false, "error": "Unknown action"])
        }
    }

    // MARK: - Native edge function call

    private func callGoOnMyWayEdgeFunction(
        problemId: Int,
        userId: String,
        supabaseUrl: String,
        anonKey: String,
        accessToken: String,
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        let urlString = "\(supabaseUrl)/functions/v1/go-on-my-way"
        guard let url = URL(string: urlString) else {
            replyHandler(["success": false, "error": "Invalid URL"])
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.timeoutInterval = 15

        let body: [String: Any] = [
            "problemId": problemId,
            "userId": userId
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        print("WatchSession: Calling go-on-my-way edge function for problem \(problemId)")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("WatchSession: Edge function error: \(error)")
                replyHandler(["success": false, "error": error.localizedDescription])
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                replyHandler(["success": false, "error": "No response"])
                return
            }

            if httpResponse.statusCode == 200 {
                print("WatchSession: go-on-my-way succeeded")
                replyHandler(["success": true])
            } else {
                let errorMsg = data.flatMap { String(data: $0, encoding: .utf8) } ?? "Unknown"
                print("WatchSession: Edge function HTTP \(httpResponse.statusCode): \(errorMsg)")
                replyHandler(["success": false, "error": "Server error: \(httpResponse.statusCode)"])
            }
        }.resume()
    }

    /// Handle "On my way" from a notification action tap (on iPhone)
    func handleOnMyWay(problemId: Int) {
        loadPersistedCredentials()

        if let url = supabaseUrl, let anonKey = supabaseAnonKey,
           let token = accessToken, let uid = userId {
            callGoOnMyWayEdgeFunction(
                problemId: problemId,
                userId: uid,
                supabaseUrl: url,
                anonKey: anonKey,
                accessToken: token,
                replyHandler: { result in
                    print("WatchSession: handleOnMyWay result: \(result)")
                }
            )
        } else {
            forwardToFlutter(problemId: problemId, replyHandler: { _ in })
        }
    }

    /// Fallback: forward to Flutter MethodChannel (only works when Flutter is active)
    private func forwardToFlutter(problemId: Int, replyHandler: @escaping ([String: Any]) -> Void) {
        DispatchQueue.main.async { [weak self] in
            self?.methodChannel?.invokeMethod(
                "onWatchGoOnMyWay",
                arguments: ["problemId": problemId]
            ) { result in
                if let error = result as? FlutterError {
                    replyHandler(["success": false, "error": error.message ?? "Unknown error"])
                } else {
                    replyHandler(["success": true])
                }
            }
        }
    }
}
