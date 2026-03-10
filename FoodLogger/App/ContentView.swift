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
