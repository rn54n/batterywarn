import Foundation
import IOKit.ps
import Combine

class BatteryMonitor: ObservableObject {
    @Published var batteryLevel: Int = 100
    @Published var isCharging: Bool = false
    @Published var isPluggedIn: Bool = false
    @Published var threshold: Int {
        didSet {
            UserDefaults.standard.set(threshold, forKey: "batteryThreshold")
            checkBatteryState()
        }
    }
    @Published var criticalThreshold: Int = 5 // Below this = fully blocking

    var onLowBattery: ((_ isCritical: Bool) -> Void)?
    var onPowerRestored: (() -> Void)?
    var onBatteryUpdate: (() -> Void)?

    private var timer: Timer?
    private var isOverlayShowing = false
    private var runLoopSource: CFRunLoopSource?

    // Track dismissed level to re-show at next drop
    private var dismissedAtLevel: Int? = nil

    init() {
        self.threshold = UserDefaults.standard.object(forKey: "batteryThreshold") as? Int ?? 10
        updateBatteryInfo()
    }

    func startMonitoring() {
        updateBatteryInfo()
        checkBatteryState()

        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateBatteryInfo()
            self?.checkBatteryState()
            self?.onBatteryUpdate?()
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

    /// Call this when user dismisses the overlay
    func dismissOverlay() {
        dismissedAtLevel = batteryLevel
        isOverlayShowing = false
    }

    /// Check if overlay should show (respects dismissal)
    var shouldShowOverlay: Bool {
        guard batteryLevel <= threshold && !isPluggedIn else { return false }

        // If dismissed at a level, only show again when battery drops further
        if let dismissed = dismissedAtLevel {
            return batteryLevel < dismissed
        }
        return true
    }

    /// Check if current state is critical (no dismiss allowed)
    var isCritical: Bool {
        return batteryLevel <= criticalThreshold && !isPluggedIn
    }

    private func setupPowerSourceNotification() {
        let context = Unmanaged.passUnretained(self).toOpaque()

        let callback: IOPowerSourceCallbackType = { context in
            guard let context = context else { return }
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async {
                monitor.updateBatteryInfo()
                monitor.checkBatteryState()
                monitor.onBatteryUpdate?()
            }
        }

        if let source = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue() {
            runLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .defaultMode)
        }
    }

    private func updateBatteryInfo() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
            return
        }

        if let currentCapacity = description[kIOPSCurrentCapacityKey] as? Int {
            batteryLevel = currentCapacity
        }

        if let powerSource = description[kIOPSPowerSourceStateKey] as? String {
            isPluggedIn = powerSource == kIOPSACPowerValue
        }

        if let charging = description[kIOPSIsChargingKey] as? Bool {
            isCharging = charging
        }
    }

    private func checkBatteryState() {
        // Reset dismissal when plugged in
        if isPluggedIn {
            dismissedAtLevel = nil
            if isOverlayShowing {
                isOverlayShowing = false
                onPowerRestored?()
            }
            return
        }

        // Check if we should show overlay
        if shouldShowOverlay && !isOverlayShowing {
            isOverlayShowing = true
            onLowBattery?(isCritical)
        }
    }

    deinit {
        stopMonitoring()
    }
}
