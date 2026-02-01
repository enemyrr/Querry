//
//  QuickLookPopoverController.swift
//  Pluk
//
//  Created by Claude on 1/29/26.
//

import AppKit
import SwiftUI

@MainActor
final class QuickLookPopoverController {
    static let shared = QuickLookPopoverController()

    private var popover: NSPopover?

    private init() {}

    func showQuickLook(
        for content: String,
        fieldName: String,
        dataType: String,
        relativeTo positioningRect: NSRect,
        of positioningView: NSView,
        onSave: @escaping (String) -> Void
    ) {
        closePopover()

        let popover = NSPopover()
        popover.behavior = .semitransient
        popover.animates = true

        let contentView = QuickLookContentView(
            fieldName: fieldName,
            dataType: dataType,
            content: content,
            onSave: onSave,
            onDismiss: { [weak self] in
                self?.closePopover()
            }
        )

        let hostingController = NSHostingController(rootView: contentView)
        popover.contentViewController = hostingController

        popover.show(relativeTo: positioningRect, of: positioningView, preferredEdge: .maxY)

        self.popover = popover
    }

    func closePopover() {
        popover?.performClose(nil)
        popover = nil
    }
}
