//
//  BluetoothNotificationView.swift
//  boringNotch
//
//  Compact live activity shown in the closed notch when a Bluetooth device
//  connects or disconnects.
//

import SwiftUI

struct BluetoothNotificationView: View {
    @EnvironmentObject var vm: BoringViewModel
    var isConnected: Bool
    var deviceName: String

    private var title: String {
        let name = deviceName.isEmpty ? "Bluetooth Device" : deviceName
        return name
    }

    private var symbolName: String {
        let lowercasedName = deviceName.lowercased()

        if lowercasedName.contains("airpods max") {
            return isConnected ? "airpodsmax" : "headphones"
        }
        if lowercasedName.contains("airpods pro") {
            return isConnected ? "airpodspro" : "headphones"
        }
        if lowercasedName.contains("airpods") {
            return isConnected ? "airpods" : "headphones"
        }
        if lowercasedName.contains("beats") || lowercasedName.contains("headphone") {
            return "headphones"
        }
        return isConnected
            ? "antenna.radiowaves.left.and.right"
            : "antenna.radiowaves.left.and.right.slash"
    }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: symbolName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isConnected ? Color.blue : Color.orange)
                    .contentTransition(.symbolEffect(.automatic))

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .allowsTightening(true)
            }

            Rectangle()
                .fill(.black)
                .frame(width: vm.closedNotchSize.width + 10)

            HStack {
                Text(isConnected ? "Connected" : "Disconnected")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isConnected ? Color.gray : Color.orange.opacity(0.8))
                    .lineLimit(1)
            }
            .frame(width: 90, alignment: .trailing)
        }
        .frame(
            height: vm.effectiveClosedNotchHeight == 0 ? 10 : vm.effectiveClosedNotchHeight,
            alignment: .center
        )
    }
}
