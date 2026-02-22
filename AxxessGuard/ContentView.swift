import SwiftUI

struct ContentView: View {
    @StateObject var healthManager = HealthKitManager()
    @StateObject var notificationManager = NotificationManager.shared
    @StateObject var fallDetectionManager = FallDetectionManager()
    @State private var selectedTab = 0
    @State private var showNotificationPanel = false
    @State private var showCriticalAlert = false
    @State private var criticalNotification: AppNotification?

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            // Main tabs
            TabView(selection: $selectedTab) {
                DashboardView(
                    healthManager: healthManager,
                    notificationManager: notificationManager,
                    fallDetectionManager: fallDetectionManager,
                    showNotificationPanel: $showNotificationPanel
                )
                .tag(0)
                RiskModelView(healthManager: healthManager)
                    .tag(1)
                VirtualAssistantView(healthManager: healthManager)
                    .tag(2)
                LifestyleCoachView(healthManager: healthManager)
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            CustomTabBar(selectedTab: $selectedTab)

            // Banner toast — slides in from top
            if notificationManager.showBanner, let banner = notificationManager.bannerNotification {
                NotificationBanner(notification: banner, isShowing: $notificationManager.showBanner)
                    .zIndex(100)
                    .allowsHitTesting(true)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .ignoresSafeArea(edges: .bottom)

        // Notification panel — full screen overlay
        .overlay {
            if showNotificationPanel {
                NotificationPanel(
                    notificationManager: notificationManager,
                    isShowing: $showNotificationPanel
                )
                .zIndex(200)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showNotificationPanel)
            }
        }

        // Critical alert dialog
        .overlay {
            if showCriticalAlert, let alert = criticalNotification {
                CriticalAlertView(
                    notification: alert,
                    onDismiss: {
                        withAnimation(.spring()) { showCriticalAlert = false }
                    },
                    onAlertContacts: {
                        withAnimation(.spring()) { showCriticalAlert = false }
                        if let url = URL(string: "tel://911") {
                            UIApplication.shared.open(url)
                        }
                    }
                )
                .zIndex(300)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: showCriticalAlert)
            }
        }

        // Watch for new critical notifications → show dialog
        .onChange(of: notificationManager.notifications.count) { _ in
            if let latest = notificationManager.notifications.first, latest.type == .critical {
                criticalNotification = latest
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    showCriticalAlert = true
                }
            }
        }

        // Monitor heart rate for alerts
        .onReceive(healthManager.$heartRate) { bpm in
            notificationManager.checkHeartRate(bpm)
        }

        // Start fall detection monitoring on launch
        .onAppear {
            fallDetectionManager.onFallDetected = {
                notificationManager.checkFall()
            }
            fallDetectionManager.startMonitoring()
        }
        .onDisappear {
            fallDetectionManager.stopMonitoring()
        }
    }
}

// MARK: - Dashboard View

struct DashboardView: View {
    @ObservedObject var healthManager: HealthKitManager
    @ObservedObject var notificationManager: NotificationManager
    @ObservedObject var fallDetectionManager: FallDetectionManager
    @Binding var showNotificationPanel: Bool
    @FocusState private var focusedField: Field?

    enum Field { case systolic, diastolic, glucose }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {

                    // ── Title Row + Bell ─────────────────────────────────
                    ZStack {
                        // Centered title
                        VStack(spacing: 4) {
                            Text("AxxessGuard")
                                .font(.largeTitle).bold().foregroundColor(.white)
                            Text("Your AI Health Partner")
                                .font(.subheadline).foregroundColor(.gray)
                        }
                        // Bell pinned to trailing
                        HStack {
                            Spacer()
                            NotificationBellButton(
                                notificationManager: notificationManager,
                                showPanel: $showNotificationPanel
                            )
                        }
                    }
                    .padding(.top, 16)

                    // ── Heart Rate Card ──────────────────────────────────
                    VStack(spacing: 4) {
                        Text("LIVE VITALS")
                            .font(.caption).bold().foregroundColor(.gray)
                        HStack(alignment: .bottom, spacing: 4) {
                            Text("\(Int(healthManager.heartRate))")
                                .font(.system(size: 56, weight: .black)).foregroundColor(.black)
                            Text("BPM")
                                .font(.subheadline).bold().foregroundColor(.gray)
                                .padding(.bottom, 8)
                        }
                        Text("❤️ Heart Rate").font(.subheadline).foregroundColor(.gray)
                        Text("Last Sync: \(healthManager.lastUpdated)").font(.caption2).foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18).padding(.horizontal, 24)
                    .background(Color.white).cornerRadius(24)
                    .shadow(color: .blue.opacity(0.3), radius: 16)

                    // ── Blood Pressure Card ──────────────────────────────
                    VStack(spacing: 6) {
                        HStack {
                            Image(systemName: "heart.fill").foregroundColor(.red)
                            Text("BLOOD PRESSURE").font(.caption).bold().foregroundColor(.gray)
                            Spacer()
                            if !healthManager.systolicBP.isEmpty && !healthManager.diastolicBP.isEmpty {
                                Text(bpStatusLabel())
                                    .font(.caption2).bold()
                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(bpStatusColor().opacity(0.15))
                                    .foregroundColor(bpStatusColor()).cornerRadius(10)
                            }
                        }
                        HStack(spacing: 0) {
                            VStack(spacing: 2) {
                                TextField("120", text: $healthManager.systolicBP)
                                    .font(.system(size: 36, weight: .black)).foregroundColor(.black)
                                    .multilineTextAlignment(.center).keyboardType(.numberPad)
                                    .focused($focusedField, equals: .systolic)
                                    .onChange(of: healthManager.systolicBP) { _ in checkBP() }
                                Text("Systolic").font(.caption).foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            Text("/").font(.system(size: 36, weight: .light)).foregroundColor(.gray)
                            VStack(spacing: 2) {
                                TextField("80", text: $healthManager.diastolicBP)
                                    .font(.system(size: 36, weight: .black)).foregroundColor(.black)
                                    .multilineTextAlignment(.center).keyboardType(.numberPad)
                                    .focused($focusedField, equals: .diastolic)
                                    .onChange(of: healthManager.diastolicBP) { _ in checkBP() }
                                Text("Diastolic").font(.caption).foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        Text("mmHg").font(.subheadline).foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14).padding(.horizontal, 20)
                    .background(Color.white).cornerRadius(24)
                    .shadow(color: .red.opacity(0.2), radius: 16)
                    .onTapGesture { focusedField = nil }

                    // ── Blood Glucose Card ───────────────────────────────
                    VStack(spacing: 6) {
                        HStack {
                            Image(systemName: "drop.fill").foregroundColor(.orange)
                            Text("BLOOD GLUCOSE").font(.caption).bold().foregroundColor(.gray)
                            Spacer()
                            if !healthManager.glucoseLevel.isEmpty {
                                Text(glucoseStatusLabel())
                                    .font(.caption2).bold()
                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(glucoseStatusColor().opacity(0.15))
                                    .foregroundColor(glucoseStatusColor()).cornerRadius(10)
                            }
                        }
                        HStack(alignment: .bottom, spacing: 4) {
                            TextField("100", text: $healthManager.glucoseLevel)
                                .font(.system(size: 56, weight: .black)).foregroundColor(.black)
                                .multilineTextAlignment(.center).keyboardType(.numberPad)
                                .focused($focusedField, equals: .glucose)
                                .onChange(of: healthManager.glucoseLevel) { _ in checkGlucose() }
                            Text("mg/dL")
                                .font(.subheadline).bold().foregroundColor(.gray).padding(.bottom, 8)
                        }
                        Text("🩸 Blood Sugar").font(.subheadline).foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14).padding(.horizontal, 20)
                    .background(Color.white).cornerRadius(24)
                    .shadow(color: .orange.opacity(0.2), radius: 16)
                    .onTapGesture { focusedField = nil }

                    // ── Steps & SpO2 ─────────────────────────────────────
                    HStack(spacing: 14) {
                        SecondaryVitalCard(icon: "figure.walk", label: "Steps",
                                           value: "\(Int(healthManager.stepCount))", color: .blue)
                        SecondaryVitalCard(icon: "lungs.fill", label: "SpO2",
                                           value: healthManager.oxygenSaturation > 0
                                                  ? "\(Int(healthManager.oxygenSaturation))%" : "—",
                                           color: .cyan)
                    }

                    // ── Enable Tracking Button ───────────────────────────
                    Button(action: {
                        healthManager.requestAuthorization()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            notificationManager.send(AppNotification(
                                type: .info,
                                title: "Real-Time Tracking Enabled",
                                message: "AxxessGuard is now monitoring your heart rate, steps, and SpO2. Stay healthy!",
                                timestamp: Date()
                            ))
                        }
                    }) {
                        HStack {
                            Image(systemName: "applewatch")
                            Text("Enable Real-Time Tracking").bold()
                        }
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.blue).foregroundColor(.white).cornerRadius(15)
                    }

                    // ── Fall Detection Status ────────────────────────────
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(fallDetectionManager.isMonitoring
                                      ? Color.green.opacity(0.15)
                                      : Color.gray.opacity(0.1))
                                .frame(width: 40, height: 40)
                            Image(systemName: fallDetectionManager.isFallDetected
                                  ? "figure.fall"
                                  : "figure.stand")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(fallDetectionManager.isFallDetected ? .red
                                                 : fallDetectionManager.isMonitoring ? .green : .gray)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Fall Detection")
                                .font(.subheadline).bold()
                                .foregroundColor(.white)
                            Text(fallDetectionManager.isFallDetected
                                 ? "Fall Detected!"
                                 : fallDetectionManager.isMonitoring
                                   ? "Active — Monitoring motion"
                                   : "Not monitoring")
                                .font(.caption)
                                .foregroundColor(fallDetectionManager.isFallDetected ? .red
                                                 : fallDetectionManager.isMonitoring ? .green : .gray)
                        }
                        Spacer()
                        // Active pulse dot
                        if fallDetectionManager.isMonitoring {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                                .shadow(color: .green, radius: 4)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                fallDetectionManager.isFallDetected ? Color.red.opacity(0.5)
                                : fallDetectionManager.isMonitoring ? Color.green.opacity(0.25)
                                : Color.white.opacity(0.08),
                                lineWidth: 1
                            )
                    )

                    Spacer(minLength: 100)
                }
                .padding(20)
            }
            .onTapGesture { focusedField = nil }
        }
    }

    // MARK: - Health Alert Triggers

    func checkBP() {
        guard let sys = Int(healthManager.systolicBP),
              let dia = Int(healthManager.diastolicBP) else { return }
        notificationManager.checkBloodPressure(systolic: sys, diastolic: dia)
    }

    func checkGlucose() {
        guard let g = Double(healthManager.glucoseLevel) else { return }
        notificationManager.checkGlucose(g)
    }

    // MARK: - Status Helpers

    func bpStatusColor() -> Color {
        guard let sys = Int(healthManager.systolicBP), let dia = Int(healthManager.diastolicBP) else { return .gray }
        if sys > 180 || dia > 120 { return .red }
        if sys >= 140 || dia >= 90 { return Color(red: 0.85, green: 0.3, blue: 0.1) }
        if (sys >= 130 && sys <= 139) || (dia >= 81 && dia <= 89) { return .orange }
        if sys >= 120 && sys <= 129 { return .yellow }
        return .green
    }

    func bpStatusLabel() -> String {
        guard let sys = Int(healthManager.systolicBP), let dia = Int(healthManager.diastolicBP) else { return "" }
        if sys > 180 || dia > 120 { return "CRISIS" }
        if sys >= 140 || dia >= 90 { return "HIGH 2" }
        if (sys >= 130 && sys <= 139) || (dia >= 81 && dia <= 89) { return "HIGH 1" }
        if sys >= 120 && sys <= 129 { return "ELEVATED" }
        return "NORMAL"
    }

    func glucoseStatusColor() -> Color {
        guard let g = Double(healthManager.glucoseLevel) else { return .gray }
        if g < 70 { return .red }
        if g <= 99 { return .green }
        if g <= 125 { return .yellow }
        return .red
    }

    func glucoseStatusLabel() -> String {
        guard let g = Double(healthManager.glucoseLevel) else { return "" }
        if g < 70 { return "LOW" }
        if g <= 99 { return "NORMAL" }
        if g <= 125 { return "PRE-DIABETIC" }
        return "HIGH"
    }
}

// MARK: - Secondary Vital Card

struct SecondaryVitalCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title2).foregroundColor(color)
            Text(value).font(.title2).bold().foregroundColor(.black)
            Text(label).font(.caption).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity).padding(20)
        .background(Color.white).cornerRadius(20)
        .shadow(color: color.opacity(0.2), radius: 8)
    }
}

// MARK: - Custom Tab Bar

struct CustomTabBar: View {
    @Binding var selectedTab: Int

    let tabs: [(icon: String, label: String)] = [
        ("house.fill", "Home"),
        ("brain.head.profile", "Risk"),
        ("message.fill", "Assistant"),
        ("heart.text.square.fill", "Coach")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                Button(action: { selectedTab = index }) {
                    VStack(spacing: 4) {
                        Image(systemName: tabs[index].icon)
                            .font(.system(size: 20))
                            .foregroundColor(selectedTab == index ? .blue : .gray)
                        Text(tabs[index].label)
                            .font(.caption2)
                            .foregroundColor(selectedTab == index ? .blue : .gray)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                }
            }
        }
        .padding(.horizontal, 10).padding(.bottom, 20)
        .background(
            RoundedRectangle(cornerRadius: 30)
                .fill(Color(white: 0.12))
                .shadow(color: .black.opacity(0.4), radius: 20)
        )
        .padding(.horizontal, 20).padding(.bottom, 10)
    }
}
