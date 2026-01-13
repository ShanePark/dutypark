import SwiftUI

struct ShiftDetailSheet: View {
    @ObservedObject var viewModel: TeamViewModel
    let year: Int
    let month: Int
    let day: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("\(year)년 \(month)월 \(day)일")
                        .font(.headline)
                        .padding(.top)

                    if viewModel.shiftData.isEmpty {
                        Text("근무 정보가 없습니다")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(viewModel.shiftData, id: \.dutyType.id) { shift in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Circle()
                                        .fill(shift.dutyType.swiftUIColor)
                                        .frame(width: 12, height: 12)

                                    Text(shift.dutyType.name)
                                        .font(.headline)

                                    Text("\(shift.members.count)명")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                FlowLayout(spacing: 8) {
                                    ForEach(shift.members) { member in
                                        HStack(spacing: 4) {
                                            ProfileAvatar(
                                                memberId: member.id,
                                                name: member.name,
                                                hasProfilePhoto: member.hasProfilePhoto ?? false,
                                                profilePhotoVersion: member.profilePhotoVersion,
                                                size: 24
                                            )
                                            Text(member.name)
                                                .font(.caption)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("근무 현황")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }
}

// Simple FlowLayout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > width && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing

                self.size.width = max(self.size.width, x)
                self.size.height = y + rowHeight
            }
        }
    }
}
