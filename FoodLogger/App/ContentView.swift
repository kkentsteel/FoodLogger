import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var profiles: [UserProfile]
    @State private var showOnboarding = false

    private var hasProfile: Bool {
        !profiles.isEmpty
    }

    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "calendar")
                }

            FoodsView()
                .tabItem {
                    Label("Foods", systemImage: "fork.knife")
                }

            ScanTabView()
                .tabItem {
                    Label("Scan", systemImage: "barcode.viewfinder")
                }

            ChatView()
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
        }
        .onChange(of: profiles.isEmpty) { _, isEmpty in
            if isEmpty && !showOnboarding {
                showOnboarding = true
            }
        }
        .onAppear {
            // Delay slightly to let @Query populate
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if !hasProfile {
                    showOnboarding = true
                }
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView()
                .interactiveDismissDisabled()
        }
    }
}
