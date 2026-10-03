import SwiftUI

@main
struct ClaimSaathiApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .tint(Color.csCyan)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if model.isLoggedIn {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.isLoggedIn)
    }
}

struct MainTabView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView(selection: $model.tab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(AppTab.home)
            ClaimsView()
                .tabItem { Label("Claims", systemImage: "list.bullet.rectangle") }
                .tag(AppTab.claims)
            DocsView()
                .tabItem { Label("Docs", systemImage: "doc.text.fill") }
                .tag(AppTab.docs)
            AssistantView()
                .tabItem { Label("AI", systemImage: "sparkles") }
                .tag(AppTab.assistant)
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(AppTab.profile)
        }
        .tint(Color.csNavy)
    }
}
