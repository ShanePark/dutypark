import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showingLogoutAlert = false

    var body: some View {
        NavigationStack {
            List {
                if let user = authManager.currentUser {
                    Section("계정") {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.name)
                                    .font(.headline)
                                Text(user.email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)

                        if let team = user.team {
                            HStack {
                                Text("소속")
                                Spacer()
                                Text(team)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("앱 정보") {
                    HStack {
                        Text("버전")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showingLogoutAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("로그아웃")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("설정")
            .alert("로그아웃", isPresented: $showingLogoutAlert) {
                Button("취소", role: .cancel) {}
                Button("로그아웃", role: .destructive) {
                    authManager.logout()
                }
            } message: {
                Text("정말 로그아웃하시겠습니까?")
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthManager.shared)
}
