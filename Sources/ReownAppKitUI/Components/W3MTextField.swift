import SwiftUI

public struct W3MTextField: View {
    var titleKey: LocalizedStringKey
    @Binding var text: String

    /// Whether the user is focused on this `TextField`.
    @State var isEditing: Bool = false

    public init(
        _ titleKey: LocalizedStringKey,
        text: Binding<String>
    ) {
        self.titleKey = titleKey
        self._text = text
    }

    public var body: some View {
        TextField(self.titleKey, text: self.$text, onEditingChanged: { self.isEditing = $0 })
            .padding(.horizontal, Spacing.xxl)
            .padding(.vertical, Spacing.xxxxs)
            .backport.overlay(alignment: .leading) {
                Image.Medium.magnifier
                    .foregroundColor(.Foreground275)
            }
            .backport.overlay(alignment: .trailing) {
                if !self.text.isEmpty {
                    Button(action: {
                        self.text = ""
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: Radius.xxxxs)
                                .fill(.GrayGlass020)
                                .frame(width: 18, height: 18)
                                .padding(.vertical, Spacing.xxxs)

                            Image.Medium.xMark
                                .resizable()
                                .frame(width: 10, height: 10)
                                .foregroundColor(.Background250)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                    }
                }
            }
            .foregroundColor(.Foreground100)
            .font(.paragraph500)
            .padding(.vertical, Spacing.xs)
            .padding(.horizontal, Spacing.s)
            .background(
                RoundedRectangle(cornerRadius: Radius.xxs)
                    .fill(self.isEditing ? .GrayGlass010 : .GrayGlass005)
            )
            .background(
                RoundedRectangle(cornerRadius: Radius.xxs)
                    .stroke(.GrayGlass005, lineWidth: 1)
            )
            .backport.background {
                if self.isEditing {
                    ZStack {
                        RoundedRectangle(cornerRadius: Radius.xxs)
                            .fill(Color(red: 0.2, green: 0.59, blue: 1).opacity(0.2))
                        
                        RoundedRectangle(cornerRadius: Radius.xxs)
                            .inset(by: 4)
                            .blendMode(.destinationOut)
                        
                        RoundedRectangle(cornerRadius: Radius.xxs)
                            .inset(by: 4)
                            .stroke(Color.Blue100, lineWidth: 1)
                    }
                    .compositingGroup()
                }
            }
    }
}

struct W3MTextFieldStylePreview: PreviewProvider {
    static var previews: some View {
        VStack {
            W3MTextField("FOoo", text: .constant(""))
        }
        .padding()
    }
}
