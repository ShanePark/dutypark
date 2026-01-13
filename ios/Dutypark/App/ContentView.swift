import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                MainTabView()
            } else {
                IntroView()
            }
        }
        .task {
            await authManager.checkAuthStatus()
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("홈", systemImage: "house.fill")
                }

            DutyView()
                .tabItem {
                    Label("내 달력", systemImage: "calendar")
                }

            TodoBoardView()
                .tabItem {
                    Label("할일", systemImage: "checklist")
                }

            TeamView()
                .tabItem {
                    Label("내 팀", systemImage: "person.3.fill")
                }

            SettingsView()
                .tabItem {
                    Label("설정", systemImage: "gearshape.fill")
                }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager.shared)
}
