import AppKit
import SwiftUI

final class NotebookAgentController: NSViewController {

    private let dataController: NotebookDataController

    init(dataController: NotebookDataController) {
        self.dataController = dataController
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        let hosting = NSHostingView(rootView: AgentPanelView(dataController: dataController))
        self.view = hosting
    }
}
