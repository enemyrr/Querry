//
//  CheckboxCellView.swift
//  Pluk
//
//  Created by Fauzaan on 6/4/25.
//

import Foundation
import AppKit

class CheckboxCellView: NSView {
    private var checkbox: NSButton!
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupCheckbox()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCheckbox()
    }
    
    private func setupCheckbox() {
        checkbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
        addSubview(checkbox)
        
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            checkbox.centerXAnchor.constraint(equalTo: centerXAnchor),
            checkbox.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    func configure(isChecked: Bool, row: Int, target: Any?, action: Selector?) {
        checkbox.state = isChecked ? .on : .off
        checkbox.tag = row
        checkbox.target = target as? AnyObject
        checkbox.action = action
    }
    
    // Prepare for reuse - reset state
    override func prepareForReuse() {
        super.prepareForReuse()
        checkbox.state = .off
        checkbox.tag = -1
        checkbox.target = nil
        checkbox.action = nil
    }
}
