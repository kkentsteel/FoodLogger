import SwiftUI

enum AppTab: Int, CaseIterable {
    case today, foods, scan, chat

    var title: String {
        switch self {
        case .today: "Today"
        case .foods: "Foods"
        case .scan: "Scan"
        case .chat: "Chat"
        }
    }

    var icon: String {
        switch self {
        case .today: "calendar"
        case .foods: "fork.knife"
        case .scan: "barcode.viewfinder"
        case .chat: "bubble.left.and.bubble.right"
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: AppTab
    let onAddTap: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Left tabs
            tabButton(for: .today)
            tabButton(for: .foods)

            // Center + button
            addButton

            // Right tabs
            tabButton(for: .scan)
            tabButton(for: .chat)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 2)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .top) {
                    Divider()
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func tabButton(for tab: AppTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20))
                    .frame(height: 24)
                Text(tab.title)
                    .font(.caption2)
            }
            .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
    }

    private var addButton: some View {
        Button(action: onAddTap) {
            ZStack {
                Circle()
                    .fill(.tint)
                    .frame(width: 56, height: 56)
                    .shadow(color: .green.opacity(0.3), radius: 8, y: 4)

                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .offset(y: -16)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Add Food")
        .accessibilityHint("Opens the add food sheet")
    }
}
