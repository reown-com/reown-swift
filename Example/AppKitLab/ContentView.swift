import SwiftUI
import Web3Modal

struct ContentView: View {
    @State var showUIComponents: Bool = false
    @EnvironmentObject var socketConnectionManager: SocketConnectionManager


    var body: some View {
        NavigationView {
            VStack {
                Spacer()
                
                Web3ModalButton()
                
                Web3ModalNetworkButton()
                
                Spacer()

                Button("Personal sign") {
                    Task {
                        do {
                            try await requestPersonalSign()
                            Web3Modal.instance.launchCurrentWallet()
                        } catch {
                            print("Error occurred: \(error)")
                        }
                    }
                }
                .buttonStyle(W3MButtonStyle())

                NavigationLink(destination: ComponentLibraryView(), isActive: $showUIComponents) {
                    Button("UI components") {
                        showUIComponents = true
                    }
                    .buttonStyle(W3MButtonStyle())
                }
            }
            .overlay(
                HStack {
                    Circle()
                        .fill(socketConnectionManager.socketConnected ? Color.Success100 : Color.Error100)
                        .frame(width: 10, height: 10)

                    Text("Socket \(socketConnectionManager.socketConnected ? "Connected" : "Disconnected")")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(socketConnectionManager.socketConnected ? Color.Success100 : Color.Error100)
                },
                alignment: .top
            )
        }
    }
    
    func requestPersonalSign() async throws {

        guard let address = Web3Modal.instance.getAddress() else { return }
        try await Web3Modal.instance.request(.personal_sign(address: address, message: "Hello there!"))

    }
}
