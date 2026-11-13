import Foundation
import IOKit.ps
import Combine

class BatteryMonitor: ObservableObject {
    @Published var batteryLevel: Int = 100
    @Published var isCharging: Bool = false
    @Published var isPluggedIn: Bool = false
    @Published var minutesRemaining: Int? = nil
    @Published var threshold: Int {
        didSet {
            defaults.set(threshold, forKey: "batteryThreshold")
            policy.threshold = threshold
            checkBatteryState()
        }
    }

    /// The warning that currently belongs on screen
    private(set) var warningLevel: WarningLevel = .none

    var onWarningChange: ((_ level: WarningLevel) -> Void)?
    var onBatteryUpdate: (() -> Void)?

    private let defaults: UserDefaults
    private let readPowerSource: () -> BatteryReading?
    private var policy: WarningPolicy
    private var timer: Timer?
    private var runLoopSource: CFRunLoopSource?

    init(
        defaults: UserDefaults = .standard,
        readPowerSource: @escaping () -> BatteryReading? = BatteryMonitor.readSystemPowerSource
    ) {
        self.defaults = defaults
        self.readPowerSource = readPowerSource

        let threshold = defaults.object(forKey: "batteryThreshold") as? Int ?? 10
        self.threshold = threshold
        self.policy = WarningPolicy(threshold: threshold)
        updateBatteryInfo()
    }

    func startMonitoring() {
        refresh()

        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }

        setupPowerSourceNotification()
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .defaultMode)
        }
    }

    /// Read the power source again and re-evaluate the warning
    func refresh() {
        updateBatteryInfo()
        checkBatteryState()
        onBatteryUpdate?()
    }

    /// Call this when user dismisses the overlay
    func dismissOverlay() {
        policy.dismiss(at: batteryLevel)
        checkBatteryState()
    }

    private func setupPowerSourceNotification() {
        let context = Unmanaged.passUnretained(self).toOpaque()

        let callback: IOPowerSourceCallbackType = { context in
            guard let context = context else { return }
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async {
                monitor.refresh()
            }
        }

        if let source = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue() {
            runLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .defaultMode)
        }
    }

    static func readSystemPowerSource() -> BatteryReading? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
            return nil
        }

        return BatteryReading(description: description)
    }

    private func updateBatteryInfo() {
        guard let reading = readPowerSource() else { return }

        batteryLevel = reading.level
        isPluggedIn = reading.isPluggedIn
        isCharging = reading.isCharging
        minutesRemaining = reading.minutesRemaining
    }

    private func checkBatteryState() {
        let level = policy.evaluate(batteryLevel: batteryLevel, isPluggedIn: isPluggedIn)
        guard level != warningLevel else { return }

        warningLevel = level
        onWarningChange?(level)
    }

    deinit {
        stopMonitoring()
    }
}
