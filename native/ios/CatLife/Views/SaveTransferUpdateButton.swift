import SwiftUI

struct SaveTransferUpdateButton: View {
    @Environment(\.openURL) private var openURL
    @State private var cannotOpen = false

    var body: some View {
        Button {
            openURL(URL(string: "itms-beta://")!) { accepted in cannotOpen = !accepted }
        } label: {
            Label(GameStrings.text("saveTransfer.updateTestFlight"), systemImage: "arrow.down.app.fill")
                .font(.headline).frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .foregroundStyle(.white)
                .background(RoomTheme.gold, in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.4), lineWidth: 2))
        }
        .buttonStyle(.plain)
        .alert(GameStrings.text("saveTransfer.updateUnavailable"), isPresented: $cannotOpen) {
            Button(GameStrings.text("saveTransfer.updateHelp")) {
                openURL(URL(string: "https://testflight.apple.com/")!)
            }
            Button(GameStrings.text("common.close"), role: .cancel) {}
        } message: {
            Text(GameStrings.text("saveTransfer.updateManual"))
        }
    }
}
