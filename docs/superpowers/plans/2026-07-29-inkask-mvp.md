# InkAsk MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 아이패드에서 PDF에 애플펜슬 필기하고, 페이지/선택영역을 이미지로 복사·공유해 Claude 앱에 넘기는 개인용 앱.

**Architecture:** SwiftUI 단일 앱. 화면 2개(문서 목록, 필기 화면). PDFKit으로 페이지를 이미지 렌더 → PencilKit 캔버스를 오버레이 → 내보내기 시 둘을 합성. 필기는 페이지별 PKDrawing 파일로 자동 저장.

**Tech Stack:** Swift 5.9+, SwiftUI, PDFKit, PencilKit, UIKit(내보내기·공유). 외부 의존성 0.

## Global Constraints

- **빌드 환경 없음**: PC(Windows)에선 컴파일 불가. 각 태스크의 검증은 코드 셀프 검토(타입/시그니처 대조)로 대체하고, 실기기 검증은 Task 8에서 일괄 수행한다.
- **Swift Playgrounds 호환**: 외부 패키지 금지, 소스 파일은 모두 단일 앱 타깃에 들어감. `Package.swift`는 아이패드의 Swift Playgrounds가 생성한 것을 그대로 쓴다 (PC에서 작성 금지 — 버전 불일치 방지).
- **캔버스 논리 좌표계**: 폭 `PageExporter.pageWidth = 800` 고정. 모든 필기 좌표·크롭 좌표·합성이 이 좌표계 기준. 이 값을 바꾸면 기존 필기가 어긋난다.
- **저장 레이아웃**: `Documents/<이름>/file.pdf`, `Documents/<이름>/page_<N>.drawing` (스펙 §컴포넌트1).
- 소스 파일 위치: 리포 루트 `Sources/` 아래. 아이패드로 옮길 때 이 폴더의 .swift 파일만 복사한다.
- 커밋 메시지는 한 줄 + Co-Authored-By 트레일러.

---

### Task 1: 프로젝트 골격 + 앱 엔트리

**Files:**
- Create: `Sources/InkAskApp.swift`
- Create: `README.md`

**Interfaces:**
- Produces: `@main InkAskApp` — `NavigationStack { DocumentListView() }`를 띄움. `DocumentListView`는 Task 3에서 정의됨 (그 전까지 컴파일 불가는 정상).

- [ ] **Step 1: 앱 엔트리 작성**

```swift
// Sources/InkAskApp.swift
import SwiftUI

@main
struct InkAskApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                DocumentListView()
            }
        }
    }
}
```

- [ ] **Step 2: README 작성 (아이패드 이관 절차 포함)**

```markdown
# InkAsk

개인용 아이패드 앱. PDF에 애플펜슬 필기 → 페이지/영역을 이미지로 복사·공유 → Claude 앱에 붙여넣어 질문.

## 아이패드 설치 방법
1. 아이패드 Swift Playgrounds에서 **새로운 앱(App)** 프로젝트 생성, 이름 InkAsk.
2. 생성된 기본 `MyApp.swift`, `ContentView.swift` 삭제.
3. 이 리포의 `Sources/` 안 .swift 파일 전부를 프로젝트에 추가
   (iCloud Drive로 옮긴 뒤 Playgrounds 좌측 파일 목록에 복사, 또는 파일 새로 만들어 내용 붙여넣기).
4. 실행(▶). 홈 화면 설치는 프로젝트 공유 메뉴의 "App 설치" 사용.

주의: Package.swift는 Playgrounds가 만든 것을 그대로 둘 것.
```

- [ ] **Step 3: Commit**

```bash
git add Sources/InkAskApp.swift README.md
git commit -m "feat: app entry and iPad install guide"
```

---

### Task 2: FileStore (문서·필기 저장소)

**Files:**
- Create: `Sources/FileStore.swift`

**Interfaces:**
- Produces (이후 태스크가 그대로 호출):
  - `FileStore.importPDF(from: URL) throws -> URL` — 파일앱 URL을 `Documents/<이름>/file.pdf`로 복사, 복사본 URL 반환
  - `FileStore.listDocuments() -> [URL]` — 저장된 file.pdf URL 목록
  - `FileStore.loadDrawing(pdf: URL, page: Int) -> PKDrawing` — 없거나 손상 시 빈 PKDrawing
  - `FileStore.saveDrawing(_: PKDrawing, pdf: URL, page: Int)`
  - `FileStore.delete(pdf: URL)` — 문서 폴더째 삭제

- [ ] **Step 1: FileStore 작성**

```swift
// Sources/FileStore.swift
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

    // 손상/부재 시 빈 캔버스 (스펙 §에러 처리: 조용히 복구)
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
```

- [ ] **Step 2: 셀프 검토** — Interfaces 블록의 시그니처 5개와 코드가 일치하는지 대조. 저장 경로가 Global Constraints의 레이아웃과 일치하는지 확인.

- [ ] **Step 3: Commit**

```bash
git add Sources/FileStore.swift
git commit -m "feat: FileStore for PDF import and per-page drawing persistence"
```

---

### Task 3: DocumentListView (PDF 목록 + 가져오기)

**Files:**
- Create: `Sources/DocumentListView.swift`

**Interfaces:**
- Consumes: `FileStore.importPDF/listDocuments/delete` (Task 2)
- Consumes: `NoteView(pdfURL: URL)` (Task 6에서 정의 — 그 전까지 컴파일 불가는 정상)

- [ ] **Step 1: 목록 화면 작성**

```swift
// Sources/DocumentListView.swift
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
```

- [ ] **Step 2: 셀프 검토** — `ContentUnavailableView`는 iOS 17+. Playgrounds 타깃이 iOS 16이면 `Text("PDF를 가져오세요")`로 교체할 것을 README 주의사항에 기록해두는 대신, 여기서 바로 호환 코드로 갈지 판단: 유지 (사용자 iPad는 최신 iPadOS).

- [ ] **Step 3: Commit**

```bash
git add Sources/DocumentListView.swift
git commit -m "feat: document list with PDF import and delete"
```

---

### Task 4: CanvasView (PencilKit 래퍼)

**Files:**
- Create: `Sources/CanvasView.swift`

**Interfaces:**
- Produces: `CanvasView(drawing: Binding<PKDrawing>, onChanged: @escaping () -> Void)` — 투명 배경 PKCanvasView + PKToolPicker. 스트로크마다 binding 갱신 후 `onChanged()` 호출.

- [ ] **Step 1: 래퍼 작성**

```swift
// Sources/CanvasView.swift
import SwiftUI
import PencilKit

struct CanvasView: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    var onChanged: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawing = drawing
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .anyInput
        canvas.delegate = context.coordinator
        let picker = context.coordinator.picker
        picker.setVisible(true, forFirstResponder: canvas)
        picker.addObserver(canvas)
        canvas.becomeFirstResponder()
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        context.coordinator.parent = self
        if canvas.drawing != drawing { canvas.drawing = drawing }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: CanvasView
        let picker = PKToolPicker()
        init(_ parent: CanvasView) { self.parent = parent }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
            parent.onChanged()
        }
    }
}
```

- [ ] **Step 2: 셀프 검토** — 되먹임 루프 점검: delegate가 binding을 갱신 → updateUIView 재호출 → `canvas.drawing != drawing`이 false라 no-op. OK인지 확인.

- [ ] **Step 3: Commit**

```bash
git add Sources/CanvasView.swift
git commit -m "feat: PencilKit canvas wrapper with tool picker"
```

---

### Task 5: PageExporter (렌더·합성·크롭)

**Files:**
- Create: `Sources/PageExporter.swift`

**Interfaces:**
- Consumes: 없음 (독립 유틸)
- Produces:
  - `PageExporter.pageWidth: CGFloat` — 800 고정
  - `PageExporter.canvasSize(for: PDFPage) -> CGSize` — 폭 800, 페이지 비율 유지
  - `PageExporter.pageImage(_ page: PDFPage, size: CGSize, scale: CGFloat) -> UIImage` — 흰 배경 PDF 렌더
  - `PageExporter.composite(page: PDFPage, drawing: PKDrawing, crop: CGRect?) -> UIImage` — PDF+잉크 합성(2x), crop은 캔버스 좌표계 기준

- [ ] **Step 1: 유틸 작성**

```swift
// Sources/PageExporter.swift
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
```

- [ ] **Step 2: 셀프 검토** — 좌표계 3개(캔버스 논리 800폭 / 픽셀 2x / PDF mediaBox)의 변환이 각 함수에서 일관적인지 손으로 추적. 특히 crop이 논리 좌표 → `*2` 픽셀 변환인지 확인.

- [ ] **Step 3: Commit**

```bash
git add Sources/PageExporter.swift
git commit -m "feat: page render, ink composite, and crop exporter"
```

---

### Task 6: NoteView 코어 (페이지 표시 + 필기 + 이동 + 자동저장)

**Files:**
- Create: `Sources/NoteView.swift`

**Interfaces:**
- Consumes: `FileStore.loadDrawing/saveDrawing` (Task 2), `CanvasView` (Task 4), `PageExporter.canvasSize/pageImage` (Task 5)
- Produces: `NoteView(pdfURL: URL)` (Task 3이 사용). 내보내기 버튼은 Task 7에서 이 파일에 추가.

- [ ] **Step 1: NoteView 작성**

```swift
// Sources/NoteView.swift
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
```

- [ ] **Step 2: 셀프 검토** — 페이지 이동 시 순서: 저장 → 인덱스 변경 → 로드. 회전 시 `fit`만 변하고 캔버스 논리 크기는 불변(필기 유지)인지 확인.

- [ ] **Step 3: Commit**

```bash
git add Sources/NoteView.swift
git commit -m "feat: note view with page nav and autosaving canvas overlay"
```

---

### Task 7: 내보내기 (영역 선택 + 복사 + 공유)

**Files:**
- Modify: `Sources/NoteView.swift` (Task 6에서 작성한 파일에 추가)
- Create: `Sources/ActivityView.swift`

**Interfaces:**
- Consumes: `PageExporter.composite(page:drawing:crop:)` (Task 5)
- Produces: NoteView 툴바에 [영역] [복사] [공유] 버튼

- [ ] **Step 1: 공유 시트 래퍼 작성**

```swift
// Sources/ActivityView.swift
import SwiftUI
import UIKit

struct ShareImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct ActivityView: UIViewControllerRepresentable {
    let image: UIImage
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image], applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
```

- [ ] **Step 2: NoteView에 상태·오버레이·버튼 추가**

NoteView의 `@State` 선언부에 추가:

```swift
    @State private var selecting = false
    @State private var selRect: CGRect?
    @State private var copied = false
    @State private var shareItem: ShareImage?
```

`ZStack` 안, `CanvasView(...)` 다음 줄에 추가:

```swift
                        if selecting {
                            selectionOverlay
                        }
```

`ToolbarItemGroup` 안, 페이지 버튼들 뒤에 추가:

```swift
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
```

`.toolbar { ... }` 뒤에 추가:

```swift
        .sheet(item: $shareItem) { item in
            ActivityView(image: item.image)
        }
```

NoteView 하단(함수들 옆)에 추가 — 드래그 좌표는 ZStack 로컬 좌표 = 캔버스 논리 좌표(800폭)라서 변환 불필요:

```swift
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
```

`loadPage()` 첫 줄에 추가 (페이지 바뀌면 선택 해제):

```swift
        selRect = nil
```

- [ ] **Step 3: 셀프 검토** — 선택 없이 복사/공유 = `selRect`가 nil → 페이지 전체 (스펙 요구). 선택 모드 중엔 오버레이가 캔버스 위에 있어 필기가 막히는 게 의도된 동작인지 확인 (맞음 — 모드 토글).

- [ ] **Step 4: Commit**

```bash
git add Sources/NoteView.swift Sources/ActivityView.swift
git commit -m "feat: region select, copy, and share to Claude via share sheet"
```

---

### Task 8: 아이패드 이관 + 수동 검증 (게이트)

**Files:**
- Modify: `README.md` (검증 체크리스트 추가)

**Interfaces:** 없음 — 사람이 수행하는 검증 태스크.

- [ ] **Step 1: README에 검증 체크리스트 추가**

```markdown
## 검증 체크리스트 (설치 후 순서대로)
1. [ ] PDF 가져오기 → 목록에 표시됨
2. [ ] 필기 → 앱 강제 종료 → 재실행 시 필기 유지됨
3. [ ] 페이지 이동 후 복귀 시 필기 유지됨
4. [ ] 복사 → Claude 앱 붙여넣기에서 원본+필기 모두 보임
5. [ ] 공유 → 공유 시트에 Claude 표시되고 이미지 전달됨
6. [ ] 영역 선택 후 복사 → 선택 영역만(필기 포함) 잘려서 전달됨
7. [ ] 가로/세로 회전 시 필기 위치 유지됨
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: manual verification checklist"
```

- [ ] **Step 3: 사용자 수행** — `Sources/` 파일 6개를 아이패드 Swift Playgrounds 새 App 프로젝트에 복사(README 절차), 빌드, 체크리스트 7항목 수행. 실패 항목은 증상 그대로 보고 → 수정 라운드.

---

## Self-Review 결과

- **스펙 커버리지**: 저장소(T2), 목록/가져오기(T3), 필기(T4·T6), 자동저장(T6), 렌더·합성(T5), 복사·공유·크롭(T7), 수동 검증 6+1항목(T8) — 스펙 전 항목 매핑됨. 스펙의 "assert 셀프체크"는 빌드 환경 부재로 T8 수동 검증으로 대체 (스펙 §테스트 취지 유지).
- **플레이스홀더**: 없음 (모든 코드 전문 수록).
- **타입 일관성**: `FileStore` 5개 시그니처, `CanvasView(drawing:onChanged:)`, `PageExporter` 4개, `NoteView(pdfURL:)`, `ShareImage`/`ActivityView` — 태스크 간 호출부와 정의부 대조 완료.
- **알려진 리스크** (T8에서 확인): ① `scaleEffect` 축소 상태의 펜슬 입력 정밀도 ② PKToolPicker가 Playgrounds 미리보기에서 안 뜰 수 있음(실기기 실행으로 확인) ③ `ContentUnavailableView`는 iOS 17+.
