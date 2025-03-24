import SwiftUI

struct SendEthereumView: View {
    @EnvironmentObject var presenter: SendEthereumPresenter
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                balanceSection
                recipientSection
                amountSection
                networkSection
                sendButton
            }
            .navigationTitle("Send ETH")
            .navigationBarItems(trailing: closeButton)
        }
    }
    
    private var closeButton: some View {
        Button(action: { dismiss() }) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.primary)
        }
    }
    
    private var balanceSection: some View {
        Section(header: Text("BALANCE")) {
            HStack {
                Text("Your ETH Balance")
                Spacer()
                Text("\(presenter.ethBalance) ETH")
                    .fontWeight(.semibold)
            }
        }
    }
    
    private var recipientSection: some View {
        Section(header: Text("RECIPIENT")) {
            TextField("ETH Address or ENS", text: $presenter.recipient)
                .autocapitalization(.none)
                .autocorrectionDisabled()
        }
    }
    
    private var amountSection: some View {
        Section(header: Text("AMOUNT")) {
            HStack {
                TextField("0.00", text: $presenter.amount)
                    .keyboardType(.decimalPad)
                
                Spacer()
                
                Text("ETH")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Spacer()
                Button("MAX") {
                    presenter.amount = presenter.ethBalance
                }
                .font(.caption)
                .foregroundColor(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color.blue, lineWidth: 1)
                )
            }
        }
    }
    
    private var networkSection: some View {
        Section(header: Text("NETWORK")) {
            Picker("Network", selection: $presenter.selectedNetwork) {
                ForEach(L2.allCases, id: \.self) { network in
                    Text(network.rawValue).tag(network)
                }
            }
            .pickerStyle(MenuPickerStyle())
        }
    }
    
    private var sendButton: some View {
        Section {
            Button(action: {
                Task {
                    do {
                        try await presenter.send()
                    } catch {
                        print("Error sending ETH: \(error)")
                    }
                }
            }) {
                Text("Send ETH")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.blue100,
                                Color.blue200
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

#if DEBUG
struct SendEthereumView_Previews: PreviewProvider {
    static var previews: some View {
        SendEthereumView()
    }
}
#endif 