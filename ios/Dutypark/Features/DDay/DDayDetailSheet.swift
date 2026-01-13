import SwiftUI

struct DDayDetailSheet: View {
    let dday: DDayDto
    @ObservedObject var viewModel: DDayViewModel
    let memberId: Int?
    let isReadOnly: Bool
    let onClose: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false

    init(dday: DDayDto, viewModel: DDayViewModel, memberId: Int?, isReadOnly: Bool = false, onClose: @escaping () -> Void) {
        self.dday = dday
        self.viewModel = viewModel
        self.memberId = memberId
        self.isReadOnly = isReadOnly
        self.onClose = onClose
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    DDayBadge(daysLeft: dday.daysLeft, size: .large)

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        detailRow(title: "제목", value: dday.title)
                        detailRow(title: "날짜", value: formattedDate(dday.date))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        togglePinned()
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: isPinned ? "star.fill" : "star")
                                .foregroundColor(isPinned ? Color(hex: "#F59E0B")! : .gray)
                            Text(isPinned ? "캘린더 고정 해제" : "캘린더에 고정하기")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)

                    if !isReadOnly {
                        HStack(spacing: DesignSystem.Spacing.md) {
                            Button {
                                showEditSheet = true
                            } label: {
                                HStack {
                                    Image(systemName: "pencil")
                                    Text("수정")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(DesignSystem.Colors.accent.opacity(0.1))
                                .foregroundColor(DesignSystem.Colors.accent)
                                .cornerRadius(12)
                            }

                            Button {
                                showDeleteAlert = true
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("삭제")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.red.opacity(0.1))
                                .foregroundColor(.red)
                                .cornerRadius(12)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("디데이 상세")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") {
                        close()
                    }
                }
            }
            .sheet(isPresented: $showEditSheet) {
                AddDDaySheet(viewModel: viewModel, ddayToEdit: dday)
            }
            .alert("D-Day 삭제", isPresented: $showDeleteAlert) {
                Button("취소", role: .cancel) {}
                Button("삭제", role: .destructive) {
                    Task {
                        if await viewModel.deleteDDay(dday.id) {
                            if isPinned, let memberId {
                                viewModel.clearPinnedDDay(memberId: memberId)
                            }
                            close()
                        }
                    }
                }
            } message: {
                Text("'\(dday.title)'을(를) 삭제하시겠습니까?")
            }
        }
    }

    private var isPinned: Bool {
        viewModel.pinnedDDayId == dday.id
    }

    private func togglePinned() {
        guard let memberId else { return }
        viewModel.togglePinnedDDay(dday, memberId: memberId)
    }

    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
                .foregroundColor(.primary)
        }
    }

    private func formattedDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }

        let outputFormatter = DateFormatter()
        outputFormatter.locale = Locale(identifier: "ko_KR")
        outputFormatter.dateFormat = "yyyy년 M월 d일 (E)"
        return outputFormatter.string(from: date)
    }

    private func close() {
        dismiss()
        onClose()
    }
}

#Preview {
    DDayDetailSheet(
        dday: DDayDto(id: 1, title: "루나 생일", date: "2023-09-13", isPrivate: false, calc: -10, daysLeft: -10),
        viewModel: DDayViewModel(),
        memberId: 1
    ) {}
}
