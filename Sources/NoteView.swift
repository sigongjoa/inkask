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
    @State private var askImage: ShareImage?

    private var page: PDFPage? { doc?.page(at: pageIndex) }
    private var pageCount: Int { doc?.pageCount ?? 0 }
    private var docName: String { pdfURL.deletingLastPathComponent().lastPathComponent }

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
                    .overlay(alignment: .top) {
                        if selecting && selRect == nil {
                            Text("자를 영역을 드래그하세요")
                                .font(.footnote.weight(.semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(.regularMaterial, in: Capsule())
                                .padding(.top, 20)
                        }
                    }
                }
                .background(Color.white.ignoresSafeArea())
            } else {
                ContentUnavailableView("PDF를 열 수 없습니다", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle(docName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Text("\(pageIndex + 1)/\(pageCount)")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
                Button("이전 페이지", systemImage: "chevron.left") { go(-1) }
                    .disabled(pageIndex <= 0)
                    .keyboardShortcut(.leftArrow, modifiers: [])
                Button("다음 페이지", systemImage: "chevron.right") { go(1) }
                    .disabled(pageIndex >= pageCount - 1)
                    .keyboardShortcut(.rightArrow, modifiers: [])
                Button("영역 선택", systemImage: "rectangle.dashed") {
                    selecting.toggle()
                    if !selecting { selRect = nil }
                }
                .background(selecting ? Color.blue.opacity(0.15) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 6))
                .keyboardShortcut("e", modifiers: [])
                Button("Claude에 묻기", systemImage: "sparkles") { ask() }
                    .keyboardShortcut("c", modifiers: [.command])
            }
        }
        .sheet(item: $askImage) { item in
            AskSheet(image: item.image)
                .presentationDetents([.medium, .large])
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
                    .strokeBorder(Color.blue, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .background(Color.blue.opacity(0.06))
                    .frame(width: r.width, height: r.height)
                    .position(x: r.midX, y: r.midY)
                let corners = [CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY),
                               CGPoint(x: r.minX, y: r.maxY), CGPoint(x: r.maxX, y: r.maxY)]
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(Color.white)
                        .overlay(Circle().stroke(Color.blue, lineWidth: 2))
                        .frame(width: 10, height: 10)
                        .position(corners[i])
                }
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

    private func ask() {
        guard let page else { return }
        askImage = ShareImage(image:
            PageExporter.composite(page: page, drawing: drawing, crop: selRect))
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
