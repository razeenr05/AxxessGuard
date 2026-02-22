import SwiftUI
import Combine
import UserNotifications

// MARK: - Notification Model

struct AppNotification: Identifiable {
    let id = UUID()
    let type: NotificationType
    let title: String
    let message: String
    let timestamp: Date
    var isRead: Bool = false

    enum NotificationType {
        case critical       // Red — e.g. high heart rate, crisis BP
        case warning        // Orange — e.g. elevated BP, high glucose
        case info           // Blue — e.g. daily summary
        case success        // Green — e.g. goal met

        var color: Color {
            switch self {
            case .critical: return .red
            case .warning:  return .orange
            case .info:     return .blue
            case .success:  return Color(red: 0.2, green: 0.72, blue: 0.4)
            }
        }

        var icon: String {
            switch self {
            case .critical: return "exclamationmark.heart.fill"
            case .warning:  return "exclamationmark.triangle.fill"
            case .info:     return "bell.badge.fill"
            case .success:  return "checkmark.seal.fill"
            }
        }

        var backgroundGradient: [Color] {
            switch self {
            case .critical: return [Color.red.opacity(0.18), Color.red.opacity(0.06)]
            case .warning:  return [Color.orange.opacity(0.18), Color.orange.opacity(0.06)]
            case .info:     return [Color.blue.opacity(0.18), Color.blue.opacity(0.06)]
            case .success:  return [Color.green.opacity(0.18), Color.green.opacity(0.06)]
            }
        }
    }
}

// MARK: - Notification Manager

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var notifications: [AppNotification] = []
    @Published var showBanner: Bool = false
    @Published var bannerNotification: AppNotification?

    // Throttle — avoid spamming same alert
    private var lastHighHRAlert: Date = .distantPast
    private var lastBPAlert: Date = .distantPast
    private var lastGlucoseAlert: Date = .distantPast
    private var lastDailySummary: Date = .distantPast
    private let alertCooldown: TimeInterval = 60 // seconds between same-type alerts

    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    init() {
        requestSystemPermission()
        scheduleDailySummary()
    }

    // MARK: - Permission

    func requestSystemPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    // MARK: - Send Notification

    func send(_ notification: AppNotification) {
        DispatchQueue.main.async {
            self.notifications.insert(notification, at: 0)
            self.bannerNotification = notification
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                self.showBanner = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                withAnimation(.easeOut(duration: 0.3)) {
                    self.showBanner = false
                }
            }
        }
    }

    func markAllRead() {
        for i in notifications.indices {
            notifications[i].isRead = true
        }
    }

    func markRead(_ id: UUID) {
        if let i = notifications.firstIndex(where: { $0.id == id }) {
            notifications[i].isRead = true
        }
    }

    func clearAll() {
        notifications.removeAll()
    }

    // MARK: - Health Triggers

    func checkHeartRate(_ bpm: Double) {
        guard bpm > 0 else { return }
        let now = Date()

        // Critical: > 120 BPM
        if bpm > 120 && now.timeIntervalSince(lastHighHRAlert) > alertCooldown {
            lastHighHRAlert = now
            send(AppNotification(
                type: .critical,
                title: "⚠️ High Heart Rate Detected",
                message: "Your heart rate is currently \(Int(bpm)) BPM. Please sit down and rest. If you feel chest pain or shortness of breath, contact emergency services immediately.",
                timestamp: now
            ))
        }
        // Warning: 100–120 BPM
        else if bpm >= 100 && bpm <= 120 && now.timeIntervalSince(lastHighHRAlert) > alertCooldown {
            lastHighHRAlert = now
            send(AppNotification(
                type: .warning,
                title: "Elevated Heart Rate",
                message: "Your heart rate is \(Int(bpm)) BPM, slightly above the normal resting range. Take a moment to breathe slowly and relax.",
                timestamp: now
            ))
        }
        // Low: < 50 BPM
        else if bpm < 50 && now.timeIntervalSince(lastHighHRAlert) > alertCooldown {
            lastHighHRAlert = now
            send(AppNotification(
                type: .warning,
                title: "Low Heart Rate Detected",
                message: "Your heart rate is \(Int(bpm)) BPM, which is below the normal resting range. If you feel dizzy or faint, seek medical attention.",
                timestamp: now
            ))
        }
    }

    func checkBloodPressure(systolic: Int, diastolic: Int) {
        let now = Date()
        guard now.timeIntervalSince(lastBPAlert) > alertCooldown else { return }

        if systolic > 180 || diastolic > 120 {
            lastBPAlert = now
            send(AppNotification(
                type: .critical,
                title: "🚨 Hypertensive Crisis",
                message: "BP \(systolic)/\(diastolic) mmHg is dangerously high. Seek emergency medical care immediately.",
                timestamp: now
            ))
        } else if systolic >= 140 || diastolic >= 90 {
            lastBPAlert = now
            send(AppNotification(
                type: .warning,
                title: "High Blood Pressure (Stage 2)",
                message: "Your BP is \(systolic)/\(diastolic) mmHg. This is Stage 2 Hypertension. Contact your doctor as soon as possible.",
                timestamp: now
            ))
        } else if (systolic >= 130 && systolic <= 139) || (diastolic >= 81 && diastolic <= 89) {
            lastBPAlert = now
            send(AppNotification(
                type: .warning,
                title: "High Blood Pressure (Stage 1)",
                message: "Your BP is \(systolic)/\(diastolic) mmHg. Consider reducing sodium intake, exercising regularly, and consulting your doctor.",
                timestamp: now
            ))
        }
    }

    func checkGlucose(_ glucose: Double) {
        let now = Date()
        guard now.timeIntervalSince(lastGlucoseAlert) > alertCooldown else { return }

        if glucose > 250 {
            lastGlucoseAlert = now
            send(AppNotification(
                type: .critical,
                title: "⚠️ Critically High Blood Sugar",
                message: "Your glucose is \(Int(glucose)) mg/dL. This level is dangerously high. Contact your healthcare provider immediately.",
                timestamp: now
            ))
        } else if glucose > 125 {
            lastGlucoseAlert = now
            send(AppNotification(
                type: .warning,
                title: "High Blood Sugar",
                message: "Your glucose is \(Int(glucose)) mg/dL, above the normal fasting range. Consider reducing sugar intake and staying hydrated.",
                timestamp: now
            ))
        } else if glucose < 70 {
            lastGlucoseAlert = now
            send(AppNotification(
                type: .critical,
                title: "⚠️ Low Blood Sugar",
                message: "Your glucose is \(Int(glucose)) mg/dL, which is below the healthy range. Consume fast-acting carbohydrates immediately.",
                timestamp: now
            ))
        }
    }

    func sendDailySummary(heartRate: Double, steps: Int) {
        let now = Date()
        guard now.timeIntervalSince(lastDailySummary) > 3600 * 6 else { return }
        lastDailySummary = now

        let hrHealthy = heartRate > 0 && heartRate >= 60 && heartRate <= 100
        let stepsGood = steps >= 7500

        if hrHealthy && stepsGood {
            send(AppNotification(
                type: .success,
                title: "Daily Health Insights",
                message: "Great job! Your heart rate stayed within the healthy range and you've logged \(steps) steps today. Keep it up!",
                timestamp: now
            ))
        } else if steps < 3000 && steps > 0 {
            send(AppNotification(
                type: .info,
                title: "Daily Health Insights",
                message: "You've taken \(steps) steps today. Try to reach 7,500 steps for optimal cardiovascular health. A short walk can make a big difference!",
                timestamp: now
            ))
        } else {
            send(AppNotification(
                type: .info,
                title: "Daily Health Insights",
                message: "Your health data has been recorded for today. Keep monitoring your vitals and stay active for best results.",
                timestamp: now
            ))
        }
    }

    // MARK: - Fall Detection Alert

    func checkFall() {
        send(AppNotification(
            type: .critical,
            title: "🚨 Potential Fall Detected",
            message: "A sudden fall-like motion was detected. Are you okay? If you need help, tap \"Alert Emergency Contacts\" to notify someone or call for assistance.",
            timestamp: Date()
        ))
    }

    // MARK: - Scheduled Daily Summary (8 AM)

    private func scheduleDailySummary() {
        let content = UNMutableNotificationContent()
        content.title = "Daily Health Insights"
        content.body = "Tap to review your health summary for today."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = 8
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "dailySummary", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
