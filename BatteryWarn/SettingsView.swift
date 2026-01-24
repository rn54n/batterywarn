import SwiftUI

extension Notification.Name {
    static let showTestOverlay = Notification.Name("showTestOverlay")
}

struct SettingsView: View {
    @EnvironmentObject var batteryMonitor: BatteryMonitor
    @State private var threshold: Double = 10
    @State private var isHovering = false
    @State private var showHelp = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "battery.25")
                        .font(.system(size: 48))
                        .foregroundStyle(.red.gradient)

                    Text("BatteryWarn")
                        .font(.system(size: 24, weight: .bold, design: .rounded))

                    Text("Low battery warning overlay")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 24)
                .padding(.bottom, 20)

                Divider()
                    .padding(.horizontal, 24)

                // Settings content
                VStack(spacing: 20) {
                    // Threshold setting
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Warning Threshold")
                                .font(.system(size: 14, weight: .semibold))

                            Spacer()

                            Text("\(Int(threshold))%")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.red)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(.red.opacity(0.1))
                                )
                        }

                        Slider(value: $threshold, in: 5...99, step: 1)
                            .tint(.red)
                            .onChange(of: threshold) { _, newValue in
                                batteryMonitor.threshold = Int(newValue)
                            }

                        Text("Show warning overlay when battery drops below this level")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                            )
                    )

                    // Current status
                    VStack(spacing: 12) {
                        HStack {
                            Text("Current Status")
                                .font(.system(size: 14, weight: .semibold))
                            Spacer()
                        }

                        HStack(spacing: 20) {
                            StatusItem(
                                icon: batteryIconName,
                                value: "\(batteryMonitor.batteryLevel)%",
                                label: "Battery"
                            )

                            StatusItem(
                                icon: batteryMonitor.isPluggedIn ? "bolt.fill" : "bolt.slash.fill",
                                value: batteryMonitor.isPluggedIn ? "Connected" : "Unplugged",
                                label: "Power"
                            )

                            StatusItem(
                                icon: batteryMonitor.isCharging ? "arrow.up.circle.fill" : "minus.circle.fill",
                                value: batteryMonitor.isCharging ? "Charging" : "Idle",
                                label: "Status"
                            )
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                            )
                    )

                    // Help section
                    VStack(alignment: .leading, spacing: 12) {
                        Button(action: { withAnimation { showHelp.toggle() } }) {
                            HStack {
                                Image(systemName: "questionmark.circle.fill")
                                    .foregroundColor(.blue)
                                Text("How it works")
                                    .font(.system(size: 14, weight: .semibold))
                                Spacer()
                                Image(systemName: showHelp ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)

                        if showHelp {
                            VStack(alignment: .leading, spacing: 16) {
                                Divider()

                                HelpItem(
                                    icon: "battery.25",
                                    title: "Warning Mode",
                                    description: "When battery drops below your threshold, a red overlay appears. You can dismiss it and continue working - it will remind you again when battery drops another percent."
                                )

                                HelpItem(
                                    icon: "exclamationmark.triangle.fill",
                                    title: "Critical Mode (≤5%)",
                                    description: "Below 5% battery, the overlay becomes critical. You must hold ESC for 3 seconds to dismiss, encouraging you to plug in immediately."
                                )

                                HelpItem(
                                    icon: "escape",
                                    title: "Keyboard Shortcuts",
                                    description: "Press ESC once to dismiss warning. In critical mode, hold ESC for 3 seconds (progress bar shown)."
                                )

                                HelpItem(
                                    icon: "moon.fill",
                                    title: "Sleep Mode",
                                    description: "The overlay won't prevent your Mac from sleeping. System power management works normally."
                                )

                                HelpItem(
                                    icon: "bolt.fill",
                                    title: "Auto-Dismiss",
                                    description: "When you connect power, the overlay disappears automatically."
                                )
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                            )
                    )

                    // Test button
                    Button(action: testOverlay) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Test Warning Overlay")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.red.gradient)
                                .shadow(color: .red.opacity(isHovering ? 0.4 : 0.2), radius: isHovering ? 8 : 4)
                        )
                        .scaleEffect(isHovering ? 1.02 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isHovering = hovering
                        }
                    }
                }
                .padding(20)

                // Footer
                VStack(spacing: 8) {
                    Text("BatteryWarn v1.0")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    HStack(spacing: 16) {
                        Link(destination: URL(string: "https://github.com/rn54n/batterywarn")!) {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                Text("Star on GitHub")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.secondary)
                        }
                        .onHover { inside in
                            if inside {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }

                        Text("·")
                            .foregroundColor(.secondary.opacity(0.5))

                        Link(destination: URL(string: "https://codekraft.dev")!) {
                            Text("codekraft.dev")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .onHover { inside in
                            if inside {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                    }
                }
                .padding(.bottom, 16)
            }
        }
        .frame(width: 400, height: 620)
        .onAppear {
            threshold = Double(batteryMonitor.threshold)
        }
    }

    private var batteryIconName: String {
        let level = batteryMonitor.batteryLevel
        if batteryMonitor.isCharging {
            return "battery.100.bolt"
        } else if level > 75 {
            return "battery.100"
        } else if level > 50 {
            return "battery.75"
        } else if level > 25 {
            return "battery.50"
        } else if level > 10 {
            return "battery.25"
        } else {
            return "battery.0"
        }
    }

    private func testOverlay() {
        NotificationCenter.default.post(name: .showTestOverlay, object: nil)
    }
}

struct StatusItem: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.red.gradient)

            Text(value)
                .font(.system(size: 12, weight: .semibold))

            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct HelpItem: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.red)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))

                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(BatteryMonitor())
}
