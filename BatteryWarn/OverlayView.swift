import SwiftUI

struct OverlayView: View {
    @ObservedObject var model: OverlayModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulseAnimation = false

    private var isCritical: Bool { model.isCritical }

    var body: some View {
        ZStack {
            // Background gradient - more intense red when critical
            LinearGradient(
                colors: isCritical ? [
                    Color(red: 0.7, green: 0.0, blue: 0.0),
                    Color(red: 0.5, green: 0.0, blue: 0.0)
                ] : [
                    Color(red: 0.6, green: 0.05, blue: 0.05),
                    Color(red: 0.4, green: 0.02, blue: 0.02)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .opacity(pulseAnimation ? 0.97 : 0.92)

            // Content
            VStack(spacing: 40) {
                Spacer()

                // Critical / test badge
                if model.isTest {
                    BadgeView(text: "TEST PREVIEW", fill: .white.opacity(0.2))
                } else if isCritical {
                    BadgeView(text: "CRITICAL", fill: .red)
                }

                // Battery icon
                BatteryIconView(level: model.batteryLevel)
                    .frame(width: 180, height: 100)

                // Main message
                VStack(spacing: 16) {
                    Text(isCritical ? "Critical Battery" : "Low Battery")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("\(model.batteryLevel)% remaining")
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))

                    if let timeRemaining = BatteryFormat.timeRemaining(minutes: model.minutesRemaining) {
                        Text(timeRemaining)
                            .font(.system(size: 20, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                // Instructions
                VStack(spacing: 24) {
                    HStack(spacing: 16) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.yellow)

                        Text("Connect to power to continue")
                            .font(.system(size: 22, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.horizontal, 36)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.white.opacity(0.1))
                    )

                    if isCritical {
                        holdToDismiss
                    } else {
                        dismissButton
                    }
                }

                Spacer()

                Text(model.isTest ? "This preview closes on its own after 5 seconds" : "Warning threshold: \(model.threshold)%")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.bottom, 32)
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.3), value: isCritical)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
    }

    // MARK: - Dismiss Controls

    /// Dismiss button plus ESC hint (only when not critical)
    private var dismissButton: some View {
        VStack(spacing: 14) {
            Button(action: { model.onDismiss?() }) {
                HStack(spacing: 8) {
                    Image(systemName: model.isTest ? "xmark" : "clock.arrow.circlepath")
                    Text(model.isTest ? "Close preview" : "Remind me at \(model.batteryLevel - 1)%")
                }
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.4), lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                Text("or press")
                KeyCapView()
            }
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundColor(.white.opacity(0.75))
        }
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

struct BadgeView: View {
    let text: String
    let fill: Color

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .black, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(fill)
            )
    }
}

struct KeyCapView: View {
    var body: some View {
        Text("esc")
            .font(.system(size: 13, weight: .semibold, design: .rounded))
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

struct BatteryIconView: View {
    let level: Int

    var body: some View {
        ZStack {
            // Battery outline
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.6), lineWidth: 4)
                .frame(width: 140, height: 70)

            // Battery cap
            RoundedRectangle(cornerRadius: 4)
                .fill(.white.opacity(0.6))
                .frame(width: 12, height: 30)
                .offset(x: 76)

            // Battery fill
            HStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [.red.opacity(0.9), .red.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: max(10, CGFloat(level) / 100 * 120), height: 54)
                Spacer()
            }
            .frame(width: 126)
            .offset(x: -3)

            // Percentage text
            Text("\(level)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Battery at \(level) percent")
    }
}
