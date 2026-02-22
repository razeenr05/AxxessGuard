import HealthKit
import Combine
import Foundation

class HealthKitManager: NSObject, ObservableObject {
    let healthStore = HKHealthStore()
    
    @Published var heartRate: Double = 0
    @Published var stepCount: Double = 0
    @Published var oxygenSaturation: Double = 0
    @Published var lastUpdated: String = "Waiting..."
    
    // Manual user entries
    @Published var systolicBP: String = ""
    @Published var diastolicBP: String = ""
    @Published var glucoseLevel: String = ""

    // Session variables to force the sensor to stay ON
    var session: HKWorkoutSession?
    var builder: HKLiveWorkoutBuilder?

    // Computed helpers for AI prompts
    var bpDisplay: String {
        if !systolicBP.isEmpty && !diastolicBP.isEmpty {
            return "\(systolicBP)/\(diastolicBP) mmHg"
        }
        return "not entered"
    }
    
    var glucoseDisplay: String {
        if !glucoseLevel.isEmpty {
            return "\(glucoseLevel) mg/dL"
        }
        return "not entered"
    }

    func requestAuthorization() {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate),
              let stepType = HKObjectType.quantityType(forIdentifier: .stepCount),
              let spo2Type = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) else { return }
        
        let typesToRead: Set<HKObjectType> = [heartRateType, stepType, spo2Type, HKObjectType.workoutType()]
        let typesToShare: Set<HKSampleType> = [HKObjectType.workoutType()]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            if success {
                print("Authorization Successful")
                self.startHeartRateQuery()
                self.fetchStepCount()
                self.fetchOxygenSaturation()
            } else {
                print("Authorization Failed: \(String(describing: error?.localizedDescription))")
            }
        }
    }
    
    func startHeartRateQuery() {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .other
        configuration.locationType = .unknown
        
        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = session?.associatedWorkoutBuilder()
        } catch {
            print("Could not start session")
            return
        }
        
        builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
        session?.startActivity(with: Date())
        builder?.beginCollection(withStart: Date()) { (success, error) in
            print(success ? "Sensor is now ACTIVE" : "Sensor Activation Failed")
        }
        
        let type = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let query = HKAnchoredObjectQuery(type: type, predicate: nil, anchor: nil, limit: HKObjectQueryNoLimit) { _, samples, _, _, _ in
            self.processHeartRate(samples)
        }
        query.updateHandler = { _, samples, _, _, _ in
            self.processHeartRate(samples)
        }
        healthStore.execute(query)
    }
    
    func fetchStepCount() {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date())
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
            DispatchQueue.main.async {
                self.stepCount = stats?.sumQuantity()?.doubleValue(for: .count()) ?? 0
            }
        }
        healthStore.execute(query)
    }
    
    func fetchOxygenSaturation() {
        guard let spo2Type = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) else { return }
        let query = HKSampleQuery(sampleType: spo2Type, predicate: nil, limit: 1, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { _, samples, _ in
            DispatchQueue.main.async {
                if let sample = samples?.first as? HKQuantitySample {
                    self.oxygenSaturation = sample.quantity.doubleValue(for: .percent()) * 100
                }
            }
        }
        healthStore.execute(query)
    }

    private func processHeartRate(_ samples: [HKSample]?) {
        guard let heartRateSamples = samples as? [HKQuantitySample] else { return }
        DispatchQueue.main.async {
            if let lastSample = heartRateSamples.last {
                self.heartRate = lastSample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                let formatter = DateFormatter()
                formatter.timeStyle = .medium
                self.lastUpdated = formatter.string(from: Date())
                print("DEBUG: Live Heart Rate: \(self.heartRate)")
            }
        }
    }
    
    func stopSession() {
        session?.end()
        builder?.endCollection(withEnd: Date()) { _, _ in
            print("Session stopped")
        }
    }
}
