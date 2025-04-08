import SwiftUI
import AsyncButton


struct SendEthereumView: View {
    @EnvironmentObject var presenter: SendEthereumPresenter
    @Environment(\.dismiss) var dismiss
    
    @State private var showNetworkPicker = false
    @FocusState private var amountFieldIsFocused: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            // My Address section
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("My Address")
                            .foregroundColor(.gray)
                        Text(presenter.importAccount.account.address)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color("grey-section"))
            .cornerRadius(12)
            
            // Balance section
            VStack(spacing: 8) {
                HStack {
                    Text("ETH Balance")
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(presenter.ethBalance) ETH")
                            .fontWeight(.semibold)
                        Text(presenter.ethDollarValue)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color("grey-section"))
            .cornerRadius(12)
            
            // Transaction card
            VStack(spacing: 20) {
                Text("Transaction")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Recipient
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recipient")
                        .foregroundColor(.gray)
                    TextField("0x1234... or ENS", text: $presenter.recipient)
                        .textFieldStyle(.roundedBorder)
                        .disableAutocorrection(true)
                        .autocapitalization(.none)
                }
                
                // Amount + network
                VStack(alignment: .leading, spacing: 8) {
                    Text("Amount to send")
                        .foregroundColor(.gray)
                    
                    HStack {
                        TextField("0.00", text: $presenter.amount)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .focused($amountFieldIsFocused)
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    Spacer()
                                    Button("Done") {
                                        amountFieldIsFocused = false
                                    }
                                }
                            }
                        
                        Button {
                            showNetworkPicker = true
                        } label: {
                            Text(presenter.selectedNetwork.rawValue)
                                .foregroundColor(.blue)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        .confirmationDialog(
                            "Select Network",
                            isPresented: $showNetworkPicker,
                            titleVisibility: .visible
                        ) {
                            Button(Chain.Arbitrium.rawValue) {
                                presenter.selectedNetwork = .Arbitrium
                            }
                            Button(Chain.Base.rawValue) {
                                presenter.selectedNetwork = .Base
                            }
                            Button(Chain.Optimism.rawValue) {
                                presenter.selectedNetwork = .Optimism
                            }
                            Button("Cancel", role: .cancel) {}
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color("grey-section"))
            .cornerRadius(12)
            
            Spacer()
            
            // Send button
            VStack(spacing: 12) {
                AsyncButton(
                    options: [
                        .showProgressViewOnLoading,
                        .disableButtonOnLoading,
                        .showAlertOnError,
                        .enableNotificationFeedback
                    ]
                ) {
                    try await presenter.send()
                } label: {
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
            }
            .padding()
        }
        .padding()
        .hideKeyboardOnTap()
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
    }
}

#if DEBUG
struct SendEthereumView_Previews: PreviewProvider {
    static var previews: some View {
        SendEthereumView()
    }
}
#endif 
