//
//  OperatorDropdown.swift
//  Pluk
//
//  Created by Assistant on 7/7/25.
//

import SwiftUI
import AppKit

/// A floating panel for the operator dropdown
class OperatorPanel<Content: View>: NSPanel {
    @Binding var isPresented: Bool
    
    init(content: @escaping () -> Content,
         contentRect: NSRect,
         isPresented: Binding<Bool>) {
        self._isPresented = isPresented
        
        super.init(contentRect: contentRect,
                   styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
                   backing: .buffered,
                   defer: false)
        
        // Panel configuration
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.transient, .ignoresCycle, .fullScreenAuxiliary]
        hasShadow = true
        
        /// Don't show a window title, even if it's set
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        
        // Enable vibrancy
        appearance = NSAppearance.currentDrawing()
        
        // Hide on deactivate
        hidesOnDeactivate = false
        
        // Set content
        contentView = NSHostingView(rootView: content().ignoresSafeArea())
    }
    
    override func resignMain() {
        super.resignMain()
        close()
    }
    
    override func close() {
        super.close()
        isPresented = false
    }
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

struct OperatorDropdown: View {
    @Binding var selectedOperator: FilterOperator
    @State private var isShowingDropdown = false
    @State private var panel: OperatorPanel<AnyView>?
    @State private var buttonFrame: CGRect = .zero
    @State private var activeIndex: Int = 0
    @State private var hoveredIndex: Int? = nil
    @State private var eventMonitor: Any?
    
    private var operators: [FilterOperator] {
        FilterOperator.allCases
    }
    
    var body: some View {
        Button(action: {
            toggleDropdown()
        }) {
            HStack {
                Text(selectedOperator.rawValue)
                Spacer()
                Image(systemName: "chevron.compact.down")
                    .scaleEffect(CGSize(width: 0.7, height: 1.5))
            }
        }
        .buttonStyle(FilterDropdownStyle())
        .frame(width: 120)
        .background(
            GeometryReader { geometry in
                Color.clear
                    .preference(key: ButtonFrameKey.self, value: geometry.frame(in: .global))
            }
        )
        .onPreferenceChange(ButtonFrameKey.self) { frame in
            buttonFrame = frame
        }
        .onAppear {
            createPanel()
        }
        .onDisappear {
            panel?.close()
            panel = nil
        }
        .onChange(of: isShowingDropdown) { _, newValue in
            if newValue {
                showPanel()
            } else {
                panel?.close()
            }
        }
    }
    
    private func toggleDropdown() {
        isShowingDropdown.toggle()
    }
    
    private func createPanel() {
        // Set initial active index
        if let currentIndex = operators.firstIndex(of: selectedOperator) {
            activeIndex = currentIndex
        }
        
        let dropdownContent = AnyView(
            OperatorListView(
                operators: operators,
                selectedOperator: selectedOperator,
                activeIndex: $activeIndex,
                hoveredIndex: $hoveredIndex,
                onSelect: { op in
                    selectedOperator = op
                    isShowingDropdown = false
                },
                onDismiss: {
                    isShowingDropdown = false
                }
            )
        )
        
        let contentRect = CGRect(x: 0, y: 0, width: 170, height: CGFloat(operators.count * 10))
        panel = OperatorPanel(content: { dropdownContent }, contentRect: contentRect, isPresented: $isShowingDropdown)
    }
    
    private func showPanel() {
        guard let panel = panel, let window = NSApp.mainWindow else { return }
        
        // Convert button frame to screen coordinates
        let windowFrame = window.frame
        let screenX = windowFrame.origin.x + buttonFrame.origin.x
        let screenY = windowFrame.origin.y + windowFrame.height - buttonFrame.maxY
        
        // Position panel below button
        let panelX = screenX
        let panelY = screenY - panel.frame.height - 4
        
        panel.setFrameOrigin(NSPoint(x: panelX, y: panelY))
        panel.orderFront(nil)
        panel.makeKey()
        
        // Setup click outside monitor
        setupEventMonitor()
    }
    
    private func setupEventMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { event in
            guard let panel = self.panel, let window = event.window else {
                self.isShowingDropdown = false
                return event
            }
            
            // If click is not in our panel, close it
            if window != panel {
                self.isShowingDropdown = false
            }
            
            return event
        }
    }
    
    private func removeEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}

// Preference key to track button frame
struct ButtonFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

// The dropdown list content
struct OperatorListView: View {
    let operators: [FilterOperator]
    let selectedOperator: FilterOperator
    @Binding var activeIndex: Int
    @Binding var hoveredIndex: Int?
    let onSelect: (FilterOperator) -> Void
    let onDismiss: () -> Void
    
    @State private var keyboardMonitor: Any?
    
    var body: some View {
        ZStack {
            VisualEffectView(
                material: .hudWindow,
                blendingMode: .behindWindow,
            )

            VStack(spacing: 0) {
                ForEach(Array(operators.enumerated()), id: \.offset) { index, op in
                    Button(action: {
                        onSelect(op)
                    }) {
                        HStack {
                            Text(op.rawValue)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text(operatorSign(for: op))
                                .foregroundColor(.secondary)
                                .font(.system(size: 14, design: .monospaced))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .frame(minWidth: 150)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(backgroundColorForItem(at: index))
                    )
                    .onHover { isHovered in
                        hoveredIndex = isHovered ? index : nil
                        if isHovered {
                            activeIndex = index
                        }
                    }
                }
            }
            .padding(6)
        }
        .onAppear {
            setupKeyboardMonitor()
        }
        .onDisappear {
            removeKeyboardMonitor()
        }
        .padding(.vertical, -12)
    }
    
    private func setupKeyboardMonitor() {
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            switch event.keyCode {
            case 125: // Down arrow
                activeIndex = min(activeIndex + 1, operators.count - 1)
                return nil
            case 126: // Up arrow
                activeIndex = max(activeIndex - 1, 0)
                return nil
            case 36: // Enter/Return
                if activeIndex < operators.count {
                    onSelect(operators[activeIndex])
                }
                return nil
            case 53: // Escape
                onDismiss()
                return nil
            default:
                return event
            }
        }
    }
    
    private func removeKeyboardMonitor() {
        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
            keyboardMonitor = nil
        }
    }
    
    private func backgroundColorForItem(at index: Int) -> Color {
        if index == activeIndex {
            return .orange
        } else if hoveredIndex == index {
            return .orange
        } else {
            return .clear
        }
    }
    
    private func operatorSign(for operator: FilterOperator) -> String {
        switch `operator` {
        case .equals:
            return "="
        case .notEquals:
            return "!="
        case .contains:
            return "∋"
        case .startsWith:
            return "^"
        case .endsWith:
            return "$"
        case .greaterThan:
            return ">"
        case .lessThan:
            return "<"
        }
    }
}


