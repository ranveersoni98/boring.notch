import Cocoa
import Defaults
import Foundation
import IOKit.ps
import SwiftUI

/// A view model that manages and monitors the battery status of the device
class BatteryStatusViewModel: ObservableObject {

    private var wasCharging: Bool = false
    private var powerSourceChangedCallback: IOPowerSourceCallbackType?
    private var runLoopSource: Unmanaged<CFRunLoopSource>?

    @ObservedObject var coordinator = BoringViewCoordinator.shared

    @Published private(set) var levelBattery: Float = 0.0
    @Published private(set) var maxCapacity: Float?
    @Published private(set) var isPluggedIn: Bool = false
    @Published private(set) var isCharging: Bool = false
    @Published private(set) var isInLowPowerMode: Bool = false
    @Published private(set) var isInitial: Bool = false
    @Published private(set) var timeToFullCharge: Int = 0
    @Published private(set) var timeToDischarge: Int = 0
    @Published private(set) var maxAdapterWatts: Int = 0
    @Published private(set) var lastStatus: LastStatus = .plugged(false)

    enum LastStatus: Equatable {
        case plugged(Bool)
        case lowPower(Bool)
        case charging(isCharging: Bool, level: Float)
    }

    var statusText: LocalizedStringKey {
        switch lastStatus {
        case .plugged(let plugged):
            return LocalizedStringKey(plugged ? "Plugged In" : "Unplugged")
        case .lowPower(let enabled):
            let key = enabled ? "Low Power: On" : "Low Power: Off"
            return LocalizedStringKey(key)
        case .charging(let isCharging, let level):
            if isCharging {
                return LocalizedStringKey("Charging battery")
            }
            if level >= 100 {
                return LocalizedStringKey("Full charge")
            }
            return LocalizedStringKey(isPluggedIn ? "Not charging" : "Unplugged")
        }
    }

    var statusIcon: String {
        switch lastStatus {
        case .plugged(let plugged):
            return plugged ? "powerplug.fill" : "powerplug.slash.fill"
        case .lowPower(let enabled):
            return enabled ? "bolt.circle.fill" : "bolt.circle"
        case .charging(let isCharging, _):
            return isCharging ? "bolt.fill" : (isPluggedIn ? "powerplug.fill" : "powerplug.slash.fill")
        }
    }

    var statusColor: Color {
        switch lastStatus {
        case .plugged(let plugged):
            return plugged ? .green : .orange
        case .lowPower(let enabled):
            return enabled ? .yellow : .gray
        case .charging(let isCharging, _):
            return isCharging ? .green : (isPluggedIn ? .green : .orange)
        }
    }

    private let managerBattery = BatteryActivityManager.shared
    private var managerBatteryId: Int?

    static let shared = BatteryStatusViewModel()

    /// Initializes the view model with a given BoringViewModel instance
    /// - Parameter vm: The BoringViewModel instance
    private init() {
        setupPowerStatus()
        setupMonitor()
    }

    /// Sets up the initial power status by fetching battery information
    private func setupPowerStatus() {
        let batteryInfo = managerBattery.initializeBatteryInfo()
        updateBatteryInfo(batteryInfo)
    }

    /// Sets up the monitor to observe battery events
    private func setupMonitor() {
        managerBatteryId = managerBattery.addObserver { [weak self] event in
            guard let self = self else { return }
            self.handleBatteryEvent(event)
        }
    }

    /// Handles battery events and updates the corresponding properties
    /// - Parameter event: The battery event to handle
    private func handleBatteryEvent(_ event: BatteryActivityManager.BatteryEvent) {
        switch event {
        case .powerSourceChanged(let isPluggedIn):
            print("🔌 Power source: \(isPluggedIn ? "Connected" : "Disconnected")")
            withAnimation {
                self.isPluggedIn = isPluggedIn
                self.lastStatus = .plugged(isPluggedIn)
                self.notifyImportanChangeStatus()
            }

        case .batteryLevelChanged(let level):
            print("🔋 Battery level: \(Int(level))%")
            withAnimation {
                self.levelBattery = level
            }

        case .lowPowerModeChanged(let isEnabled):
            print("⚡ Low power mode: \(isEnabled ? "Enabled" : "Disabled")")
            withAnimation {
                self.isInLowPowerMode = isEnabled
                self.lastStatus = .lowPower(isEnabled)
                self.notifyImportanChangeStatus()
            }

        case .isChargingChanged(let isCharging):
            print("🔌 Charging: \(isCharging ? "Yes" : "No")")
            withAnimation {
                self.isCharging = isCharging
                if self.isPluggedIn {
                    self.lastStatus = .charging(isCharging: isCharging, level: self.levelBattery)
                    self.notifyImportanChangeStatus()
                }
            }

        case .timeToFullChargeChanged(let time):
            print("🕒 Time to full charge: \(time) minutes")
            withAnimation {
                self.timeToFullCharge = time
            }

        case .timeToDischargeChanged(let time):
            print("🕒 Time until empty: \(time) minutes")
            withAnimation {
                self.timeToDischarge = time
            }

        case .maxCapacityChanged(let capacity):
            print("🔋 Max capacity: \(capacity.map { "\($0)" } ?? "Unavailable")")
            withAnimation {
                self.maxCapacity = capacity
            }

        case .adapterWattageChanged(let watts):
            print("🔌 Power adapter: \(watts)W")
            withAnimation {
                self.maxAdapterWatts = watts
            }

        case .error(let description):
            print("⚠️ Error: \(description)")
        }
    }

    /// Updates the battery information with the given BatteryInfo instance
    /// - Parameter batteryInfo: The BatteryInfo instance containing the battery data
    private func updateBatteryInfo(_ batteryInfo: BatteryInfo) {
        withAnimation {
            self.levelBattery = batteryInfo.currentCapacity
            self.isPluggedIn = batteryInfo.isPluggedIn
            self.isCharging = batteryInfo.isCharging
            self.isInLowPowerMode = batteryInfo.isInLowPowerMode
            self.timeToFullCharge = batteryInfo.timeToFullCharge
            self.timeToDischarge = batteryInfo.timeToDischarge
            self.maxCapacity = batteryInfo.maxCapacity
            self.maxAdapterWatts = batteryInfo.maxAdapterWatts
            self.lastStatus = .plugged(batteryInfo.isPluggedIn)
        }
    }

    /// Notifies important changes in the battery status with an optional delay
    /// - Parameter delay: The delay before notifying the change, default is 0.0
    private func notifyImportanChangeStatus(delay: Double = 0.0) {
        guard Defaults[.showPowerStatusNotifications] else { return }
        Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch { return }
            guard Defaults[.showPowerStatusNotifications] else { return }
            self.coordinator.toggleExpandingView(status: true, type: .battery)
        }
    }

    deinit {
        print("🔌 Cleaning up battery monitoring...")
        if let managerBatteryId: Int = managerBatteryId {
            managerBattery.removeObserver(byId: managerBatteryId)
        }
    }

}
