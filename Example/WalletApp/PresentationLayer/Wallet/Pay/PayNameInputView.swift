import SwiftUI

struct PayNameInputView: View {
    @EnvironmentObject var presenter: PayPresenter
    @FocusState private var focusedField: NameField?
    
    enum NameField: Hashable {
        case firstName
        case lastName
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button and close
            HStack {
                Button(action: {
                    presenter.goBack()
                }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.grey8)
                }
                
                Spacer()
                
                // Progress indicator
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue100)
                        .frame(width: 24, height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.grey95)
                        .frame(width: 24, height: 4)
                }
                
                Spacer()
                
                Button(action: {
                    presenter.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.grey50)
                        .frame(width: 30, height: 30)
                        .background(Color.grey95.opacity(0.5))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            // Avatar placeholder
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [.orange, .orange.opacity(0.7)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 56, height: 56)
                .overlay(
                    Text(initials)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                )
                .padding(.top, 24)
            
            // Title
            Text("What's your name?")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(.grey8)
                .padding(.top, 16)
            
            // Input fields
            VStack(spacing: 12) {
                // First name field
                TextField("First name", text: $presenter.userInfo.firstName)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.grey95.opacity(0.3))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(focusedField == .firstName ? Color.blue100 : Color.clear, lineWidth: 2)
                    )
                    .focused($focusedField, equals: .firstName)
                
                // Last name field
                TextField("Last name", text: $presenter.userInfo.lastName)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.grey95.opacity(0.3))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(focusedField == .lastName ? Color.blue100 : Color.clear, lineWidth: 2)
                    )
                    .focused($focusedField, equals: .lastName)
            }
            .padding(.top, 24)
            
            Spacer()
                .frame(minHeight: 20, maxHeight: 60)
            
            // Continue button
            Button(action: {
                presenter.submitUserInfo()
            }) {
                if presenter.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                } else {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .padding(.vertical, 16)
                }
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: isFormValid ? [.blue100, .blue200] : [.grey95, .grey95]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(16)
            .disabled(!isFormValid || presenter.isLoading)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .background(Color.whiteBackground)
        .cornerRadius(34)
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
        .onAppear {
            focusedField = .firstName
        }
    }
    
    private var isFormValid: Bool {
        !presenter.userInfo.firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !presenter.userInfo.lastName.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    private var initials: String {
        let first = presenter.userInfo.firstName.first.map(String.init) ?? ""
        let last = presenter.userInfo.lastName.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }
}

#if DEBUG
struct PayNameInputView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.opacity(0.6)
            PayNameInputView()
        }
    }
}
#endif
