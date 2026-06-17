import SwiftUI

struct ImportWalletView: View {
    @EnvironmentObject var viewModel: ImportWalletPresenter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundPrimary
                    .edgesIgnoringSafeArea(.all)

                VStack(spacing: Spacing._5) {
                    chainPicker()
                    inputField()
                    errorLabel()
                    Spacer()
                    actionButtons()
                }
                .padding(.horizontal, Spacing._5)
                .padding(.top, Spacing._5)
                .padding(.bottom, Spacing._6)
            }
            .navigationTitle("Import Wallet")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert("Wallet imported successfully", isPresented: $viewModel.showSuccess) {
            Button("OK") { dismiss() }
        }
    }

    private func chainPicker() -> some View {
        Picker("Chain", selection: $viewModel.selectedChain) {
            ForEach(ImportChain.allCases) { chain in
                Text(chain.rawValue).tag(chain)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: viewModel.selectedChain) { _ in
            viewModel.input = ""
            viewModel.errorMessage = nil
        }
    }

    private func inputField() -> some View {
        ZStack(alignment: .topLeading) {
            if viewModel.input.isEmpty {
                Text(viewModel.selectedChain.placeholder)
                    .appFont(.md)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, Spacing._3)
                    .padding(.vertical, Spacing._3)
            }

            TextEditor(text: $viewModel.input)
                .appFont(.md)
                .foregroundColor(AppColors.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 100)
                .padding(.horizontal, Spacing._05)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
        }
        .background(AppColors.foregroundPrimary)
        .cornerRadius(AppRadius._3)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius._3)
                .stroke(AppColors.borderSecondary, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func errorLabel() -> some View {
        if let error = viewModel.errorMessage {
            Text(error)
                .appFont(.md)
                .foregroundColor(AppColors.textError)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func actionButtons() -> some View {
        HStack(spacing: Spacing._3) {
            Button {
                dismiss()
            } label: {
                Text("Cancel")
                    .appFont(.lg, weight: .medium)
                    .foregroundColor(AppColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
            .overlay(
                RoundedRectangle(cornerRadius: CGFloat(AppRadius._3))
                    .stroke(AppColors.borderSecondary, lineWidth: 1)
            )

            Button {
                viewModel.importWallet()
            } label: {
                Text(viewModel.isImporting ? "Importing..." : "Import")
                    .appFont(.lg, weight: .medium)
                    .foregroundColor(AppColors.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(viewModel.canImport ? AppColors.backgroundAccentPrimary : AppColors.foregroundTertiary)
                    .cornerRadius(CGFloat(AppRadius._3))
            }
            .disabled(!viewModel.canImport)
        }
    }
}
