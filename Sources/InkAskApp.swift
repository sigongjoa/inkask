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
