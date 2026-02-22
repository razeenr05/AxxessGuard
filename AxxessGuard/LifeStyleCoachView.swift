import SwiftUI

struct LifestyleCoachView: View {
    @ObservedObject var healthManager: HealthKitManager
    @State private var dietPlan: String = ""
    @State private var exercisePlan: String = ""
    @State private var isLoadingDiet = false
    @State private var isLoadingExercise = false

    // Multi-select sets
    @State private var selectedGoals: Set<HealthGoal> = [.general]
    @State private var selectedConditions: Set<HealthCondition> = [.none]
    @State private var selectedDiets: Set<DietaryRestriction> = []

    enum HealthGoal: String, CaseIterable {
        case general = "General Wellness"
        case weightLoss = "Weight Loss"
        case heartHealth = "Heart Health"
        case diabetes = "Blood Sugar Control"
        case energy = "Energy & Sleep"
    }

    enum HealthCondition: String, CaseIterable {
        case none = "None"
        case diabetes = "Diabetes"
        case hypertension = "Hypertension"
        case postOp = "Post-Operative"
        case elderly = "Elderly Care"
    }

    enum DietaryRestriction: String, CaseIterable {
        case vegetarian = "Vegetarian"
        case vegan = "Vegan"
        case pescatarian = "Pescatarian"
        case glutenFree = "Gluten-Free"
        case dairyFree = "Dairy-Free"
        case keto = "Keto"
    }

    var goalsText: String {
        selectedGoals.map { $0.rawValue }.joined(separator: ", ")
    }

    var conditionsText: String {
        let filtered = selectedConditions.filter { $0 != .none }
        return filtered.isEmpty ? "None" : filtered.map { $0.rawValue }.joined(separator: ", ")
    }

    var dietText: String {
        selectedDiets.isEmpty ? "No restrictions" : selectedDiets.map { $0.rawValue }.joined(separator: ", ")
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("LIFESTYLE COACH").font(.caption).bold().foregroundColor(.gray)
                        Text("Personalized Plans").font(.title2).bold().foregroundColor(.black)
                        Text("AI-powered diet & exercise based on your vitals and preferences")
                            .font(.caption).foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18).background(Color.white).cornerRadius(20)

                    // Health Goals — multi-select
                    MultiSelectSection(
                        title: "MY HEALTH GOALS",
                        subtitle: "Select all that apply"
                    ) {
                        ForEach(HealthGoal.allCases, id: \.self) { goal in
                            MultiChip(
                                label: goal.rawValue,
                                isSelected: selectedGoals.contains(goal)
                            ) {
                                if selectedGoals.contains(goal) {
                                    if selectedGoals.count > 1 { selectedGoals.remove(goal) }
                                } else {
                                    selectedGoals.insert(goal)
                                }
                            }
                        }
                    }

                    // Health Conditions — multi-select
                    MultiSelectSection(
                        title: "HEALTH CONDITIONS",
                        subtitle: "Select all that apply"
                    ) {
                        ForEach(HealthCondition.allCases, id: \.self) { condition in
                            MultiChip(
                                label: condition.rawValue,
                                isSelected: selectedConditions.contains(condition)
                            ) {
                                if condition == .none {
                                    selectedConditions = [.none]
                                } else {
                                    selectedConditions.remove(.none)
                                    if selectedConditions.contains(condition) {
                                        selectedConditions.remove(condition)
                                        if selectedConditions.isEmpty { selectedConditions = [.none] }
                                    } else {
                                        selectedConditions.insert(condition)
                                    }
                                }
                            }
                        }
                    }

                    // Dietary Restrictions — multi-select
                    MultiSelectSection(
                        title: "DIETARY RESTRICTIONS",
                        subtitle: "Select all that apply"
                    ) {
                        ForEach(DietaryRestriction.allCases, id: \.self) { diet in
                            MultiChip(
                                label: diet.rawValue,
                                isSelected: selectedDiets.contains(diet)
                            ) {
                                if selectedDiets.contains(diet) {
                                    selectedDiets.remove(diet)
                                } else {
                                    selectedDiets.insert(diet)
                                }
                            }
                        }
                    }

                    // Diet Plan Card
                    PlanCard(
                        title: "DIET PLAN",
                        icon: "fork.knife",
                        iconColor: .orange,
                        content: dietPlan,
                        isLoading: isLoadingDiet,
                        placeholder: "Tap \"Generate Diet Plan\" to get your personalized recommendations.",
                        buttonLabel: "Generate Diet Plan",
                        buttonColor: .orange
                    ) { generateDietPlan() }

                    // Exercise Plan Card
                    PlanCard(
                        title: "EXERCISE PLAN",
                        icon: "figure.run",
                        iconColor: .green,
                        content: exercisePlan,
                        isLoading: isLoadingExercise,
                        placeholder: "Tap \"Generate Exercise Plan\" to get your personalized plan.",
                        buttonLabel: "Generate Exercise Plan",
                        buttonColor: .green
                    ) { generateExercisePlan() }

                    // Generate Both Button
                    Button(action: {
                        generateDietPlan()
                        generateExercisePlan()
                    }) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Generate Both Plans").bold()
                        }
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.blue).foregroundColor(.white).cornerRadius(15)
                    }
                    .disabled(isLoadingDiet || isLoadingExercise)

                    Spacer(minLength: 100)
                }
                .padding(16)
            }
        }
    }

    func generateDietPlan() {
        isLoadingDiet = true
        let hr = Int(healthManager.heartRate)
        let steps = Int(healthManager.stepCount)

        let prompt = """
        You are a clinical dietitian AI. Create a concise daily diet plan in under 125 words.

        Patient vitals: Heart Rate \(hr == 0 ? "unknown" : "\(hr) BPM"), BP: \(healthManager.bpDisplay), Glucose: \(healthManager.glucoseDisplay), Steps: \(steps).
        Health goals: \(goalsText).
        Health conditions: \(conditionsText).
        Dietary restrictions: \(dietText).

        Format your response EXACTLY like this — each item on its own line with a bold label followed by the detail:
        **Breakfast:** [1 sentence]
        **Lunch:** [1 sentence]
        **Dinner:** [1 sentence]
        **Snacks:** [1 sentence]
        **Key Tips:** [1-2 sentences specific to their conditions and restrictions]

        Do NOT use asterisks for bullets. Do NOT exceed 125 words. Be specific and respect all dietary restrictions.
        """

        Task {
            do {
                let response = try await FeatherlessService.generate(prompt: prompt)
                await MainActor.run {
                    dietPlan = cleanResponse(response)
                    isLoadingDiet = false
                }
            } catch {
                await MainActor.run {
                    dietPlan = "Unable to generate plan. Please check your connection and try again."
                    isLoadingDiet = false
                }
            }
        }
    }

    func generateExercisePlan() {
        isLoadingExercise = true
        let hr = Int(healthManager.heartRate)
        let steps = Int(healthManager.stepCount)

        let prompt = """
        You are a certified fitness coach AI. Create a concise weekly exercise plan in under 125 words.

        Patient vitals: Heart Rate \(hr == 0 ? "unknown" : "\(hr) BPM"), BP: \(healthManager.bpDisplay), Glucose: \(healthManager.glucoseDisplay), Steps: \(steps).
        Health goals: \(goalsText).
        Health conditions: \(conditionsText).
        Dietary restrictions (for recovery nutrition): \(dietText).

        Format your response EXACTLY like this — each item on its own line with a bold label followed by the detail:
        **Monday/Wednesday/Friday:** [1 sentence activity]
        **Tuesday/Thursday:** [1 sentence activity]
        **Weekend:** [1 sentence activity]
        **Intensity:** [1 sentence appropriate to conditions]
        **Key Tips:** [1 sentence]

        Do NOT use asterisks for bullets. Do NOT exceed 125 words. Adjust intensity for all listed conditions.
        """

        Task {
            do {
                let response = try await FeatherlessService.generate(prompt: prompt)
                await MainActor.run {
                    exercisePlan = cleanResponse(response)
                    isLoadingExercise = false
                }
            } catch {
                await MainActor.run {
                    exercisePlan = "Unable to generate plan. Please check your connection and try again."
                    isLoadingExercise = false
                }
            }
        }
    }

    // Strips leftover markdown asterisks used as bullet points
    func cleanResponse(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        let cleaned = lines.map { line -> String in
            var l = line.trimmingCharacters(in: .whitespaces)
            if l.hasPrefix("* ") { l = l.dropFirst(2).description }
            if l.hasPrefix("- ") { l = l.dropFirst(2).description }
            return l
        }
        return cleaned.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Shared Sub-views

struct MultiSelectSection<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).bold().foregroundColor(.gray)
                Text(subtitle).font(.caption2).foregroundColor(.gray.opacity(0.7))
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) { content() }
            }
        }
        .padding(16).background(Color.white).cornerRadius(20)
    }
}

struct MultiChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark").font(.caption2).fontWeight(.bold)
                }
                Text(label).font(.caption).bold()
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color.blue.opacity(0.08))
            .foregroundColor(isSelected ? .white : .blue)
            .cornerRadius(20)
        }
    }
}

struct PlanCard: View {
    let title: String
    let icon: String
    let iconColor: Color
    let content: String
    let isLoading: Bool
    let placeholder: String
    let buttonLabel: String
    let buttonColor: Color
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon).foregroundColor(iconColor).font(.headline)
                Text(title).font(.caption).bold().foregroundColor(.gray)
                Spacer()
            }
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: iconColor))
                    Spacer()
                }
                .padding(.vertical, 16)
            } else {
                FormattedPlanText(text: content.isEmpty ? placeholder : content,
                                  isEmpty: content.isEmpty)
            }
            Button(action: action) {
                Text(buttonLabel).font(.subheadline).bold()
                    .frame(maxWidth: .infinity).padding(10)
                    .background(buttonColor.opacity(0.15))
                    .foregroundColor(buttonColor).cornerRadius(12)
            }
            .disabled(isLoading)
        }
        .padding(18).background(Color.white).cornerRadius(20)
        .shadow(color: iconColor.opacity(0.1), radius: 8)
    }
}

struct FormattedPlanText: View {
    let text: String
    let isEmpty: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                lineView(for: line)
            }
        }
    }

    @ViewBuilder
    func lineView(for line: String) -> some View {
        // Match lines that start with **SomeHeader:** and have trailing content
        if line.hasPrefix("**"), let endRange = line.range(of: "**", range: line.index(line.startIndex, offsetBy: 2)..<line.endIndex) {
            let header = String(line[line.index(line.startIndex, offsetBy: 2)..<endRange.lowerBound])
            let remainder = String(line[endRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            // Strip leading colon from remainder if present (avoids double colon since header may already end with one)
            let body = remainder.hasPrefix(":") ? String(remainder.dropFirst()).trimmingCharacters(in: .whitespaces) : remainder

            Group {
                if body.isEmpty {
                    Text(header)
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(.black)
                } else {
                    // header already contains the colon (e.g. "Breakfast:"), so just add a space before body
                    Text(header + " ").font(.subheadline).bold().foregroundColor(.black)
                    + Text(body).font(.subheadline).foregroundColor(.black)
                }
            }
        } else if !line.isEmpty {
            Text(line)
                .font(.subheadline)
                .foregroundColor(isEmpty ? .gray : .black)
        }
    }

    var lines: [String] {
        text.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }
}

struct GoalChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label).font(.caption).bold()
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color.blue.opacity(0.08))
                .foregroundColor(isSelected ? .white : .blue)
                .cornerRadius(20)
        }
    }
}
