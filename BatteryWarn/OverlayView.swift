import SwiftUI

struct OverlayView: View {
    var batteryMonitor: BatteryMonitor
    var isCritical: Bool
    var onDismiss: (() -> Void)?

    @State private var pulseAnimation = false
    @State private var escHoldProgress: CGFloat = 0
    @State private var isHoldingEsc = false

    private let escHoldDuration: Double = 3.0

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

                // Critical badge
                if isCritical {
                    Text("CRITICAL")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(.red)
                        )
                }

                // Battery icon
                BatteryIconView(level: batteryMonitor.batteryLevel)
                    .frame(width: 180, height: 100)

                // Main message
                VStack(spacing: 16) {
                    Text(isCritical ? "Critical Battery" : "Low Battery")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("\(batteryMonitor.batteryLevel)% remaining")
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                }

                // Instructions
                VStack(spacing: 20) {
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

                    // Dismiss button (only when not critical)
                    if !isCritical {
                        Button(action: { onDismiss?() }) {
                            HStack(spacing: 8) {
                                Image(systemName: "clock.arrow.circlepath")
                                Text("Remind me at \(batteryMonitor.batteryLevel - 1)%")
                            }
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(.white.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // ESC hint
                    Text(isCritical ? "Hold ESC for 3 seconds to dismiss" : "Press ESC or click button to dismiss")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                }

                Spacer()

                // ESC progress indicator (when holding)
                if isHoldingEsc {
                    VStack(spacing: 8) {
                        ProgressView(value: escHoldProgress)
                            .progressViewStyle(.linear)
                            .tint(.white)
                            .frame(width: 200)

                        Text("Hold ESC... \(Int(escHoldProgress * 100))%")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.bottom, 20)
                }

                Text("Warning threshold: \(batteryMonitor.threshold)%")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.bottom, 32)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
            setupKeyMonitor()
        }
        .onDisappear {
            removeKeyMonitor()
        }
    }

    // MARK: - ESC Key Handling

    @State private var keyMonitor: Any?
    @State private var escTimer: Timer?

    private func setupKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { event in
            if event.keyCode == 53 { // ESC key
                if event.type == .keyDown && !event.isARepeat {
                    startEscHold()
                } else if event.type == .keyUp {
                    cancelEscHold()
                }
                return nil // Consume the event
            }
            return event
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        escTimer?.invalidate()
    }

    private func startEscHold() {
        // For non-critical, instant dismiss
        if !isCritical {
            onDismiss?()
            return
        }

        // For critical, require 3 second hold
        isHoldingEsc = true
        escHoldProgress = 0

        let steps = 30
        let interval = escHoldDuration / Double(steps)

        escTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            escHoldProgress += 1.0 / CGFloat(steps)

            if escHoldProgress >= 1.0 {
                timer.invalidate()
                onDismiss?()
            }
        }
    }

    private func cancelEscHold() {
        isHoldingEsc = false
        escHoldProgress = 0
        escTimer?.invalidate()
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
    }
}
