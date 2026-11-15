//
//  TabSelectionView.swift
//  boringNotch
//
//  Created by Hugo Persson on 2024-08-25.
//

import Defaults
import SwiftUI

struct TabModel: Identifiable {
    var id: NotchViews { view }
    let label: String
    let icon: String
    let view: NotchViews
}

struct TabSelectionView: View {
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @Default(.boringShelf) private var boringShelf
    @Default(.showTodosTab) private var showTodosTab
    @Default(.systemActivityEnabled) private var systemActivityEnabled
    @Namespace var animation

    private var tabs: [TabModel] {
        var result = [TabModel(label: "Home", icon: "house.fill", view: .home)]
        if boringShelf {
            result.append(
                TabModel(label: "Shelf", icon: "tray.fill", view: .shelf)
            )
        }
        if systemActivityEnabled {
            result.append(
                TabModel(label: "System", icon: "chart.bar.xaxis", view: .systemActivity)
            )
        }
        if showTodosTab {
            result.append(
                TabModel(label: "Todos", icon: "checklist", view: .todos)
            )
        }
        return result
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                TabButton(label: tab.label, icon: tab.icon, selected: coordinator.currentView == tab.view) {
                    withAnimation(.smooth) {
                        coordinator.currentView = tab.view
                    }
                }
                .frame(height: 26)
                .foregroundStyle(
                    tab.view == coordinator.currentView ? .white : .gray
                )
                .background {
                    if tab.view == coordinator.currentView {
                        Capsule()
                            .fill(
                                coordinator.currentView == tab.view
                                    ? Color(nsColor: .secondarySystemFill)
                                    : Color.clear
                            )
                            .matchedGeometryEffect(
                                id: "capsule",
                                in: animation
                            )
                    }
                }
            }
        }
        .clipShape(Capsule())
    }
}

#Preview {
    BoringHeader().environmentObject(BoringViewModel())
}
