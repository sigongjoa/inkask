import Foundation
import PencilKit

enum FileStore {
    static var docsDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // Documents/<이름>/file.pdf 로 복사. 이름 충돌 시 " 2", " 3" 붙임.
    static func importPDF(from src: URL) throws -> URL {
        let base = src.deletingPathExtension().lastPathComponent
        var name = base
        var n = 2
        while FileManager.default.fileExists(atPath: docsDir.appendingPathComponent(name).path) {
            name = "\(base) \(n)"
            n += 1
        }
        let folder = docsDir.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let dst = folder.appendingPathComponent("file.pdf")
        let scoped = src.startAccessingSecurityScopedResource()
        defer { if scoped { src.stopAccessingSecurityScopedResource() } }
        try FileManager.default.copyItem(at: src, to: dst)
        return dst
    }

    static func listDocuments() -> [URL] {
        let entries = (try? FileManager.default.contentsOfDirectory(
            at: docsDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        return entries
            .filter { $0.hasDirectoryPath }
            .map { $0.appendingPathComponent("file.pdf") }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    static func drawingURL(pdf: URL, page: Int) -> URL {
        pdf.deletingLastPathComponent().appendingPathComponent("page_\(page).drawing")
    }

    // 손상/부재 시 빈 캔버스 (조용히 복구)
    static func loadDrawing(pdf: URL, page: Int) -> PKDrawing {
        guard let data = try? Data(contentsOf: drawingURL(pdf: pdf, page: page)),
              let drawing = try? PKDrawing(data: data) else { return PKDrawing() }
        return drawing
    }

    static func saveDrawing(_ drawing: PKDrawing, pdf: URL, page: Int) {
        try? drawing.dataRepresentation().write(to: drawingURL(pdf: pdf, page: page))
    }

    static func delete(pdf: URL) {
        try? FileManager.default.removeItem(at: pdf.deletingLastPathComponent())
    }
}
