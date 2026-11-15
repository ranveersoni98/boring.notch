import CoreWLAN
import Defaults
import Foundation
import Network

@MainActor
final class WiFiActivityManager: ObservableObject {
    static let shared = WiFiActivityManager()

    @Published private(set) var isConnected = false
    @Published private(set) var ssid = ""
    @Published private(set) var isWiFiEnabled = false

    private var pathMonitor: NWPathMonitor?
    private let pathMonitorQueue = DispatchQueue(label: "com.boringNotch.wifiMonitor", qos: .utility)
    private var pollTimer: Timer?
    private var hasInitialPath = false
    private var pathIsConnected = false

    private init() {
        startMonitoring()
    }

    func startMonitoring() {
        guard pathMonitor == nil else { return }
        hasInitialPath = false
        let monitor = NWPathMonitor(requiredInterfaceType: .wifi)
        pathMonitor = monitor
        monitor.pathUpdateHandler = { [weak self, weak monitor] path in
            let connected = path.status == .satisfied
            Task { @MainActor in
                guard let self, let monitor, self.pathMonitor === monitor else { return }
                self.pathIsConnected = connected
                self.updateCurrentState(postNotification: self.hasInitialPath)
                self.hasInitialPath = true
            }
        }
        monitor.start(queue: pathMonitorQueue)

        // A network switch need not change path availability. Check the SSID as
        // well; macOS may redact it, in which case the view uses a generic label.
        let timer = Timer(timeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.pathMonitor != nil else { return }
                self.updateCurrentState(postNotification: self.hasInitialPath)
            }
        }
        pollTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stopMonitoring() {
        pathMonitor?.cancel()
        pathMonitor = nil
        pollTimer?.invalidate()
        pollTimer = nil
        hasInitialPath = false
    }

    private func updateCurrentState(postNotification: Bool) {
        let interface = CWWiFiClient.shared().interface()
        let powerOn = interface?.powerOn() ?? false
        let currentSSID = powerOn ? (interface?.ssid() ?? "") : ""
        let connected = powerOn && (pathIsConnected || !currentSSID.isEmpty)
        let connectionChanged = connected != isConnected
        let networkChanged = connected && !currentSSID.isEmpty && !ssid.isEmpty && currentSSID != ssid

        isWiFiEnabled = powerOn
        isConnected = connected
        ssid = connected ? currentSSID : ""

        guard postNotification, connectionChanged || networkChanged,
              Defaults[.showWiFiNotifications] else { return }
        BoringViewCoordinator.shared.toggleExpandingView(
            status: true, type: .wifi, value: connected ? 1 : 0
        )
    }
}
