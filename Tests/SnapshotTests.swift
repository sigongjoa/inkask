import XCTest
import SwiftUI
import PDFKit
import UIKit
@testable import InkAskKit

// 화면을 시뮬레이터에서 실제 렌더해 PNG로 저장. CI가 아티팩트로 업로드한다.
@MainActor
final class SnapshotTests: XCTestCase {

    private var outDir: URL {
        if let p = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"], !p.isEmpty {
            return URL(fileURLWithPath: p)
        }
        return FileManager.default.temporaryDirectory.appendingPathComponent("snapshots")
    }

    // 아이패드 11" 세로 기준. 가로/스플릿뷰는 호출부에서 크기 지정.
    private func save<V: View>(_ view: V, name: String,
                               size: CGSize = CGSize(width: 834, height: 1194)) throws {
        let host = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        // 테스트 호스트의 씬에 붙여야 실제 렌더가 일어남
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            window.windowScene = scene
        }
        window.rootViewController = host
        window.makeKeyAndVisible()
        // onAppear·레이아웃이 돌 시간을 줌
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 1.0))
        window.layoutIfNeeded()
        // drawHierarchy는 오프스크린 윈도우에서 빈 화면을 주므로 CA 레이어 렌더 사용
        let img = UIGraphicsImageRenderer(bounds: window.bounds).image { ctx in
            window.layer.render(in: ctx.cgContext)
        }
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        let file = outDir.appendingPathComponent("\(name).png")
        try XCTUnwrap(img.pngData()).write(to: file)
    }

    func testSnapshotDocumentList() throws {
        try save(NavigationStack { DocumentListView() }, name: "01-document-list")
    }

    private func makeSamplePDF(in folder: URL) throws -> URL {
        let pdfURL = folder.appendingPathComponent("file.pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 400, height: 550))
        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            ("InkAsk 스냅샷 페이지" as NSString).draw(
                at: CGPoint(x: 40, y: 60),
                withAttributes: [.font: UIFont.systemFont(ofSize: 24)])
            UIColor.black.setStroke()
            UIBezierPath(ovalIn: CGRect(x: 120, y: 180, width: 160, height: 160)).stroke()
        }
        try data.write(to: pdfURL)
        return pdfURL
    }

    // 아이패드 3가지 상황: 세로 / 가로 / Claude와 스플릿뷰(절반 폭)
    func testSnapshotNoteView() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("snap-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let pdfURL = try makeSamplePDF(in: folder)

        try save(NavigationStack { NoteView(pdfURL: pdfURL) },
                 name: "02-note-portrait")
        try save(NavigationStack { NoteView(pdfURL: pdfURL) },
                 name: "03-note-landscape", size: CGSize(width: 1194, height: 834))
        try save(NavigationStack { NoteView(pdfURL: pdfURL) },
                 name: "04-note-splitview", size: CGSize(width: 507, height: 834))
    }
}
