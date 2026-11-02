import SwiftUI

@main
struct CatLifeApp: App {
    @State private var store = GameStore()

    var body: some Scene {
        WindowGroup {
            RoomHomeView(store: store)
        }
    }
}
