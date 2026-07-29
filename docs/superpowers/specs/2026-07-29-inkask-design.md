# InkAsk — 개인용 PDF 필기 → Claude 전달 앱 (설계 스펙)

날짜: 2026-07-29 | 상태: 사용자 검토 대기 | 용도: 개인용 (판매 안 함)

## 목적

아이패드에서 학습용 PDF에 애플펜슬로 필기하고, 현재 페이지(원본+필기 합성 이미지)를
한 번의 탭으로 Claude 앱에 넘겨 질문한다. 서버·MCP·계정 없음.

## 확정된 결정

| 항목 | 결정 | 근거 |
|---|---|---|
| 개발 환경 | 아이패드 Swift Playgrounds (.swiftpm 앱 프로젝트) | Mac 없음. 개인 설치는 개발자 계정 불필요 |
| 코드 전달 | PC에서 작성 → iCloud Drive/복붙으로 아이패드에 이동, 빌드는 아이패드에서 | Windows에선 빌드 불가 |
| AI 전달 | ① 클립보드 복사 ② iOS 공유 시트 (Claude "Ask Claude" 공유 대상 공식 지원, 이미지 가능) | 서버 0원, 조사로 확인됨 |
| 전달 형태 | 페이지 이미지 (PDF 렌더 + 잉크 합성) | Claude 비전이 직접 읽음. OCR 불필요 |
| 제외 | MCP 서버, 온디바이스 sLLM/SFT, OCR, 노트북 관리, 도형/텍스트 도구, 온보딩 | YAGNI — 개인용 MVP |

## 아키텍처

SwiftUI 앱 하나. 화면 2개.

```
DocumentListView (PDF 목록)
  └─ fileImporter로 파일 앱에서 PDF 가져오기 → Documents/에 복사
  └─ 탭하면 NoteView로 이동

NoteView (필기 화면)
  └─ 페이지 이미지 (PDFKit으로 렌더) 위에 PKCanvasView 오버레이
  └─ 페이지 넘기기 (이전/다음), PKToolPicker (펜/형광펜/지우개)
  └─ 툴바 버튼: [복사] [공유]
```

## 컴포넌트

**1. 저장소 (FileStore)**
- `Documents/<pdf파일명>/file.pdf` — 원본 복사본
- `Documents/<pdf파일명>/page_<N>.drawing` — 페이지별 `PKDrawing` 직렬화 데이터
- 필기는 펜을 뗄 때마다(`canvasViewDrawingDidChange`) 저장. 별도 저장 버튼 없음.

**2. 필기 화면 (NoteView)**
- PDFKit `PDFPage`를 `UIGraphicsImageRenderer`로 화면 폭에 맞춰 이미지 렌더
- 그 위에 투명 `PKCanvasView`. 페이지 이동 시 현재 drawing 저장 → 다음 페이지 drawing 로드
- 줌: MVP는 화면 폭 맞춤 고정. (ponytail: 줌 없음 — 불편하면 PKCanvasView의 내장 스크롤뷰 줌으로 업그레이드)

**3. 내보내기 (PageExporter)**
- 페이지 이미지 위에 `PKDrawing.image(from:scale:)` 합성 → `UIImage`
- 복사: `UIPasteboard.general.image`
- 공유: `ShareLink` → 공유 시트에서 Claude 선택

## 에러 처리

- PDF 열기 실패 / drawing 파일 손상 → 해당 페이지 빈 캔버스로 시작 (데이터는 덮어쓰기 전까지 보존)
- 개인용이므로 알림창 최소화, 조용히 복구가 기본

## 테스트

- 시뮬레이터/자동 테스트 불가 (빌드 환경이 아이패드). 검증은 수동 체크리스트:
  1. PDF 가져오기 → 목록에 표시
  2. 필기 → 앱 강제 종료 → 재실행 시 필기 유지
  3. 페이지 이동 후 복귀 시 필기 유지
  4. 복사 → Claude 앱 붙여넣기에서 원본+필기 모두 보임
  5. 공유 → Claude 대상 표시되고 이미지 전달됨
- 순수 로직(경로 생성, 파일명 안전화)은 코드 내 `assert` 셀프체크로 커버

## 알려진 제약

- Swift Playgrounds 개인 설치 앱은 서명 갱신 없이 장기간 사용 가능하나, Playgrounds 버전에 따라 재빌드가 필요할 수 있음
- 대용량 PDF(수백 페이지)는 페이지 단위 렌더라 문제 없으나, 첫 렌더가 페이지당 ~수백 ms
- 가로/세로 회전 시 필기 좌표는 페이지 기준이므로 유지됨 (렌더 폭만 변경)
