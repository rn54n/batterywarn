import SwiftUI

extension Notification.Name {
    static let showTestOverlay = Notification.Name("showTestOverlay")
}

struct SettingsView: View {
    @EnvironmentObject var batteryMonitor: BatteryMonitor
    var loginItemAvailable = LoginItem.isAvailable
    var appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    var appIcon: NSImage = NSApplication.shared.applicationIconImage

    @AppStorage(AppAppearance.defaultsKey) private var appearance = AppAppearance.system
    @State private var threshold: Double = 10
    @State private var isDraggingThreshold = false
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var loginItemError: String?
    @State private var showHelp = false

    private var roundedThreshold: Int { Int(threshold.rounded()) }

    var body: some View {
        VStack(spacing: 16) {
            header

            // Warning
            SettingsGroup {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Warn me at")
                            .font(.system(size: 13, weight: .medium))

                        Spacer()

                        Text("\(roundedThreshold)%")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.red)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(.red.opacity(0.12))
                            )
                    }

                    // Apply a drag only on release, so the overlay can't pop up mid-drag.
                    // No step: it would draw a tick mark per percent; values are rounded instead.
                    Slider(value: $threshold, in: 5...99) { editing in
                        isDraggingThreshold = editing
                        if !editing {
                            batteryMonitor.threshold = roundedThreshold
                        }
                    }
                    .tint(.red)
                    .onChange(of: threshold) { _, newValue in
                        // Keyboard and accessibility changes arrive without a drag
                        if !isDraggingThreshold {
                            batteryMonitor.threshold = Int(newValue.rounded())
                        }
                    }

                    Text("A full-screen warning appears when the battery drops to this level")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                Divider()
                    .padding(.leading, 16)

                SettingsRow(title: "Preview", caption: "See the warning for 5 seconds") {
                    Button("Show Preview", action: testOverlay)
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                }
            }

            // General
            SettingsGroup {
                SettingsRow(title: "Launch at Login", caption: loginItemHint, captionColor: loginItemError == nil ? .secondary : .red) {
                    Toggle("Launch at Login", isOn: Binding(get: { launchAtLogin }, set: setLaunchAtLogin))
                        .toggleStyle(.switch)
                        .tint(.red)
                        .labelsHidden()
                        .disabled(!loginItemAvailable)
                }

                Divider()
                    .padding(.leading, 16)

                SettingsRow(title: "Appearance") {
                    Picker("Appearance", selection: $appearance) {
                        ForEach(AppAppearance.allCases) { appearance in
                            Text(appearance.title).tag(appearance)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 210)
                    .onChange(of: appearance) { _, newValue in
                        newValue.apply()
                    }
                }
            }

            footer
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .frame(width: 540)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            threshold = Double(batteryMonitor.threshold)
            launchAtLogin = LoginItem.isEnabled
        }
    }

    // MARK: - Header

    /// App identity plus the live battery, with the warning level marked on it
    private var header: some View {
        VStack(spacing: 18) {
            HStack(spacing: 14) {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 3) {
                    Text("BatteryWarn")
                        .font(.system(size: 22, weight: .bold, design: .rounded))

                    Text(BatteryFormat.powerDetail(
                        isPluggedIn: batteryMonitor.isPluggedIn,
                        isCharging: batteryMonitor.isCharging,
                        minutesRemaining: batteryMonitor.minutesRemaining
                    ))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                }

                Spacer()

                HStack(spacing: 6) {
                    if batteryMonitor.isPluggedIn {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.green)
                    }

                    Text("\(batteryMonitor.batteryLevel)%")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
            }

            BatteryGaugeView(level: batteryMonitor.batteryLevel, threshold: roundedThreshold)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            HelpLink { showHelp = true }
                .popover(isPresented: $showHelp, arrowEdge: .top) {
                    helpContent
                }

            Text("How it works")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Spacer()

            Text("v\(appVersion)")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

            FooterLink(title: "Star on GitHub", icon: "star.fill", url: "https://github.com/rn54n/batterywarn")
            FooterLink(title: "codekraft.dev", icon: nil, url: "https://codekraft.dev")
        }
        .padding(.horizontal, 4)
    }

    private var helpContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HelpItem(
                icon: "battery.25",
                title: "Warning Mode",
                description: "When battery drops to your threshold, a red overlay appears. You can dismiss it and continue working - it will remind you again when battery drops another percent."
            )

            HelpItem(
                icon: "exclamationmark.triangle.fill",
                title: "Critical Mode (≤5%)",
                description: "At 5% battery and below, the overlay becomes critical. You must hold ESC for 3 seconds to dismiss, encouraging you to plug in immediately."
            )

            HelpItem(
                icon: "escape",
                title: "Keyboard Shortcuts",
                description: "Press ESC once to dismiss warning. In critical mode, hold ESC for 3 seconds (progress ring shown)."
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
        .padding(20)
        .frame(width: 360)
    }

    // MARK: - Actions

    private var loginItemHint: String {
        if let error = loginItemError {
            return error
        } else if !loginItemAvailable {
            return "Available when BatteryWarn runs from your Applications folder"
        } else {
            return "Keeps the warning in place after a restart"
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LoginItem.setEnabled(enabled)
            loginItemError = nil
        } catch {
            loginItemError = "macOS did not accept the change. Check System Settings > General > Login Items."
        }
        launchAtLogin = LoginItem.isEnabled
    }

    private func testOverlay() {
        NotificationCenter.default.post(name: .showTestOverlay, object: nil)
    }
}

/// Rounded box that holds related rows
struct SettingsGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

/// Title and caption on the left, one control on the right
struct SettingsRow<Control: View>: View {
    let title: String
    var caption: String? = nil
    var captionColor: Color = .secondary
    @ViewBuilder var control: Control

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))

                if let caption = caption {
                    Text(caption)
                        .font(.system(size: 11))
                        .foregroundColor(captionColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 12)

            control
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

/// Battery bar: charge in green, the warning zone in red, a marker where the warning starts
struct BatteryGaugeView: View {
    let level: Int
    let threshold: Int

    private let barHeight: CGFloat = 44
    private let inset: CGFloat = 5
    private let capWidth: CGFloat = 6
    private let capGap: CGFloat = 4

    var body: some View {
        GeometryReader { geometry in
            let bodyWidth = geometry.size.width - capWidth - capGap
            let innerWidth = bodyWidth - inset * 2
            let levelWidth = innerWidth * CGFloat(min(max(level, 0), 100)) / 100
            let thresholdWidth = innerWidth * CGFloat(threshold) / 100
            let markerX = inset + thresholdWidth

            ZStack(alignment: .topLeading) {
                // Battery outline
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(Color.primary.opacity(0.3), lineWidth: 2)
                    .frame(width: bodyWidth, height: barHeight)

                // Battery cap
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.primary.opacity(0.3))
                    .frame(width: capWidth, height: 16)
                    .offset(x: bodyWidth + capGap, y: (barHeight - 16) / 2)

                ZStack(alignment: .leading) {
                    // Warning zone, also where the charge has not reached it yet
                    Rectangle()
                        .fill(.red.opacity(0.35))
                        .frame(width: thresholdWidth)

                    // Charge: red inside the warning zone, green above it
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(.red)
                            .frame(width: min(levelWidth, thresholdWidth))

                        Rectangle()
                            .fill(.green)
                            .frame(width: max(0, levelWidth - thresholdWidth))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .frame(width: innerWidth, height: barHeight - inset * 2, alignment: .leading)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .offset(x: inset, y: inset)

                // Marker where the warning starts
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.primary)
                    .frame(width: 2, height: barHeight + 12)
                    .offset(x: markerX - 1, y: -2)

                // Marker label: to the right of the marker on the left half, otherwise to its left
                Text("Warning at \(threshold)%")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(
                        width: threshold < 50 ? geometry.size.width - markerX - 7 : markerX - 7,
                        alignment: threshold < 50 ? .leading : .trailing
                    )
                    .offset(x: threshold < 50 ? markerX + 7 : 0, y: barHeight + 2)
            }
        }
        .frame(height: barHeight + 18)
        .animation(.easeInOut(duration: 0.4), value: level)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Battery at \(level) percent, warning at \(threshold) percent")
    }
}

struct FooterLink: View {
    let title: String
    let icon: String?
    let url: String

    var body: some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                }
                Text(title)
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
