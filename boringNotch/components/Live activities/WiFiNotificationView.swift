//
//  WiFiNotificationView.swift
//  boringNotch
//
//  Created by Antigravity on 2026-08-31.
//

import SwiftUI

struct WiFiNotificationView: View {
    @EnvironmentObject var vm: BoringViewModel
    var isConnected: Bool
    var ssid: String

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: isConnected ? "wifi" : "wifi.slash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isConnected ? Color.blue : Color.orange)
                    .contentTransition(.symbolEffect(.automatic))

                Text(isConnected ? (ssid.isEmpty ? "Wi-Fi Connected" : ssid) : "Wi-Fi Disconnected")
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
                Text(isConnected ? "Connected" : "Offline")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isConnected ? Color.gray : Color.orange.opacity(0.8))
                    .lineLimit(1)
            }
            .frame(width: 80, alignment: .trailing)
        }
        .frame(height: vm.effectiveClosedNotchHeight == 0 ? 10 : vm.effectiveClosedNotchHeight, alignment: .center)
    }
}
