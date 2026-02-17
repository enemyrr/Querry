import AppKit
import SwiftUI

final class NotebookAgentController: NSViewController {

    override func loadView() {
        let hosting = NSHostingView(rootView: AgentPanelView())
        self.view = hosting
    }
}
