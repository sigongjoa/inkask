import UIKit
import PDFKit
import PencilKit

enum PageExporter {
    // 캔버스 논리 좌표계 폭. 변경하면 기존 필기 좌표가 어긋남.
    static let pageWidth: CGFloat = 800

    static func canvasSize(for page: PDFPage) -> CGSize {
        let b = page.bounds(for: .mediaBox)
        return CGSize(width: pageWidth, height: b.height * pageWidth / max(b.width, 1))
    }

    private static func renderer(_ px: CGSize) -> UIGraphicsImageRenderer {
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1  // 픽셀 크기를 직접 제어 (크롭 좌표 계산 단순화)
        return UIGraphicsImageRenderer(size: px, format: fmt)
    }

    static func pageImage(_ page: PDFPage, size: CGSize, scale: CGFloat) -> UIImage {
        let px = CGSize(width: size.width * scale, height: size.height * scale)
        let b = page.bounds(for: .mediaBox)
        return renderer(px).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: px))
            ctx.cgContext.translateBy(x: 0, y: px.height)
            ctx.cgContext.scaleBy(x: px.width / max(b.width, 1), y: -px.height / max(b.height, 1))
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
    }

    static func composite(page: PDFPage, drawing: PKDrawing, crop: CGRect?) -> UIImage {
        let size = canvasSize(for: page)
        let scale: CGFloat = 2
        let px = CGSize(width: size.width * scale, height: size.height * scale)
        let base = pageImage(page, size: size, scale: scale)
        let ink = drawing.image(from: CGRect(origin: .zero, size: size), scale: scale)
        var img = renderer(px).image { _ in
            base.draw(in: CGRect(origin: .zero, size: px))
            ink.draw(in: CGRect(origin: .zero, size: px))
        }
        if let crop {
            let pxCrop = CGRect(x: crop.origin.x * scale, y: crop.origin.y * scale,
                                width: crop.width * scale, height: crop.height * scale)
            if let cg = img.cgImage?.cropping(to: pxCrop) {
                img = UIImage(cgImage: cg)
            }
        }
        return img
    }
}
