//
//  ThreePanelSplitView.swift
//  Pluk
//
//  Created by Fauzaan on 7/2/25.
//
import SwiftUI

// MARK: - Main Three Panel Split View

struct ThreePanelSplitView<Left: View, Middle: View, Right: View>: View {
    // Fixed widths (in points/pixels) for all three panels
    @Binding var leftWidth: CGFloat
    @Binding var middleWidth: CGFloat
    @Binding var rightWidth: CGFloat
    
    // Hide/show state for each panel (ADDED)
    @Binding var isLeftHidden: Bool
    @Binding var isMiddleHidden: Bool
    @Binding var isRightHidden: Bool
    
    let dividerColor: Color
    let minPanelSize: CGFloat = 50 // Minimum size for each panel
    let left: Left
    let middle: Middle
    let right: Right
    

    // Divider styling
    private let dividerVisibleSize: CGFloat = 1
    private let dividerInvisibleSize: CGFloat = 6
    
    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let totalHeight = geometry.size.height
            
            // Calculate which panels are visible (ADDED)
            let visiblePanels = [!isLeftHidden, !isMiddleHidden, !isRightHidden]
            let visibleCount = visiblePanels.filter { $0 }.count
            let totalDividerWidth = CGFloat(max(0, visibleCount - 1)) * dividerVisibleSize
            
            // Calculate actual widths based on visibility (MODIFIED)
            let actualLeftWidth = isLeftHidden ? 0 : max(minPanelSize, leftWidth)
            let actualMiddleWidth = isMiddleHidden ? 0 : max(minPanelSize, middleWidth)
            let actualRightWidth = isRightHidden ? 0 : max(minPanelSize, rightWidth)
            
            // Calculate divider positions (MODIFIED)
            let leftDividerX = isLeftHidden ? 0 : actualLeftWidth
            let rightDividerX = leftDividerX + (isLeftHidden || isMiddleHidden ? 0 : dividerVisibleSize) + actualMiddleWidth
            
            ZStack(alignment: .topLeading) {
                // Left Panel (MODIFIED - conditional rendering)
                if !isLeftHidden {
                    left
                        .frame(width: actualLeftWidth, height: totalHeight)
                        .position(x: actualLeftWidth / 2, y: totalHeight / 2)
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("Left panel")
                        .transition(.move(edge: .leading))
                }
                
                // Middle Panel (MODIFIED - conditional rendering)
                    let middleX = (isLeftHidden ? 0 : actualLeftWidth + dividerVisibleSize) + actualMiddleWidth / 2
                    middle
                        .frame(width: actualMiddleWidth, height: totalHeight)
                        .position(x: middleX, y: totalHeight / 2)
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("Middle panel")
                        .transition(.opacity)
                
                // Right Panel (MODIFIED - conditional rendering)
                if !isRightHidden {
                    let rightX = rightDividerX + (isMiddleHidden ? 0 : dividerVisibleSize) + actualRightWidth / 2
                    right
                        .frame(width: actualRightWidth, height: totalHeight)
                        .position(x: rightX, y: totalHeight / 2)
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("Right panel")
                        .transition(.move(edge: .trailing))
                }
                
                // Left Divider (MODIFIED - only show if both left and middle are visible)
                if !isLeftHidden && !isMiddleHidden {
                    SplitDivider(
                        visibleSize: dividerVisibleSize,
                        invisibleSize: dividerInvisibleSize,
                        color: dividerColor
                    )
                    .position(x: leftDividerX, y: totalHeight / 2)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let minimumRemainingPanelsWidth = (isMiddleHidden ? 0 : minPanelSize) + (isRightHidden ? 0 : minPanelSize)
                                let maxLeftWidth = totalWidth - minimumRemainingPanelsWidth - totalDividerWidth
                                let dragPosition = leftDividerX + value.translation.width
                                let newWidth = max(minPanelSize, min(dragPosition, maxLeftWidth))
                                leftWidth = newWidth
                            }
                    )
                }
                
                // Right Divider (MODIFIED - only show if middle and right are both visible)
                if !isMiddleHidden && !isRightHidden {
                    SplitDivider(
                        visibleSize: dividerVisibleSize,
                        invisibleSize: dividerInvisibleSize,
                        color: dividerColor
                    )
                    .position(x: rightDividerX, y: totalHeight / 2)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let leftDividerWidth = (!isLeftHidden && !isMiddleHidden) ? dividerVisibleSize : 0
                                let rightDividerWidth = dividerVisibleSize // This divider itself
                                let usedWidth = actualLeftWidth + leftDividerWidth
                                let availableWidth = totalWidth - usedWidth
                                let dragPosition = value.location.x - actualLeftWidth - dividerVisibleSize
                                
                                let newMiddleWidth = max(minPanelSize, min(dragPosition, availableWidth - minPanelSize))
                                let newRightWidth = max(minPanelSize, availableWidth - newMiddleWidth)
                                
                                middleWidth = newMiddleWidth
                                rightWidth = newRightWidth
                            }
                    )
                }
            }
        }
        // ADDED - animations for hide/show
        .animation(.easeInOut(duration: 0.3), value: isLeftHidden)
        .animation(.easeInOut(duration: 0.3), value: isMiddleHidden)
        .animation(.easeInOut(duration: 0.3), value: isRightHidden)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Three panel split view")
    }
    
    // MODIFIED - added hide parameters with defaults
    init(
        leftWidth: Binding<CGFloat>,
        middleWidth: Binding<CGFloat>,
        rightWidth: Binding<CGFloat>,
        isLeftHidden: Binding<Bool> = .constant(false),
        isMiddleHidden: Binding<Bool> = .constant(false),
        isRightHidden: Binding<Bool> = .constant(false),
        dividerColor: Color = Color.gray,
        @ViewBuilder left: () -> Left,
        @ViewBuilder middle: () -> Middle,
        @ViewBuilder right: () -> Right
    ) {
        self._leftWidth = leftWidth
        self._middleWidth = middleWidth
        self._rightWidth = rightWidth
        self._isLeftHidden = isLeftHidden
        self._isMiddleHidden = isMiddleHidden
        self._isRightHidden = isRightHidden
        self.dividerColor = dividerColor
        self.left = left()
        self.middle = middle()
        self.right = right()
    }
}

struct SplitDivider: View {
    let visibleSize: CGFloat
    let invisibleSize: CGFloat
    let color: Color
    
    var body: some View {
        ZStack {
            // Invisible hit area for easier dragging
            Color.clear
                .frame(width: visibleSize + invisibleSize, height: nil)
                .contentShape(Rectangle())
            
            // Visible divider line
            Rectangle()
                .fill(color)
                .frame(width: visibleSize, height: nil)
        }
        .onHover { isHovered in
            if isHovered {
                NSCursor.resizeLeftRight.push()
            } else {
                NSCursor.pop()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Vertical divider")
        .accessibilityHint("Drag to resize panels")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Usage Example
// MARK: - Usage Example

struct PContentView: View {
    @State private var leftWidth: CGFloat = 200     // Left panel is 200 points wide
    @State private var middleWidth: CGFloat = 300   // Middle panel is 300 points wide
    @State private var rightWidth: CGFloat = 250    // Right panel is 250 points wide
    
    // Hide/show state for panels
    @State private var isLeftHidden = false
    @State private var isMiddleHidden = false
    @State private var isRightHidden = false
    
    var body: some View {
        VStack {
            // Control buttons
            HStack {
                Button("Toggle Left") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isLeftHidden.toggle()
                    }
                }
                
                Button("Toggle Middle") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isMiddleHidden.toggle()
                    }
                }
                
                Button("Toggle Right") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isRightHidden.toggle()
                    }
                }
                
                Spacer()
                
                Button("Show All") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isLeftHidden = false
                        isMiddleHidden = false
                        isRightHidden = false
                    }
                }
            }
            .padding()
            
            // Split view (MODIFIED - now connected to hide state)
            ThreePanelSplitView(
                leftWidth: $leftWidth,
                middleWidth: $middleWidth,
                rightWidth: $rightWidth,
                isLeftHidden: $isLeftHidden,       // ← ADDED
                isMiddleHidden: $isMiddleHidden,   // ← ADDED
                isRightHidden: $isRightHidden,    // ← ADDED
                dividerColor: .gray
            ) {
                // Left Panel
                VStack {
                    Text("Left Panel")
                        .font(.headline)
                    Spacer()
                    Text("Width: \(Int(leftWidth))pts")
                    Text("Visible: \(!isLeftHidden ? "Yes" : "No")")
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                
            } middle: {
                // Middle Panel
                VStack {
                    Text("Middle Panel")
                        .font(.headline)
                    Spacer()
                    Text("Width: \(Int(middleWidth))pts")
                    Text("Visible: \(!isMiddleHidden ? "Yes" : "No")")
                    Spacer()
                }
                .padding()
                .background(Color.green.opacity(0.1))
                
            } right: {
                // Right Panel
                VStack {
                    Text("Right Panel")
                        .font(.headline)
                    Spacer()
                    Text("Width: \(Int(rightWidth))pts")
                    Text("Visible: \(!isRightHidden ? "Yes" : "No")")
                }
                .padding()
                .background(Color.red.opacity(0.1))
            }
        }
    }
}

// MARK: - Preview

#Preview {
    PContentView()
        .frame(width: 800, height: 600)
}
