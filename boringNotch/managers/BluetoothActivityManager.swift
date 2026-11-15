//
//  BluetoothActivityManager.swift
//  boringNotch
//
//  Tracks Bluetooth device connections and surfaces them as notch live activities.
//

import Defaults
import Foundation
import IOBluetooth
import SwiftUI

@MainActor
final class BluetoothActivityManager: NSObject, ObservableObject {
    static let shared = BluetoothActivityManager()

    /// Name of the device from the most recent connection event.
    @Published private(set) var lastEventDeviceName: String = ""
    /// Whether the most recent event was a connection (true) or disconnection (false).
    @Published private(set) var lastEventConnected: Bool = true
    /// Names of all Bluetooth devices that are currently connected.
    @Published private(set) var connectedDeviceNames: [String] = []

    private var connectNotification: IOBluetoothUserNotification?
    private var disconnectNotifications: [String: IOBluetoothUserNotification] = [:]
    private var pollTimer: Timer?
    private var knownConnectedAddresses: Set<String> = []
    private var started = false
    private var pendingActivities: [(name: String, connected: Bool)] = []
    private var activityTask: Task<Void, Never>?

    private override init() {
        super.init()
        start()
    }

    func start() {
        guard !started else { return }
        started = true

        connectNotification = IOBluetoothDevice.register(
            forConnectNotifications: self,
            selector: #selector(bluetoothDeviceConnected(_:device:))
        )

        // Seed the current state without showing a notification for devices that
        // were already connected when the app launched.
        refreshConnectedDevices(notify: false)

        // IOBluetooth notifications can be missed (for example when the app is
        // relaunched while a device stays connected), so poll as a fallback.
        pollTimer = Timer(timeInterval: 6, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshConnectedDevices(notify: true)
            }
        }
        if let pollTimer { RunLoop.main.add(pollTimer, forMode: .common) }
    }

    func stop() {
        connectNotification?.unregister()
        connectNotification = nil

        for notification in disconnectNotifications.values {
            notification.unregister()
        }
        disconnectNotifications.removeAll()

        pollTimer?.invalidate()
        pollTimer = nil
        started = false
        activityTask?.cancel()
        activityTask = nil
        pendingActivities.removeAll()
        knownConnectedAddresses.removeAll()
    }

    // MARK: - IOBluetooth notifications

    @objc nonisolated private func bluetoothDeviceConnected(
        _ notification: IOBluetoothUserNotification,
        device: IOBluetoothDevice
    ) {
        Task { @MainActor [weak self] in
            self?.handleDeviceEvent(device: device, connected: true)
        }
    }

    @objc nonisolated private func bluetoothDeviceDisconnected(
        _ notification: IOBluetoothUserNotification,
        device: IOBluetoothDevice
    ) {
        Task { @MainActor [weak self] in
            self?.handleDeviceEvent(device: device, connected: false)
        }
    }

    private func handleDeviceEvent(device: IOBluetoothDevice, connected: Bool) {
        guard started, let address = device.addressString else { return }

        if connected {
            registerDisconnectNotification(for: device, address: address)

            guard !knownConnectedAddresses.contains(address) else { return }
            knownConnectedAddresses.insert(address)
        } else {
            disconnectNotifications[address]?.unregister()
            disconnectNotifications[address] = nil

            guard knownConnectedAddresses.contains(address) else { return }
            knownConnectedAddresses.remove(address)
        }

        connectedDeviceNames = pairedDevices()
            .filter { $0.isConnected() }
            .map(displayName)
            .sorted()

        emitActivity(device: device, connected: connected)
    }

    private func registerDisconnectNotification(for device: IOBluetoothDevice, address: String) {
        guard disconnectNotifications[address] == nil else { return }
        disconnectNotifications[address] = device.register(
            forDisconnectNotification: self,
            selector: #selector(bluetoothDeviceDisconnected(_:device:))
        )
    }

    // MARK: - Polling fallback

    private func refreshConnectedDevices(notify: Bool) {
        guard started else { return }
        let devices = pairedDevices()
        var currentAddresses: Set<String> = []
        var connectedDevices: [IOBluetoothDevice] = []

        for device in devices where device.isConnected() {
            guard let address = device.addressString else { continue }
            currentAddresses.insert(address)
            connectedDevices.append(device)
            registerDisconnectNotification(for: device, address: address)
        }

        connectedDeviceNames = connectedDevices.map(displayName).sorted()

        guard notify else {
            knownConnectedAddresses = currentAddresses
            return
        }

        let added = currentAddresses.subtracting(knownConnectedAddresses)
        let removed = knownConnectedAddresses.subtracting(currentAddresses)

        knownConnectedAddresses = currentAddresses

        for address in removed.sorted() {
            disconnectNotifications[address]?.unregister()
            disconnectNotifications[address] = nil
            if let device = devices.first(where: { $0.addressString == address }) {
                emitActivity(device: device, connected: false)
            }
        }
        for device in connectedDevices where added.contains(device.addressString ?? "") {
            emitActivity(device: device, connected: true)
        }
    }

    private func pairedDevices() -> [IOBluetoothDevice] {
        (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
    }

    // MARK: - Presentation

    private func emitActivity(device: IOBluetoothDevice, connected: Bool) {
        guard Defaults[.showBluetoothNotifications] else { return }

        pendingActivities.append((displayName(device), connected))
        guard activityTask == nil else { return }
        activityTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.activityTask = nil }
            while !self.pendingActivities.isEmpty {
                guard !Task.isCancelled, Defaults[.showBluetoothNotifications] else {
                    self.pendingActivities.removeAll()
                    return
                }
                let event = self.pendingActivities.removeFirst()
                self.lastEventDeviceName = event.name
                self.lastEventConnected = event.connected
                BoringViewCoordinator.shared.toggleExpandingView(
                    status: true, type: .bluetooth, value: event.connected ? 1 : 0
                )
                do {
                    try await Task.sleep(for: .seconds(3.2))
                } catch {
                    return
                }
            }
        }
    }

    private func displayName(_ device: IOBluetoothDevice) -> String {
        if let name = device.name, !name.isEmpty {
            return name
        }
        if let nameOrAddress = device.nameOrAddress, !nameOrAddress.isEmpty {
            return nameOrAddress
        }
        return device.addressString ?? "Bluetooth Device"
    }
}
