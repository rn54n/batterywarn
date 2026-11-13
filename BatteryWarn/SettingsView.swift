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
    @State private var threshold = 10
    @State private var isDraggingThreshold = false
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var loginItemError: String?
    @State private var showHelp = false

    var body: some View {
        VStack(spacing: 16) {
            header

            // Warning
            SettingsGroup {
                SettingsRow(title: "Warn me at", caption: "Drag the marker on the battery, or use the arrows") {
                    HStack(spacing: 8) {
                        Text("\(threshold)%")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.red)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(.red.opacity(0.12))
                            )

                        Stepper("Warning level", value: $threshold, in: WarningPolicy.thresholdRange)
                            .labelsHidden()
                    }
                }

                Divider()
                    .padding(.leading, 16)

                SettingsRow(
                    title: "Allow Dismissing",
                    caption: batteryMonitor.allowsDismiss
                        ? "ESC or the button closes the warning until the next percent"
                        : "The warning stays on screen until you connect power"
                ) {
                    Toggle("Allow Dismissing", isOn: $batteryMonitor.allowsDismiss)
                        .toggleStyle(.switch)
                        .tint(.red)
                        .labelsHidden()
                }

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
        .onChange(of: threshold) { _, newValue in
            // Apply a drag only on release, so the overlay can't pop up mid-drag.
            // Stepper and accessibility changes arrive without a drag.
            if !isDraggingThreshold {
                batteryMonitor.threshold = newValue
            }
        }
        .onAppear {
            threshold = batteryMonitor.threshold
            launchAtLogin = LoginItem.isEnabled
        }
    }

    // MARK: - Header

    /// App identity plus the live battery, with the warning level as a draggable marker on it
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

            BatteryGaugeView(level: batteryMonitor.batteryLevel, threshold: $threshold) { editing in
                isDraggingThreshold = editing
                if !editing {
                    batteryMonitor.threshold = threshold
                }
            }
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
                icon: "lock.fill",
                title: "No Dismissing",
                description: "Turn off Allow Dismissing to keep the warning on screen until power is connected. ESC and the button are disabled then."
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

/// Battery bar: charge in green, the warning zone in red.
/// Drag the handle (or anywhere on the bar) to set where the warning starts.
struct BatteryGaugeView: View {
    let level: Int
    @Binding var threshold: Int
    var onEditingChanged: (Bool) -> Void = { _ in }

    @State private var isDragging = false

    private let barHeight: CGFloat = 44
    private let inset: CGFloat = 5
    private let capWidth: CGFloat = 6
    private let capGap: CGFloat = 4

    /// The warning level a drag at this x position inside the bar stands for
    static func threshold(atX x: CGFloat, innerWidth: CGFloat) -> Int {
        let range = WarningPolicy.thresholdRange
        let percent = Int((x / innerWidth * 100).rounded())
        return min(max(percent, range.lowerBound), range.upperBound)
    }

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

                // Drag handle where the warning starts
                Capsule()
                    .fill(.white)
                    .overlay(
                        Capsule()
                            .stroke(.black.opacity(0.2), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.35), radius: isDragging ? 5 : 2, y: 1)
                    .frame(width: 10, height: barHeight + 12)
                    .scaleEffect(isDragging ? 1.08 : 1)
                    .offset(x: markerX - 5, y: -6)
                    .animation(.easeOut(duration: 0.15), value: isDragging)

                // Handle label: to the right of the handle on the left half, otherwise to its left
                Text("Warning at \(threshold)%")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(
                        width: threshold < 50 ? geometry.size.width - markerX - 10 : markerX - 10,
                        alignment: threshold < 50 ? .leading : .trailing
                    )
                    .offset(x: threshold < 50 ? markerX + 10 : 0, y: barHeight + 4)
            }
            // The whole bar takes the drag, like the track of a slider
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            onEditingChanged(true)
                        }
                        threshold = Self.threshold(atX: value.location.x - inset, innerWidth: innerWidth)
                    }
                    .onEnded { _ in
                        isDragging = false
                        onEditingChanged(false)
                    }
            )
        }
        .frame(height: barHeight + 20)
        .animation(.easeInOut(duration: 0.4), value: level)
        .onHover { inside in
            if inside {
                NSCursor.resizeLeftRight.push()
            } else {
                NSCursor.pop()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Warning level")
        .accessibilityValue("\(threshold) percent, battery at \(level) percent")
        .accessibilityAdjustableAction { direction in
            let range = WarningPolicy.thresholdRange
            switch direction {
            case .increment:
                threshold = min(threshold + 1, range.upperBound)
            case .decrement:
                threshold = max(threshold - 1, range.lowerBound)
            @unknown default:
                break
            }
        }
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
