import AppKit
import SwiftUI

final class NotebookAgentController: NSViewController {

    override func loadView() {
        let hostingView = NSHostingView(rootView: AnyView(AgentPanelView()))
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        self.view = hostingView
    }
}
