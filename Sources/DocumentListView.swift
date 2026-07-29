import SwiftUI

struct DocumentListView: View {
    @State private var docs: [URL] = []
    @State private var showImporter = false

    var body: some View {
        List {
            ForEach(docs, id: \.self) { pdf in
                NavigationLink(pdf.deletingLastPathComponent().lastPathComponent) {
                    NoteView(pdfURL: pdf)
                }
            }
            .onDelete { indexSet in
                indexSet.map { docs[$0] }.forEach { FileStore.delete(pdf: $0) }
                docs = FileStore.listDocuments()
            }
        }
        .overlay {
            if docs.isEmpty {
                ContentUnavailableView("PDF를 가져오세요", systemImage: "doc.badge.plus")
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
