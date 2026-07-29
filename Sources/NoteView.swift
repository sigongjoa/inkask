import SwiftUI
import PDFKit
import PencilKit

struct NoteView: View {
    let pdfURL: URL
    @State private var doc: PDFDocument?
    @State private var pageIndex = 0
    @State private var drawing = PKDrawing()
    @State private var pageImage: UIImage?

    private var page: PDFPage? { doc?.page(at: pageIndex) }
    private var pageCount: Int { doc?.pageCount ?? 0 }

    var body: some View {
        Group {
            if let page, let img = pageImage {
                let size = PageExporter.canvasSize(for: page)
                GeometryReader { geo in
                    let fit = min(geo.size.width / size.width, geo.size.height / size.height)
                    ZStack {
                        Image(uiImage: img).resizable()
                        CanvasView(drawing: $drawing) {
                            FileStore.saveDrawing(drawing, pdf: pdfURL, page: pageIndex)
                        }
                    }
                    .frame(width: size.width, height: size.height)
                    .scaleEffect(fit, anchor: .topLeading)
                    .frame(width: size.width * fit, height: size.height * fit, alignment: .topLeading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            } else {
                Text("PDF를 열 수 없습니다")
            }
        }
        .navigationTitle("\(pageIndex + 1) / \(pageCount)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("이전 페이지", systemImage: "chevron.left") { go(-1) }
                    .disabled(pageIndex <= 0)
                Button("다음 페이지", systemImage: "chevron.right") { go(1) }
                    .disabled(pageIndex >= pageCount - 1)
            }
        }
        .onAppear {
            doc = PDFDocument(url: pdfURL)
            loadPage()
        }
        .onDisappear {
            FileStore.saveDrawing(drawing, pdf: pdfURL, page: pageIndex)
        }
    }

    private func loadPage() {
        guard let page else { pageImage = nil; return }
        drawing = FileStore.loadDrawing(pdf: pdfURL, page: pageIndex)
        let size = PageExporter.canvasSize(for: page)
        pageImage = PageExporter.pageImage(page, size: size, scale: 2)
    }

    private func go(_ delta: Int) {
        FileStore.saveDrawing(drawing, pdf: pdfURL, page: pageIndex)
        pageIndex = max(0, min(pageCount - 1, pageIndex + delta))
        loadPage()
    }
}
