import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var profiles: [UserProfile]
    @State private var showOnboarding = false
    @State private var selectedTab: AppTab = .today
    @State private var showAddFood = false

    private var hasProfile: Bool {
        !profiles.isEmpty
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tag(AppTab.today)
                .tabItem { Label("Today", systemImage: "calendar") }

            FoodsView()
                .tag(AppTab.foods)
                .tabItem { Label("Foods", systemImage: "fork.knife") }

            ScanTabView()
                .tag(AppTab.scan)
                .tabItem { Label("Scan", systemImage: "barcode.viewfinder") }

            ChatView()
                .tag(AppTab.chat)
                .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right") }
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            CustomTabBar(selectedTab: $selectedTab) {
                showAddFood = true
            }
        }
        .sheet(isPresented: $showAddFood) {
            AddFoodToMealSheet(mealSlot: nil, date: Date())
        }
        .onChange(of: profiles.isEmpty) { _, isEmpty in
            if isEmpty && !showOnboarding {
                showOnboarding = true
            }
        }
        .onAppear {
            if !hasProfile {
                showOnboarding = true
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView()
                .interactiveDismissDisabled()
        }
    }
}
