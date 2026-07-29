import SwiftUI
import UIKit
import PDFKit
import PencilKit

struct NoteView: View {
    let pdfURL: URL
    @State private var doc: PDFDocument?
    @State private var pageIndex = 0
    @State private var drawing = PKDrawing()
    @State private var pageImage: UIImage?
    @State private var selecting = false
    @State private var selRect: CGRect?
    @State private var copied = false
    @State private var shareItem: ShareImage?

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
                        if selecting {
                            selectionOverlay
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
                Button("영역 선택", systemImage: selecting ? "rectangle.dashed.badge.record" : "rectangle.dashed") {
                    selecting.toggle()
                    if !selecting { selRect = nil }
                }
                Button("복사", systemImage: copied ? "checkmark" : "doc.on.doc") {
                    guard let page else { return }
                    UIPasteboard.general.image =
                        PageExporter.composite(page: page, drawing: drawing, crop: selRect)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                }
                Button("공유", systemImage: "square.and.arrow.up") {
                    guard let page else { return }
                    shareItem = ShareImage(image:
                        PageExporter.composite(page: page, drawing: drawing, crop: selRect))
                }
            }
        }
        .sheet(item: $shareItem) { item in
            ActivityView(image: item.image)
        }
        .onAppear {
            doc = PDFDocument(url: pdfURL)
            loadPage()
        }
        .onDisappear {
            FileStore.saveDrawing(drawing, pdf: pdfURL, page: pageIndex)
        }
    }

    private var selectionOverlay: some View {
        ZStack {
            Color.black.opacity(0.001)  // 드래그 입력을 받기 위한 히트 영역
            if let r = selRect {
                Rectangle()
                    .stroke(Color.blue, lineWidth: 2)
                    .background(Color.blue.opacity(0.1))
                    .frame(width: r.width, height: r.height)
                    .position(x: r.midX, y: r.midY)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { v in
                    let a = v.startLocation
                    let b = v.location
                    selRect = CGRect(x: min(a.x, b.x), y: min(a.y, b.y),
                                     width: abs(a.x - b.x), height: abs(a.y - b.y))
                }
        )
    }

    private func loadPage() {
        selRect = nil
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
