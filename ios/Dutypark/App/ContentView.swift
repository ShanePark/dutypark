import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
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
                    Label("근무표", systemImage: "calendar")
                }

            ScheduleListView()
                .tabItem {
                    Label("일정", systemImage: "clock.fill")
                }

            TodoListView()
                .tabItem {
                    Label("할일", systemImage: "checklist")
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
