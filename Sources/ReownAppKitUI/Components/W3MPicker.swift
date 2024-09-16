import SwiftUI

public struct W3MPicker<Data, Content>: View where Data: Hashable, Content: View {
    let sources: [Data]
    let selection: Data?
    let itemBuilder: (Data) -> Content
    
    private var customIndicator: AnyView?
    
    public init(
        _ sources: [Data],
        selection: Data?,
        @ViewBuilder itemBuilder: @escaping (Data) -> Content
    ) {
        self.sources = sources
        self.selection = selection
        self.itemBuilder = itemBuilder
    }
    
    public var body: some View {
        ZStack(alignment: .center) {
            if let selection = selection, let selectedIdx = sources.firstIndex(of: selection) {
                
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: Radius.s)
                        .fill(.GrayGlass002, strokeBorder: .GrayGlass002, lineWidth: 1)
                        .frame(width: geo.size.width / CGFloat(sources.count))
                        .animation(.spring().speed(1.5), value: selection)
                        .offset(x: geo.size.width / CGFloat(sources.count) * CGFloat(selectedIdx), y: 0)
                }.frame(height: 28)
            }
            
            HStack(spacing: 0) {
                ForEach(sources, id: \.self) { item in
                    itemBuilder(item)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Radius.s)
                .fill(.GrayGlass002)
                .padding(-3)
        )
    }
}

struct PreviewWeb3ModalPicker: View {
    
    enum Platform: String, CaseIterable {
        case native
        case browser
    }
    
    @State private var selectedItem: Platform? = .native
    
    var body: some View {
        W3MPicker(
            Platform.allCases,
            selection: selectedItem
        ) { item in
                
            HStack {
                item == .native ? Image.Bold.mobile : Image.Bold.browser
                Text(item.rawValue.capitalized)
            }
            .font(.small600)
            .multilineTextAlignment(.center)
            .foregroundColor(selectedItem == item ? .Foreground100 : .Foreground200)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    selectedItem = item
                }
            }
        }
        .accentColor(Color.Overgray005)
        .frame(maxWidth: 200)
        .padding()
    }
}

struct Web3ModalPicker_Previews: PreviewProvider {
    static var previews: some View {
        PreviewWeb3ModalPicker()
    }
}
