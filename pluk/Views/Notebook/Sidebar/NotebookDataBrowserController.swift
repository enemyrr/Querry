import AppKit
import SwiftUI

final class NotebookDataBrowserController: NSViewController {

    private let dataController: NotebookDataController

    init(dataController: NotebookDataController) {
        self.dataController = dataController
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        let rootView = DataBrowserView(dataController: dataController)
        let hostingView = NSHostingView(rootView: AnyView(rootView))
        self.view = hostingView
    }
}
