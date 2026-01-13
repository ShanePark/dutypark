import SwiftUI

struct GuideSection: Identifiable {
    let id = UUID()
    let title: String
    let items: [GuideItem]
}

struct GuideItem: Identifiable {
    let id = UUID()
    let title: String
    let details: [String]
}

struct GuideView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var expandedSectionIds: Set<UUID> = []

    private let sections: [GuideSection] = [
        GuideSection(
            title: "대시보드 (홈)",
            items: [
                GuideItem(
                    title: "오늘의 정보 확인",
                    details: [
                        "오늘 날짜와 요일, 내 근무를 바로 확인할 수 있어요.",
                        "오늘 일정에는 태그된 일정이 'by 이름' 형태로 표시돼요.",
                        "상단 영역을 누르면 내 달력으로 이동해요."
                    ]
                ),
                GuideItem(
                    title: "친구 목록",
                    details: [
                        "등록된 친구의 오늘 근무와 일정을 한눈에 볼 수 있어요.",
                        "친구 카드를 누르면 해당 친구의 달력으로 이동해요."
                    ]
                )
            ]
        ),
        GuideSection(
            title: "내 달력",
            items: [
                GuideItem(
                    title: "월간 보기",
                    details: [
                        "근무, 일정, 할일을 한 화면에서 확인할 수 있어요.",
                        "공휴일이 자동으로 표시돼요.",
                        "원하는 날짜를 눌러 상세 일정을 확인하세요."
                    ]
                ),
                GuideItem(
                    title: "비교 보기",
                    details: [
                        "친구 달력을 선택해 함께 비교할 수 있어요.",
                        "공유된 일정은 태그 표시로 구분돼요."
                    ]
                )
            ]
        ),
        GuideSection(
            title: "일정",
            items: [
                GuideItem(
                    title: "일정 추가/수정",
                    details: [
                        "시간, 공개 범위, 태그 친구를 설정할 수 있어요.",
                        "사진을 첨부해 기록을 남길 수 있어요."
                    ]
                ),
                GuideItem(
                    title: "검색",
                    details: [
                        "키워드로 일정과 기록을 빠르게 찾을 수 있어요."
                    ]
                )
            ]
        ),
        GuideSection(
            title: "할일",
            items: [
                GuideItem(
                    title: "칸반 보드",
                    details: [
                        "할 일, 진행중, 완료 상태를 칼럼별로 관리해요.",
                        "드래그로 순서와 상태를 변경할 수 있어요.",
                        "진행중 할 일은 달력에 표시돼요."
                    ]
                )
            ]
        ),
        GuideSection(
            title: "내 팀",
            items: [
                GuideItem(
                    title: "팀 달력",
                    details: [
                        "팀원 근무표와 팀 일정을 확인할 수 있어요.",
                        "매니저는 팀 관리 화면에서 멤버와 근무유형을 관리할 수 있어요."
                    ]
                )
            ]
        ),
        GuideSection(
            title: "친구 관리",
            items: [
                GuideItem(
                    title: "친구 추가/요청",
                    details: [
                        "친구 요청을 보내고 받은 요청을 관리할 수 있어요.",
                        "가족/친구 표시와 상단 고정을 지원해요."
                    ]
                )
            ]
        ),
        GuideSection(
            title: "설정",
            items: [
                GuideItem(
                    title: "내 정보 관리",
                    details: [
                        "프로필 사진과 공개 범위를 변경할 수 있어요.",
                        "세션 관리, 로그아웃, 약관 확인이 가능해요."
                    ]
                )
            ]
        )
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "book.fill")
                            .foregroundColor(DesignSystem.Colors.accent)
                        Text("이용 안내")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    Text("Dutypark의 주요 기능과 사용 방법을 안내합니다")
                        .font(.subheadline)
                        .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textSecondary : DesignSystem.Colors.Light.textSecondary)
                }

                HStack(spacing: DesignSystem.Spacing.sm) {
                    Button("모두 펼치기") {
                        expandedSectionIds = Set(sections.map { $0.id })
                    }
                    .buttonStyle(.bordered)

                    Button("모두 접기") {
                        expandedSectionIds.removeAll()
                    }
                    .buttonStyle(.bordered)
                }

                ForEach(sections) { section in
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedSectionIds.contains(section.id) },
                            set: { isExpanded in
                                if isExpanded {
                                    expandedSectionIds.insert(section.id)
                                } else {
                                    expandedSectionIds.remove(section.id)
                                }
                            }
                        )
                    ) {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            ForEach(section.items) { item in
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                    Text(item.title)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textPrimary : DesignSystem.Colors.Light.textPrimary)

                                    ForEach(item.details, id: \.self) { detail in
                                        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                                            Text("•")
                                                .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted)
                                            Text(detail)
                                                .font(.caption)
                                                .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textSecondary : DesignSystem.Colors.Light.textSecondary)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.top, DesignSystem.Spacing.sm)
                    } label: {
                        Text(section.title)
                            .font(.headline)
                            .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textPrimary : DesignSystem.Colors.Light.textPrimary)
                    }
                    .padding(DesignSystem.Spacing.md)
                    .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgSecondary : DesignSystem.Colors.Light.bgCard)
                    .cornerRadius(DesignSystem.CornerRadius.md)
                }
            }
            .padding(DesignSystem.Spacing.lg)
        }
        .navigationTitle("이용 안내")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        GuideView()
    }
}
