import SwiftUI

struct DocumentListView: View {
    @State private var docs: [URL] = []
    @State private var showImporter = false

    var body: some View {
        List {
            ForEach(docs, id: \.self) { pdf in
                NavigationLink {
                    NoteView(pdfURL: pdf)
                } label: {
                    Label {
                        Text(pdf.deletingLastPathComponent().lastPathComponent)
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: "doc.richtext")
                            .foregroundStyle(.tint)
                    }
                    .padding(.vertical, 6)
                }
            }
            .onDelete { indexSet in
                indexSet.map { docs[$0] }.forEach { FileStore.delete(pdf: $0) }
                docs = FileStore.listDocuments()
            }
        }
        .listStyle(.plain)
        .overlay {
            if docs.isEmpty {
                ContentUnavailableView {
                    Label("교재가 없습니다", systemImage: "doc.badge.plus")
                } description: {
                    Text("PDF를 가져와서 필기를 시작하세요.\n필기한 페이지는 복사해서 Claude에게 바로 물어볼 수 있어요.")
                } actions: {
                    Button("PDF 가져오기") { showImporter = true }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("InkAsk")
        .toolbar {
            Button("PDF 가져오기", systemImage: "plus") { showImporter = true }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.pdf]) { result in
            if let src = try? result.get() {
                _ = try? FileStore.importPDF(from: src)
                docs = FileStore.listDocuments()
            }
        }
        .onAppear { docs = FileStore.listDocuments() }
    }
}
