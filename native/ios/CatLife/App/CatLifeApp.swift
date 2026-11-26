import SwiftUI

@main
struct CatLifeApp: App {
    @State private var store = DiaryAppStore()

    var body: some Scene {
        WindowGroup {
            DiaryRootView(store: store)
        }
    }
}
