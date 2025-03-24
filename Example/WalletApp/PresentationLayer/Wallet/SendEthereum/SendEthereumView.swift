import SwiftUI

struct SendEthereumView: View {
    @EnvironmentObject var presenter: SendEthereumPresenter
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            // Top bar with title and close button
            HStack {
                Text("Send ETH")
                    .font(.headline)
                    .padding(.leading)
                
                Spacer()
                
                closeButton
                    .padding(.trailing)
            }
            .padding(.top)
            
            Form {
                addressSection
                balanceSection
                recipientSection
                amountSection
                networkSection
            }
            
            // Button moved outside the Form to avoid border styling
            Button(action: {
                Task {
                    do {
                        try await presenter.send()
                    } catch {
                        print("Error sending ETH: \(error)")
                    }
                }
            }) {
                Text("Send")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
    
    private var closeButton: some View {
        Button(action: { dismiss() }) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.primary)
        }
    }
    
    private var addressSection: some View {
        Section(header: Text("MY ADDRESS")) {
            VStack(alignment: .leading, spacing: 4) {
                Text(presenter.importAccount.account.address)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
    }
    
    private var balanceSection: some View {
        Section(header: Text("BALANCE")) {
            HStack {
                Text("ETH Balance")
                Spacer()
                Text("\(presenter.ethBalance) ETH")
                    .fontWeight(.semibold)
            }
        }
    }
    
    private var recipientSection: some View {
        Section(header: Text("RECIPIENT")) {
            TextField("ETH Address", text: $presenter.recipient)
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
        }
    }
    
    private var networkSection: some View {
        Section(header: Text("NETWORK")) {
            Picker("Network", selection: $presenter.selectedNetwork) {
                let supportedNetworks: [Chain] = [.Arbitrium, .Base, .Optimism]
                ForEach(supportedNetworks, id: \.self) { network in
                    Text(network.rawValue).tag(network)
                }
            }
            .pickerStyle(MenuPickerStyle())
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
