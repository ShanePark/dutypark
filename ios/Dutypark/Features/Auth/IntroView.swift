import SwiftUI

struct IntroFeature: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let accent: Color
}

struct IntroView: View {
    @Environment(\.colorScheme) var colorScheme

    private let features: [IntroFeature] = [
        IntroFeature(title: "일상을 함께", description: "서로의 일정을 공유하며 함께 계획해요.", icon: "heart.fill", accent: .pink),
        IntroFeature(title: "근무 & 연차 관리", description: "근무표와 휴무를 손쉽게 관리해요.", icon: "clock.fill", accent: .orange),
        IntroFeature(title: "다양한 일상", description: "아이 일정, 경기 일정까지 함께 기록해요.", icon: "person.2.fill", accent: .blue),
        IntroFeature(title: "할일 관리", description: "칸반 보드로 할 일을 정리해요.", icon: "checkmark.circle.fill", accent: .green),
        IntroFeature(title: "D-Day 카운트다운", description: "중요한 날을 잊지 않도록 알려줘요.", icon: "flag.fill", accent: .red),
        IntroFeature(title: "공휴일 자동 연동", description: "공휴일 정보를 자동으로 표시해요.", icon: "sun.max.fill", accent: .yellow)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxxl) {
                    heroSection
                    scrollHint
                    showcaseSection
                    ctaSection
                }
                .padding(.horizontal, DesignSystem.Spacing.xxl)
                .padding(.vertical, DesignSystem.Spacing.xxxl)
            }
            .navigationBarHidden(true)
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text("Dutypark")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("나와 소중한 사람들을 위한 소셜 캘린더")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.accent)

            Text("근무 일정, 아이 등원, 응원하는 팀의 경기까지. 서로의 일상을 공유하고 함께 계획하세요.")
                .font(.body)
                .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textSecondary : DesignSystem.Colors.Light.textSecondary)

            NavigationLink(destination: LoginView()) {
                HStack(spacing: 6) {
                    Text("시작하기")
                        .fontWeight(.semibold)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.accent)
                .foregroundColor(.white)
                .cornerRadius(DesignSystem.CornerRadius.full)
            }
        }
    }

    private var scrollHint: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Text("스크롤하여 더 알아보기")
                .font(.caption)
                .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted)
            Image(systemName: "arrow.down")
                .font(.caption2)
                .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted)
        }
    }

    private var showcaseSection: some View {
        TabView {
            ForEach(features) { feature in
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Image(systemName: feature.icon)
                        .font(.system(size: 32))
                        .foregroundColor(feature.accent)

                    Text(feature.title)
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text(feature.description)
                        .font(.body)
                        .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textSecondary : DesignSystem.Colors.Light.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DesignSystem.Spacing.xxl)
                .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgSecondary : DesignSystem.Colors.Light.bgCard)
                .cornerRadius(DesignSystem.CornerRadius.lg)
                .shadow(color: DesignSystem.Shadow.sm(colorScheme), radius: 4, x: 0, y: 2)
                .padding(.horizontal, DesignSystem.Spacing.md)
            }
        }
        .frame(height: 240)
        .tabViewStyle(.page(indexDisplayMode: .always))
    }

    private var ctaSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("소중한 사람들과 연결되세요")
                .font(.title3)
                .fontWeight(.semibold)

            Text("당신의 일정은 단순한 근무 그 이상이니까요. 카카오톡으로 지금 바로 시작하세요.")
                .font(.body)
                .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textSecondary : DesignSystem.Colors.Light.textSecondary)

            NavigationLink(destination: LoginView()) {
                Text("로그인 / 회원가입")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .background(DesignSystem.Colors.accent)
                    .foregroundColor(.white)
                    .cornerRadius(DesignSystem.CornerRadius.sm)
            }

            Text("먼저 기능 둘러보기")
                .font(.footnote)
                .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted)
        }
    }
}

#Preview {
    IntroView()
        .environmentObject(AuthManager.shared)
}
