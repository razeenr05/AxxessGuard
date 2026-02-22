import SwiftUI

// MARK: - Notification Bell Button

struct NotificationBellButton: View {
    @ObservedObject var notificationManager: NotificationManager
    @Binding var showPanel: Bool

    var body: some View {
        Button(action: {
            notificationManager.markAllRead()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                showPanel.toggle()
            }
        }) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())

                if notificationManager.unreadCount > 0 {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 18, height: 18)
                        Text(notificationManager.unreadCount > 9 ? "9+" : "\(notificationManager.unreadCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .offset(x: 4, y: -4)
                }
            }
        }
    }
}

// MARK: - Notification Panel (slide down from top)

struct NotificationPanel: View {
    @ObservedObject var notificationManager: NotificationManager
    @Binding var isShowing: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Dimmed background tap to dismiss
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isShowing = false
                    }
                }

            // Panel
            VStack(spacing: 0) {
                // Panel header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Notifications")
                            .font(.title3)
                            .bold()
                            .foregroundColor(.white)
                        Text(notificationManager.notifications.isEmpty
                             ? "All caught up!"
                             : "\(notificationManager.notifications.count) alert\(notificationManager.notifications.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                    if !notificationManager.notifications.isEmpty {
                        Button(action: {
                            withAnimation { notificationManager.clearAll() }
                        }) {
                            Text("Clear All")
                                .font(.caption)
                                .bold()
                                .foregroundColor(.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.15))
                                .cornerRadius(12)
                        }
                    }
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isShowing = false
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 14)

                Divider().background(Color.white.opacity(0.1))

                if notificationManager.notifications.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "bell.slash.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.white.opacity(0.2))
                        Text("No notifications yet")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.4))
                        Text("Health alerts and daily summaries\nwill appear here.")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.3))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 50)
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 10) {
                            ForEach(notificationManager.notifications) { notification in
                                NotificationRow(notification: notification)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .top).combined(with: .opacity),
                                        removal: .opacity
                                    ))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .frame(maxHeight: 420)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(white: 0.10))
                    .shadow(color: .black.opacity(0.5), radius: 30)
            )
            .padding(.horizontal, 16)
            .padding(.top, 60) // clears status bar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Notification Row Card

struct NotificationRow: View {
    let notification: AppNotification

    var timeAgo: String {
        let seconds = Int(Date().timeIntervalSince(notification.timestamp))
        if seconds < 60 { return "Just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        return "\(seconds / 86400)d ago"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(notification.type.color.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: notification.type.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(notification.type.color)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(notification.title)
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Spacer()
                    Text(timeAgo)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                }
                Text(notification.message)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.65))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: notification.type.backgroundGradient.map { $0.opacity(0.6) },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(notification.type.color.opacity(0.25), lineWidth: 1)
        )
        .cornerRadius(16)
    }
}

// MARK: - Banner Toast (slides down from top of screen)

struct NotificationBanner: View {
    let notification: AppNotification
    @Binding var isShowing: Bool

    var body: some View {
        VStack {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(notification.type.color.opacity(0.25))
                        .frame(width: 40, height: 40)
                    Image(systemName: notification.type.icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(notification.type.color)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(notification.title)
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(notification.message)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(2)
                }
                Spacer()
                Button(action: {
                    withAnimation(.easeOut(duration: 0.25)) { isShowing = false }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            .padding(14)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(white: 0.11))
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(notification.type.color.opacity(0.4), lineWidth: 1.5)
                }
            )
            .shadow(color: notification.type.color.opacity(0.3), radius: 16)
            .padding(.horizontal, 16)
            .padding(.top, 55) // below status bar
            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Critical Alert Dialog (for high heart rate etc.)

struct CriticalAlertView: View {
    let notification: AppNotification
    var onDismiss: () -> Void
    var onAlertContacts: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()

            VStack(spacing: 0) {
                // Top accent bar
                Rectangle()
                    .fill(notification.type.color)
                    .frame(height: 4)
                    .cornerRadius(4)

                VStack(spacing: 18) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(notification.type.color.opacity(0.15))
                            .frame(width: 72, height: 72)
                        Image(systemName: notification.type.icon)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(notification.type.color)
                    }
                    .padding(.top, 24)

                    VStack(spacing: 8) {
                        Text(notification.title)
                            .font(.title3)
                            .bold()
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        Text(notification.message)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 20)

                    // Action buttons
                    VStack(spacing: 10) {
                        if notification.type == .critical {
                            Button(action: onAlertContacts) {
                                HStack {
                                    Image(systemName: "phone.fill")
                                    Text("Alert Emergency Contacts")
                                        .bold()
                                }
                                .frame(maxWidth: .infinity)
                                .padding(14)
                                .background(notification.type.color)
                                .foregroundColor(.white)
                                .cornerRadius(14)
                            }
                        }
                        Button(action: onDismiss) {
                            Text("I'm Okay")
                                .font(.subheadline)
                                .bold()
                                .frame(maxWidth: .infinity)
                                .padding(14)
                                .background(Color.white.opacity(0.1))
                                .foregroundColor(.white)
                                .cornerRadius(14)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .background(Color(white: 0.1))
            .cornerRadius(28)
            .padding(.horizontal, 28)
        }
    }
}
