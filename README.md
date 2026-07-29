# InkAsk

개인용 아이패드 앱. PDF에 애플펜슬 필기 → 페이지/영역을 이미지로 복사·공유 → Claude 앱에 붙여넣어 질문.

## 아이패드 설치 방법
1. 아이패드 Swift Playgrounds에서 **새로운 앱(App)** 프로젝트 생성, 이름 InkAsk.
2. 생성된 기본 `MyApp.swift`, `ContentView.swift` 삭제.
3. 이 리포의 `Sources/` 안 .swift 파일 전부를 프로젝트에 추가
   (iCloud Drive로 옮긴 뒤 Playgrounds 좌측 파일 목록에 복사, 또는 파일 새로 만들어 내용 붙여넣기).
4. 실행(▶). 홈 화면 설치는 프로젝트 공유 메뉴의 "App 설치" 사용.

주의: Package.swift는 Playgrounds가 만든 것을 그대로 둘 것.
