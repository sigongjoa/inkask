import XCTest
import PDFKit
import PencilKit
import UIKit
@testable import InkAskKit

final class InkAskTests: XCTestCase {

    // 200x100pt 단색 PDF 페이지 생성
    private func makePage() -> PDFPage {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 200, height: 100))
        let data = renderer.pdfData { ctx in ctx.beginPage() }
        return PDFDocument(data: data)!.page(at: 0)!
    }

    // 스트로크 1개짜리 필기 생성
    private func makeDrawing() -> PKDrawing {
        let points = [CGPoint(x: 10, y: 10), CGPoint(x: 50, y: 50)].map {
            PKStrokePoint(location: $0, timeOffset: 0, size: CGSize(width: 3, height: 3),
                          opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        let path = PKStrokePath(controlPoints: points, creationDate: Date())
        return PKDrawing(strokes: [PKStroke(ink: PKInk(.pen, color: .red), path: path)])
    }

    // UC-2/5: 필기 저장 → 로드 왕복
    func testDrawingSaveLoadRoundtrip() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("inkask-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let pdf = folder.appendingPathComponent("file.pdf")

        FileStore.saveDrawing(makeDrawing(), pdf: pdf, page: 3)
        let loaded = FileStore.loadDrawing(pdf: pdf, page: 3)
        XCTAssertEqual(loaded.strokes.count, 1)

        // 없는 페이지는 조용히 빈 캔버스
        XCTAssertEqual(FileStore.loadDrawing(pdf: pdf, page: 99).strokes.count, 0)
    }

    // UC-1: 같은 이름 두 번 가져오면 " 2" 접미사
    func testImportCollisionNaming() throws {
        let src = FileManager.default.temporaryDirectory
            .appendingPathComponent("교재-\(UUID().uuidString.prefix(6)).pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 10, height: 10))
        try renderer.pdfData { ctx in ctx.beginPage() }.write(to: src)
        defer { try? FileManager.default.removeItem(at: src) }

        let first = try FileStore.importPDF(from: src)
        let second = try FileStore.importPDF(from: src)
        defer {
            FileStore.delete(pdf: first)
            FileStore.delete(pdf: second)
        }
        let firstName = first.deletingLastPathComponent().lastPathComponent
        let secondName = second.deletingLastPathComponent().lastPathComponent
        XCTAssertNotEqual(firstName, secondName)
        XCTAssertTrue(secondName.hasSuffix(" 2"))
        XCTAssertTrue(FileStore.listDocuments().contains(first))
    }

    // 캔버스 좌표계: 폭 800 고정, 비율 유지
    func testCanvasSizeAspect() {
        let size = PageExporter.canvasSize(for: makePage())
        XCTAssertEqual(size.width, 800)
        XCTAssertEqual(size.height, 400)  // 200x100 → 2:1 비율
    }

    // UC-4: 전체 합성 이미지는 캔버스의 2배 픽셀
    func testCompositeFullSize() {
        let img = PageExporter.composite(page: makePage(), drawing: makeDrawing(), crop: nil)
        XCTAssertEqual(img.cgImage?.width, 1600)
        XCTAssertEqual(img.cgImage?.height, 800)
    }

    // UC-3: 크롭하면 선택 영역만 (논리 좌표 → 2배 픽셀)
    func testCompositeCrop() {
        let crop = CGRect(x: 0, y: 0, width: 100, height: 50)
        let img = PageExporter.composite(page: makePage(), drawing: PKDrawing(), crop: crop)
        XCTAssertEqual(img.cgImage?.width, 200)
        XCTAssertEqual(img.cgImage?.height, 100)
    }
}
