import SwiftUI
import UIKit

class Web3ModalSheetController: UIHostingController<ModalContainerView> {
    @available(*, unavailable)
    @MainActor dynamic required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init(router: Router) {
        super.init(rootView: ModalContainerView(router: router))
        self.modalTransitionStyle = .crossDissolve
        self.modalPresentationStyle = .overFullScreen
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .clear
    }
}
