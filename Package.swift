// swift-tools-version: 5.9
// CI 컴파일 체크 전용. 아이패드 Swift Playgrounds에는 이 파일을 복사하지 말 것 (README 참조).
import PackageDescription

let package = Package(
    name: "InkAskKit",
    platforms: [.iOS(.v17)],
    products: [.library(name: "InkAskKit", targets: ["InkAskKit"])],
    targets: [
        // @main 앱 엔트리는 라이브러리 타깃에서 컴파일 불가라 제외 (12줄짜리 보일러플레이트)
        .target(name: "InkAskKit", path: "Sources", exclude: ["InkAskApp.swift"])
    ]
)
