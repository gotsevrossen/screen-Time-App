import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if model.hasOnboarded {
                MainTabs()
            } else {
                OnboardingView()
            }
        }
        .alert("Something needs attention",
               isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}

private struct MainTabs: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max") }
            LimitsView()
                .tabItem { Label("Limits", systemImage: "hourglass") }
            DowntimeView()
                .tabItem { Label("Downtime", systemImage: "moon") }
            WebFilterView()
                .tabItem { Label("Web", systemImage: "globe") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
