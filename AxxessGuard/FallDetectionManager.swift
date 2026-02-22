import CoreMotion
import Foundation
import Combine
import SwiftUI

// MARK: - Fall Detection Manager
// Uses the iPhone's accelerometer to detect the classic fall signature:
//   Phase 1 — Freefall:  total acceleration drops near 0g (body in air)
//   Phase 2 — Impact:    total acceleration spikes sharply (body hits surface)
// Both phases must occur within a short time window to count as a fall.

class FallDetectionManager: ObservableObject {

    // MARK: - Published State
    @Published var isFallDetected: Bool = false
    @Published var isMonitoring: Bool = false

    // MARK: - Private
    private let motionManager = CMMotionManager()
    private let updateInterval: TimeInterval = 0.02   // 50 Hz sampling rate

    // Thresholds — tuned for realistic falls while minimising false positives
    private let freefallThreshold: Double = 0.35      // g — below this = freefall (normal is ~1.0g)
    private let impactThreshold: Double   = 2.8       // g — above this = hard impact
    private let detectionWindow: TimeInterval = 0.60  // seconds — freefall → impact must occur within this window

    private var freefallDetectedAt: Date? = nil
    private var lastFallAlertAt: Date = .distantPast
    private let fallAlertCooldown: TimeInterval = 30  // seconds between fall alerts

    // Callback fired on the main thread when a fall is confirmed
    var onFallDetected: (() -> Void)?

    // MARK: - Start / Stop

    func startMonitoring() {
        guard motionManager.isAccelerometerAvailable else {
            print("FallDetection: Accelerometer not available on this device.")
            return
        }

        motionManager.accelerometerUpdateInterval = updateInterval
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self = self, let data = data, error == nil else { return }
            self.processAccelerometer(data)
        }

        DispatchQueue.main.async { self.isMonitoring = true }
        print("FallDetection: Monitoring started.")
    }

    func stopMonitoring() {
        motionManager.stopAccelerometerUpdates()
        DispatchQueue.main.async { self.isMonitoring = false }
        print("FallDetection: Monitoring stopped.")
    }

    // MARK: - Core Algorithm

    private func processAccelerometer(_ data: CMAccelerometerData) {
        let ax = data.acceleration.x
        let ay = data.acceleration.y
        let az = data.acceleration.z

        // Total acceleration magnitude (gravity-inclusive)
        let magnitude = sqrt(ax * ax + ay * ay + az * az)

        let now = Date()

        // ── Phase 1: Freefall ─────────────────────────────────────────
        if magnitude < freefallThreshold {
            // Record the moment freefall begins (only once per event)
            if freefallDetectedAt == nil {
                freefallDetectedAt = now
                print("FallDetection: Freefall phase detected — magnitude: \(String(format: "%.2f", magnitude))g")
            }
        }

        // ── Phase 2: Impact ───────────────────────────────────────────
        if let freefallTime = freefallDetectedAt {
            let elapsed = now.timeIntervalSince(freefallTime)

            if elapsed > detectionWindow {
                // Window expired — no impact detected, reset
                freefallDetectedAt = nil
                print("FallDetection: Detection window expired without impact — resetting.")
            } else if magnitude > impactThreshold {
                // Impact confirmed within the detection window!
                freefallDetectedAt = nil  // reset for next event
                print("FallDetection: Impact confirmed — magnitude: \(String(format: "%.2f", magnitude))g, elapsed: \(String(format: "%.2f", elapsed))s")
                triggerFallAlert()
            }
        }
    }

    // MARK: - Alert Trigger

    private func triggerFallAlert() {
        let now = Date()
        guard now.timeIntervalSince(lastFallAlertAt) > fallAlertCooldown else {
            print("FallDetection: Alert suppressed — within cooldown window.")
            return
        }
        lastFallAlertAt = now

        DispatchQueue.main.async {
            self.isFallDetected = true
            self.onFallDetected?()

            // Auto-reset detected flag after a few seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                self.isFallDetected = false
            }
        }
    }
}
