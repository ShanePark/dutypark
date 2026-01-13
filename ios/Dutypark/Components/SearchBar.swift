import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    var onSubmit: (() -> Void)?

    init(text: Binding<String>, placeholder: String = "검색", onSubmit: (() -> Void)? = nil) {
        self._text = text
        self.placeholder = placeholder
        self.onSubmit = onSubmit
    }

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .onSubmit {
                    onSubmit?()
                }

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

#Preview {
    VStack(spacing: 20) {
        SearchBar(text: .constant(""), placeholder: "일정 검색")
        SearchBar(text: .constant("회의"), placeholder: "일정 검색")
    }
    .padding()
}
