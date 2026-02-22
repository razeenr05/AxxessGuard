<p align="center">
  <img src="AxxessGuard/Assets.xcassets/AppIcon.appiconset/axxess_logo.png" alt="AxxessGuard Logo" width="160"/>
</p>

# AxxessGuard
### AI-Driven Preventive Health Partner
*Built for the Axxess 2026 Hackathon*

---

## Overview

AxxessGuard is an iOS application that acts as a proactive, AI-powered personal health companion. It collects real-time vitals from Apple HealthKit, analyzes them using a large language model, detects potential falls, and sends smart health alerts; all in one unified experience!

---

## Features

| Feature | Description |
|---|---|
| 📊 **Live Vitals Dashboard** | Real-time heart rate, step count, and SpO2 pulled from HealthKit |
| 🧠 **Predictive Risk Analysis** | AI assesses your vitals and returns a LOW / MODERATE / HIGH risk score |
| 💬 **Virtual Health Assistant** | Conversational AI chatbot for symptom triage, medication questions, and health guidance |
| 🥗 **Lifestyle Coach** | Personalized AI-generated diet and exercise plans based on your vitals and health goals |
| 🚨 **Smart Notifications** | Automatic alerts for high/low heart rate, hypertensive crisis, blood sugar anomalies, and daily summaries |
| 🤸 **Fall Detection** | Accelerometer-based fall detection using a two-phase freefall + impact algorithm |

---

## Project Structure

```
AxxessGuard/
│
├── App
│   ├── AxxessGuardApp.swift          # App entry point (@main)
│   └── AxxessGuard.entitlements      # HealthKit entitlements
│
├── Config
│   └── Info.plist                    # App permissions, ATS config, background modes
│
├── Views
│   ├── ContentView.swift             # Root TabView + custom tab bar
│   ├── RiskModelView.swift           # Predictive risk AI analysis screen
│   ├── VirtualAssistantView.swift    # Chat-based health assistant screen
│   └── LifestyleCoachView.swift      # Diet & exercise plan generator screen
│
├── Managers
│   ├── HealthKitManager.swift        # HealthKit authorization, queries, live HR session
│   ├── NotificationManager.swift     # In-app notification logic + health alert triggers
│   └── FallDetectionManager.swift    # Accelerometer fall detection (freefall + impact phases)
│
├── Services
│   └── FeatherlessService.swift      # AI API client (REST, no external dependencies)
│
└── UI Components
    └── NotificationViews.swift       # Notification bell, panel, banner, and alert dialog views
```

---

## Tech Stack & Frameworks

### Apple Frameworks

| Framework | Usage |
|---|---|
| **SwiftUI** | Entire UI layer — all views, animations, and layout |
| **HealthKit** | Reading heart rate, step count, SpO2; live workout session to keep HR sensor active |
| **CoreMotion** | Accelerometer access for fall detection at 50Hz sampling rate |
| **UserNotifications** | System push notification permission + scheduled daily 8AM summary |
| **Combine** | `ObservableObject` / `@Published` reactive data binding across managers |
| **Foundation** | Networking (`URLSession`), JSON parsing, date formatting |

### AI / Backend

| Service | Usage |
|---|---|
| **Featherless AI** | Serverless LLM inference endpoint — OpenAI-compatible API |
| **Meta LLaMA 3.1 8B Instruct** | The underlying model used for all AI features |

> All AI calls are made via plain `URLSession` REST requests — **zero third party Swift packages required.**

### Architecture Pattern
- **MVVM-adjacent**: `ObservableObject` managers act as ViewModels; Views are purely declarative
- **Async/Await**: All AI and HealthKit network calls use Swift Concurrency (`async/await`, `Task`, `MainActor`)

---

## Setup & Installation

### Prerequisites
- Xcode 15+
- iOS 16+ device or simulator (HealthKit requires a real device for live heart rate)
- A Featherless AI API key → [featherless.ai](https://featherless.ai)

### Steps

1. **Clone the repo**
   ```bash
   git clone https://github.com/your-org/AxxessGuard.git
   cd AxxessGuard
   ```

2. **Open in Xcode**
   ```bash
   open AxxessGuard.xcodeproj
   ```

3. **No package dependencies to install** — the project uses no Swift Package Manager dependencies. Everything runs on native Apple frameworks + direct REST calls.

4. **Add your API key**
   Open `FeatherlessService.swift` and replace the API key:
   ```swift
   static let apiKey = "YOUR_FEATHERLESS_API_KEY"
   ```
   
5. **Set your development team**
   In Xcode → Target → Signing & Capabilities → set your Apple Developer Team (required for HealthKit on device)

6. **Build & run on a real iPhone** for full HealthKit + fall detection functionality

---

## App Permissions Required

| Permission | Reason |
|---|---|
| **HealthKit — Heart Rate** | Live and historical heart rate monitoring |
| **HealthKit — Step Count** | Daily activity tracking |
| **HealthKit — Oxygen Saturation** | SpO2 monitoring |
| **HealthKit — Workout** | Keeps the heart rate sensor active via a background workout session |
| **Motion & Fitness** | Accelerometer access for fall detection |
| **Notifications** | Health alerts and daily summaries |

---

## AI Features In Depth

### Predictive Risk Model
Sends the user's vitals (HR, BP, glucose, steps, SpO2) to the LLM and asks it to return a 2–3 sentence risk summary ending with a structured `RISK:LOW`, `RISK:MODERATE`, or `RISK:HIGH` label, which the app parses to set the visual risk badge color.

### Virtual Health Assistant
A multi-turn style chat interface. Each message prepends a system context block containing the user's current vitals before sending to the model. Responds in 2–4 sentences, always directing serious symptoms to a doctor. Never diagnoses.

### Lifestyle Coach
Two separate AI calls. One for a diet plan, one for an exercise plan. Both are conditioned on the user's selected health goal (General Wellness, Weight Loss, Heart Health, etc.) and health condition (Diabetes, Hypertension, Post-Operative, etc.).

---

## Fall Detection Algorithm

The `FallDetectionManager` uses a classic **two phase detection approach** on raw accelerometer data sampled at 50Hz:

1. **Freefall Phase** — Total acceleration magnitude drops below `0.35g` (normal standing is ~1.0g)
2. **Impact Phase** — Within 600ms, magnitude spikes above `2.8g`

Both phases must occur in sequence within the time window to trigger an alert. A 30 second cooldown prevents duplicate alerts from a single event.

---

## Smart Notifications

Alerts are triggered automatically when vitals cross clinical thresholds:

| Condition | Threshold | Alert Type |
|---|---|---|
| High Heart Rate | > 120 BPM | 🔴 Critical |
| Elevated Heart Rate | 100–120 BPM | 🟠 Warning |
| Low Heart Rate | < 50 BPM | 🟠 Warning |
| Hypertensive Crisis | Systolic > 180 or Diastolic > 120 | 🔴 Critical |
| Stage 2 Hypertension | Systolic ≥ 140 or Diastolic ≥ 90 | 🟠 Warning |
| Critical High Glucose | > 250 mg/dL | 🔴 Critical |
| High Glucose | > 125 mg/dL | 🟠 Warning |
| Low Glucose | < 70 mg/dL | 🔴 Critical |
| Fall Detected | Algorithm trigger | 🔴 Critical |
| Daily Summary | Step count based | 🔵 Info / 🟢 Success |

---

## Hackathon Track Alignment

| Requirement | Implementation |
|---|---|
| Wearable Integration | Apple Watch via HealthKit — live HKWorkoutSession keeps the Watch heart rate sensor continuously active; HKAnchoredObjectQuery streams real-time HR, step count, and SpO2 directly from the Watch to the app |
| Predictive Risk Modeling | LLaMA 3.1 risk assessment with structured output parsing (RISK:LOW / MODERATE / HIGH) |
| Virtual Assistant | Full chat UI with health context injection per message |
| Smart Alerts | `NotificationManager` with clinical thresholds + banner UI |
| Diet & Lifestyle Coaching | Goal/condition aware AI plan generation |
| Fall Detection (bonus) | Two phase CoreMotion accelerometer algorithm |

---

## Use Cases

These are directly supported through the condition selectors in the Lifestyle Coach and the AI's context-aware responses across all features:

| Use Case | How AxxessGuard Addresses It |
|---|---|
| **Chronic Disease Management** | Users can select Diabetes or Hypertension as their health condition. The AI tailors diet plans, exercise recommendations, and risk assessments specifically around managing those conditions. Blood glucose and blood pressure are tracked as first-class vitals. |
| **Elderly Care** | "Elderly Care" is a selectable condition in the Lifestyle Coach, prompting the AI to recommend low impact, safe exercises and easy-to-prepare meals. Fall detection runs continuously in the background and fires a critical alert the moment a fall is detected, with an option to alert emergency contacts. |
| **Post-Operative Recovery** | "Post-Operative" is a selectable condition, causing the AI to generate conservative recovery appropriate plans, avoiding strenuous activity and recommending nutrition that supports healing. The risk model also factors this in when assessing vitals. |

---

## Devpost & Video Demo
https://devpost.com/software/axxessguard
https://www.youtube.com/shorts/ttEiJdkgv7Y
