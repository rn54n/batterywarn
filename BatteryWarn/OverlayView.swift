import SwiftUI

struct OverlayView: View {
    @ObservedObject var model: OverlayModel
    /// Off where there is no screen behind the view to blur (previews, rendered screenshots)
    var blursScreen = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulseAnimation = false
    @State private var isHoveringDismiss = false

    private var isCritical: Bool { model.isCritical }

    // Warning light: a vivid red, a softer tint of it for small text
    private let glow = Color(red: 1.0, green: 0.23, blue: 0.19)
    private let glowText = Color(red: 1.0, green: 0.48, blue: 0.43)

    var body: some View {
        ZStack {
            backdrop

            // Content
            VStack(spacing: 0) {
                Spacer()

                if model.isTest {
                    BadgeView(text: "TEST PREVIEW", fill: .white.opacity(0.16))
                        .padding(.bottom, 22)
                }

                statusLabel

                // Battery level, the one thing to read from across the room
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(model.batteryLevel)")
                        .font(.system(size: 176, weight: .bold, design: .rounded))
                        .tracking(-5)
                        .contentTransition(.numericText())

                    Text("%")
                        .font(.system(size: 76, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.55))
                }
                .foregroundColor(.white)
                .animation(.easeInOut(duration: 0.4), value: model.batteryLevel)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Battery at \(model.batteryLevel) percent")

                levelBar
                    .padding(.top, 2)

                if let timeRemaining = BatteryFormat.timeRemaining(minutes: model.minutesRemaining) {
                    Text(timeRemaining)
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                        .padding(.top, 22)
                }

                // Instructions
                HStack(spacing: 12) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.yellow)

                    Text("Connect to power to continue")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                        )
                )
                .padding(.top, 48)

                Group {
                    if !model.allowsDismiss {
                        lockedNote
                    } else if isCritical {
                        holdToDismiss
                    } else {
                        dismissButton
                    }
                }
                .padding(.top, 26)

                Spacer()

                Text(model.isTest ? "This preview closes on its own after 5 seconds" : "Warning threshold \(model.threshold)%")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.bottom, 32)
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.3), value: isCritical)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: isCritical ? 1.2 : 2.0).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
    }

    // MARK: - Backdrop

    /// The screen behind, blurred and dimmed, with red light coming in from the edges
    private var backdrop: some View {
        ZStack {
            if blursScreen {
                BackdropBlur()
            }

            Color.black
                .opacity(isCritical ? 0.66 : 0.56)

            // Edge light: a luminous rim that leaves the middle neutral.
            // Stronger and faster when critical.
            ZStack {
                EllipticalGradient(
                    stops: [
                        .init(color: .clear, location: 0.5),
                        .init(color: glow.opacity(isCritical ? 0.5 : 0.32), location: 0.82),
                        .init(color: glow.opacity(isCritical ? 1.0 : 0.85), location: 1.0)
                    ],
                    center: .center,
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.68
                )

                LinearGradient(
                    colors: [glow.opacity(isCritical ? 0.5 : 0.32), .clear],
                    startPoint: .bottom,
                    endPoint: UnitPoint(x: 0.5, y: 0.62)
                )
            }
            .opacity(pulseAnimation ? 1.0 : 0.6)
        }
    }

    // MARK: - Status

    /// What kind of warning this is, above the number
    @ViewBuilder
    private var statusLabel: some View {
        if isCritical {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .bold))
                Text("CRITICAL BATTERY")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .tracking(2.5)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(glow)
            )
        } else {
            Text("LOW BATTERY")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .tracking(4)
                .foregroundColor(glowText)
        }
    }

    /// Slim bar under the number: how little is left
    private var levelBar: some View {
        let width: CGFloat = 300

        return ZStack(alignment: .leading) {
            Capsule()
                .fill(.white.opacity(0.16))

            Capsule()
                .fill(glow)
                .frame(width: max(8, width * CGFloat(min(max(model.batteryLevel, 0), 100)) / 100))
                .shadow(color: glow.opacity(0.9), radius: 8)
        }
        .frame(width: width, height: 8)
        .animation(.easeInOut(duration: 0.4), value: model.batteryLevel)
        .accessibilityHidden(true)
    }

    // MARK: - Dismiss Controls

    /// Dismiss button with its ESC shortcut (only when not critical)
    private var dismissButton: some View {
        Button(action: { model.onDismiss?() }) {
            HStack(spacing: 12) {
                Text(model.isTest ? "Close preview" : "Remind me at \(model.batteryLevel - 1)%")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))

                KeyCapView()
            }
            .padding(.leading, 22)
            .padding(.trailing, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white.opacity(isHoveringDismiss ? 0.14 : 0.0))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHoveringDismiss = hovering
            }
        }
    }

    /// Shown instead of the dismiss controls when dismissing is turned off in Settings
    private var lockedNote: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
            Text("This warning stays until you connect power")
        }
        .font(.system(size: 16, weight: .medium, design: .rounded))
        .foregroundColor(.white.opacity(0.8))
    }

    /// ESC key inside a ring that fills while the key is held (critical only)
    private var holdToDismiss: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.25), lineWidth: 4)

                Circle()
                    .trim(from: 0, to: model.escHoldProgress)
                    .stroke(.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: model.escHoldProgress)

                Text("esc")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }
            .frame(width: 56, height: 56)

            Text(model.isHoldingEsc ? "Keep holding…" : "Hold ESC for 3 seconds to dismiss")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hold Escape for 3 seconds to dismiss")
    }
}

/// Blurs whatever is on screen behind the overlay window
struct BackdropBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .fullScreenUI
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct BadgeView: View {
    let text: String
    let fill: Color

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .heavy, design: .rounded))
            .tracking(2)
            .foregroundColor(.white.opacity(0.9))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(fill)
            )
    }
}

struct KeyCapView: View {
    var body: some View {
        Text("esc")
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundColor(.white.opacity(0.9))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(.white.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.white.opacity(0.35), lineWidth: 1)
                    )
            )
    }
}
