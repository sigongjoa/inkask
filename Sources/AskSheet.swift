import SwiftUI
import UIKit

// ✨ Ask 시트: 잘린 이미지 미리보기 + 제안 질문 칩 + 복사/보내기
struct AskSheet: View {
    let image: UIImage
    @State private var question = ""
    @State private var copied = false
    @State private var showShare = false

    private let chips = ["이 그림 설명해줘", "여기서 틀린 부분 찾아줘", "시험 문제로 만들어줘"]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: 240)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Text("이대로 보내거나, 질문을 붙여서")
                .font(.caption)
                .foregroundStyle(.secondary)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { chipButtons }
                VStack(alignment: .leading, spacing: 8) { chipButtons }
            }

            Button {
                UIPasteboard.general.image = image
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                copied = true
            } label: {
                Label(copied ? "복사됨 — Claude에 붙여넣으세요" : "이미지 복사",
                      systemImage: copied ? "checkmark" : "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                showShare = true
            } label: {
                Label("Claude로 보내기", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .sheet(isPresented: $showShare) {
            ActivityView(items: question.isEmpty ? [image] : [image, question])
        }
    }

    @ViewBuilder private var chipButtons: some View {
        ForEach(chips, id: \.self) { chip in
            Button(chip) { question = (question == chip) ? "" : chip }
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
                .tint(question == chip ? .blue : .gray)
        }
    }
}
