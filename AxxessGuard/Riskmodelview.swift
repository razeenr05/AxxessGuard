import SwiftUI

struct RiskModelView: View {
    @ObservedObject var healthManager: HealthKitManager
    @State private var riskSummary: String = "Tap Analyze to get your AI risk assessment."
    @State private var isLoading = false
    @State private var riskLevel: RiskLevel = .unknown

    enum RiskLevel {
        case unknown, low, moderate, high
        var color: Color {
            switch self {
            case .unknown: return .gray
            case .low: return .green
            case .moderate: return .yellow
            case .high: return .red
            }
        }
        var label: String {
            switch self {
            case .unknown: return "—"
            case .low: return "LOW RISK"
            case .moderate: return "MODERATE"
            case .high: return "HIGH RISK"
            }
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("PREDICTIVE RISK")
                                .font(.caption)
                                .bold()
                                .foregroundColor(.gray)
                            Text("AI Health Analysis")
                                .font(.title2)
                                .bold()
                                .foregroundColor(.black)
                        }
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(riskLevel.color.opacity(0.2))
                                .frame(width: 60, height: 60)
                            Text(riskLevel == .unknown ? "?" : "!")
                                .font(.title2)
                                .bold()
                                .foregroundColor(riskLevel.color)
                        }
                    }
                    .padding(20)
                    .background(Color.white)
                    .cornerRadius(20)

                    // Scrollable Vitals
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("CURRENT VITALS")
                                .font(.caption)
                                .bold()
                                .foregroundColor(.gray)
                            Spacer()
                            Text("Swipe for more →")
                                .font(.caption2)
                                .foregroundColor(.gray.opacity(0.7))
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                VitalChip(
                                    label: "Heart Rate",
                                    value: healthManager.heartRate > 0 ? "\(Int(healthManager.heartRate)) BPM" : "—",
                                    color: .red,
                                    icon: "heart.fill"
                                )
                                VitalChip(
                                    label: "Blood Pressure",
                                    value: (!healthManager.systolicBP.isEmpty && !healthManager.diastolicBP.isEmpty)
                                        ? "\(healthManager.systolicBP)/\(healthManager.diastolicBP)"
                                        : "Not entered",
                                    color: .pink,
                                    icon: "waveform.path.ecg"
                                )
                                VitalChip(
                                    label: "Glucose",
                                    value: !healthManager.glucoseLevel.isEmpty
                                        ? "\(healthManager.glucoseLevel) mg/dL"
                                        : "Not entered",
                                    color: .orange,
                                    icon: "drop.fill"
                                )
                                VitalChip(
                                    label: "Steps Today",
                                    value: "\(Int(healthManager.stepCount))",
                                    color: .blue,
                                    icon: "figure.walk"
                                )
                                VitalChip(
                                    label: "SpO2",
                                    value: healthManager.oxygenSaturation > 0
                                        ? "\(Int(healthManager.oxygenSaturation))%"
                                        : "—",
                                    color: .cyan,
                                    icon: "lungs.fill"
                                )
                            }
                            .padding(.horizontal, 2)
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(20)
                    .background(Color.white)
                    .cornerRadius(20)

                    // Risk Badge
                    HStack {
                        Spacer()
                        Text(riskLevel.label)
                            .font(.headline)
                            .bold()
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(riskLevel.color.opacity(0.2))
                            .foregroundColor(riskLevel.color)
                            .cornerRadius(20)
                        Spacer()
                    }

                    // AI Analysis Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("AI ASSESSMENT")
                            .font(.caption)
                            .bold()
                            .foregroundColor(.gray)
                        if isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                    .scaleEffect(1.3)
                                Spacer()
                            }
                            .padding(.vertical, 20)
                        } else {
                            Text(riskSummary)
                                .font(.body)
                                .foregroundColor(.black)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: .blue.opacity(0.1), radius: 10)

                    // Analyze Button
                    Button(action: analyzeRisk) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                            Text("Analyze My Risk")
                                .bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(15)
                    }
                    .disabled(isLoading)
                    
                    Spacer(minLength: 100)
                }
                .padding(20)
            }
        }
    }

    func analyzeRisk() {
        isLoading = true
        let hr = Int(healthManager.heartRate)
        let steps = Int(healthManager.stepCount)
        let spo2 = Int(healthManager.oxygenSaturation)

        let prompt = """
        You are a preventive health AI. Analyze these vitals and give a brief, clear risk assessment (2-3 sentences max).
        - Heart Rate: \(hr == 0 ? "unavailable" : "\(hr) BPM")
        - Blood Pressure: \(healthManager.bpDisplay)
        - Blood Glucose: \(healthManager.glucoseDisplay)
        - Steps Today: \(steps)
        - Oxygen Saturation: \(spo2 == 0 ? "unavailable" : "\(spo2)%")
        
        End your response with one of these exact labels on a new line: RISK:LOW, RISK:MODERATE, or RISK:HIGH.
        """

        Task {
            do {
                let response = try await FeatherlessService.generate(prompt: prompt)
                await MainActor.run {
                    if response.contains("RISK:HIGH") {
                        riskLevel = .high
                    } else if response.contains("RISK:MODERATE") {
                        riskLevel = .moderate
                    } else if response.contains("RISK:LOW") {
                        riskLevel = .low
                    }
                    riskSummary = response
                        .replacingOccurrences(of: "RISK:HIGH", with: "")
                        .replacingOccurrences(of: "RISK:MODERATE", with: "")
                        .replacingOccurrences(of: "RISK:LOW", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    riskSummary = "Unable to connect to AI service: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

struct VitalChip: View {
    let label: String
    let value: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(value)
                .font(.headline)
                .bold()
                .foregroundColor(value == "Not entered" || value == "—" ? .gray : color)
                .multilineTextAlignment(.center)
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(width: 110)
        .padding(.vertical, 14)
        .padding(.horizontal, 10)
        .background(color.opacity(0.08))
        .cornerRadius(16)
    }
}
