import SwiftUI

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let text: String
    let timestamp: Date

    enum Role {
        case user, assistant
    }
}

struct VirtualAssistantView: View {
    @ObservedObject var healthManager: HealthKitManager
    @State private var messages: [ChatMessage] = [
        ChatMessage(role: .assistant, text: "Hello! I'm your AxxessGuard health assistant. I can help with symptom triage, medication reminders, and health questions. How are you feeling today?", timestamp: Date())
    ]
    @State private var inputText = ""
    @State private var isTyping = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 4) {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.2))
                                .frame(width: 44, height: 44)
                            Image(systemName: "stethoscope")
                                .foregroundColor(.blue)
                                .font(.headline)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Health Assistant")
                                .font(.headline)
                                .bold()
                                .foregroundColor(.black)
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 7, height: 7)
                                Text("Online")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                        Spacer()
                        Text("AI Powered")
                            .font(.caption2)
                            .bold()
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(10)
                    }
                    .padding(16)
                }
                .background(Color.white)
                .cornerRadius(20)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .shadow(color: .blue.opacity(0.1), radius: 8)

                // Messages with quick prompts at the top
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            // Quick prompts inside scroll area so they don't overlap input
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    QuickPromptChip(label: "I have chest pain") { sendMessage("I'm experiencing chest pain") }
                                    QuickPromptChip(label: "Medication reminder") { sendMessage("Set up a medication reminder for me") }
                                    QuickPromptChip(label: "Sleep issues") { sendMessage("I've been having trouble sleeping lately") }
                                    QuickPromptChip(label: "Stress & anxiety") { sendMessage("I'm feeling stressed and anxious") }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                            }

                            LazyVStack(spacing: 12) {
                                ForEach(messages) { message in
                                    MessageBubble(message: message)
                                        .id(message.id.uuidString)
                                }
                                if isTyping {
                                    TypingIndicator()
                                        .id("typing")
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 10)
                        }
                    }
                    .onChange(of: messages.count) { _ in
                        withAnimation {
                            if let lastId = messages.last?.id.uuidString {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: isTyping) { _ in
                        withAnimation {
                            proxy.scrollTo("typing", anchor: .bottom)
                        }
                    }
                }

                // Input Bar — pinned to bottom, always visible
                HStack(spacing: 10) {
                    TextField("Ask about symptoms, medications...", text: $inputText)
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(20)
                        .focused($isInputFocused)
                        .onSubmit { sendMessage(inputText) }

                    Button(action: { sendMessage(inputText) }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundColor(inputText.isEmpty ? .gray : .blue)
                    }
                    .disabled(inputText.isEmpty || isTyping)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(white: 0.1))
                // Extra bottom padding so input clears the tab bar
                .padding(.bottom, 80)
            }
        }
    }

    func sendMessage(_ text: String) {
        guard !text.isEmpty else { return }
        inputText = ""
        isInputFocused = false

        let userMessage = ChatMessage(role: .user, text: text, timestamp: Date())
        messages.append(userMessage)
        isTyping = true

        let hr = Int(healthManager.heartRate)
        let steps = Int(healthManager.stepCount)

        let systemContext = """
        You are AxxessGuard, a compassionate AI health assistant. Current user vitals: heart rate \(hr == 0 ? "unknown" : "\(hr) BPM"), steps today: \(steps).
        You help with symptom triage, medication reminders, and general health guidance.
        Keep responses concise (2-4 sentences). For serious symptoms, always recommend seeing a doctor.
        Never diagnose — only guide and support.
        """

        let prompt = "\(systemContext)\n\nUser: \(text)\n\nAssistant:"

        Task {
            do {
                let response = try await FeatherlessService.generate(prompt: prompt)
                await MainActor.run {
                    isTyping = false
                    messages.append(ChatMessage(role: .assistant, text: response, timestamp: Date()))
                }
            } catch {
                await MainActor.run {
                    isTyping = false
                    messages.append(ChatMessage(role: .assistant, text: "I'm having trouble connecting right now. For urgent medical concerns, please contact your healthcare provider or call emergency services.", timestamp: Date()))
                }
            }
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .assistant {
                ZStack {
                    Circle().fill(Color.blue.opacity(0.2)).frame(width: 28, height: 28)
                    Image(systemName: "cross.case.fill").font(.caption2).foregroundColor(.blue)
                }
            } else {
                Spacer()
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 2) {
                Text(message.text)
                    .padding(12)
                    .background(message.role == .user ? Color.blue : Color.white)
                    .foregroundColor(message.role == .user ? .white : .black)
                    .cornerRadius(18)
                    .shadow(color: .black.opacity(0.08), radius: 4)
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.72, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .user {
                ZStack {
                    Circle().fill(Color.blue).frame(width: 28, height: 28)
                    Image(systemName: "person.fill").font(.caption2).foregroundColor(.white)
                }
            } else {
                Spacer()
            }
        }
    }
}

struct TypingIndicator: View {
    @State private var animate = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack {
                Circle().fill(Color.blue.opacity(0.2)).frame(width: 28, height: 28)
                Image(systemName: "cross.case.fill").font(.caption2).foregroundColor(.blue)
            }
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 7, height: 7)
                        .scaleEffect(animate ? 1.3 : 0.8)
                        .animation(.easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.15), value: animate)
                }
            }
            .padding(12)
            .background(Color.white)
            .cornerRadius(18)
            Spacer()
        }
        .onAppear { animate = true }
    }
}

struct QuickPromptChip: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .bold()
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white)
                .foregroundColor(.blue)
                .cornerRadius(20)
                .shadow(color: .blue.opacity(0.1), radius: 4)
        }
    }
}
