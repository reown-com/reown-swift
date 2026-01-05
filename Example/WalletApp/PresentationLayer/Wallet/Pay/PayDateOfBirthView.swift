import SwiftUI

struct PayDateOfBirthView: View {
    @EnvironmentObject var presenter: PayPresenter
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button, progress, and close
            HStack {
                Button(action: {
                    presenter.goBack()
                }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.grey8)
                }
                
                Spacer()
                
                // Progress indicator (step 2 of 2)
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue100)
                        .frame(width: 24, height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue100)
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
            
            // Title
            Text("What's your date of birth?")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(.grey8)
                .padding(.top, 24)
            
            // Date picker wheel
            DatePicker(
                "",
                selection: $presenter.dateOfBirth,
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(height: 200)
            .padding(.top, 16)
            
            Spacer()
                .frame(minHeight: 20, maxHeight: 40)
            
            // Continue button
            Button(action: {
                presenter.submitDateOfBirth()
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
                    gradient: Gradient(colors: [.blue100, .blue200]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(16)
            .disabled(presenter.isLoading)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .background(Color.whiteBackground)
        .cornerRadius(34)
        .padding(.horizontal, 10)
    }
}

#if DEBUG
struct PayDateOfBirthView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.opacity(0.6)
            PayDateOfBirthView()
        }
    }
}
#endif
