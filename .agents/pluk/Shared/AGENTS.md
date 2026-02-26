# Shared/

## Purpose

Design system components — reusable SwiftUI views and AppKit utilities used across the app. When building UI, check here first before creating custom components.

## Component Inventory

| File | Component | Use Instead Of |
|------|-----------|---------------|
| `Button.swift` | 20+ button styles (Primary, Secondary, ActionButton, TabBar, Icon, DeleteAction, etc.) | Stock SwiftUI `.buttonStyle()` |
| `TextField.swift` | Custom text field styles, text editor with placeholder | Stock `TextField` |
| `FloatingDropdown.swift` | Dropdown for `CaseIterable` enums with floating panel | Stock `Picker` |
| `ArrayFloatingDropdown.swift` | Dropdown for arbitrary arrays (non-enum) | Stock `Picker` |
| `FloatingPanel.swift` | NSPanel subclass for floating UI elements with anchor positioning | Custom popover |
| `CustomTooltip.swift` | Tooltip system with `TooltipCoordinator`, `TooltipWindow`, AppKit support | Stock `.help()` |
| `Form.swift` | `FormField` component with error messages and highlights | Raw `VStack` |
| `Background.swift` | Glass effect backgrounds (macOS 26+ with fallback) | `.background()` |
| `RoundedCorners.swift` | Per-corner radius shapes | `.clipShape()` |
| `FadedDivider.swift` | Divider with fade effect | `Divider()` |
| `ConfettiView.swift` | Celebration animation | N/A |
| `IntelligenceUIPlatterView.swift` | AI UI component platter | N/A |
| `Backport.swift` | Backward compatibility helpers | N/A |

### CustomSplitView/ subdirectory

| File | Purpose |
|------|---------|
| `SidebarSplitViewController.swift` | Hover divider split view with dynamic visibility |
| `EnvironmentOption.swift` | Environment configuration |
| `WindowAccessor.swift` | Window access utilities |
| `NSToolbarItem+Identifier.swift` | Toolbar extensions |

## Patterns

- Button styles implement `ButtonStyle` protocol with `makeBody(configuration:)`
- All hover effects use `@State var isHovering` with `onHover` modifier
- Light/dark mode awareness via `@Environment(\.colorScheme)`
- Custom tracking areas use `.inVisibleRect` option (per CLAUDE.md hover rules)
- `FloatingPanel` is an NSPanel — use for dropdowns that need to float above the window
- Glass effects check `#available(macOS 26, *)` with fallback styling

## Invariants

- Design system components are the preferred choice over stock SwiftUI equivalents
- `FloatingPanel` handles its own positioning relative to an anchor view
- `TooltipCoordinator` manages a singleton `TooltipWindow` — don't create tooltip windows manually
- Button styles support `isHovering`, `isPressed`, and disabled states

## Anti-Patterns

- Do NOT use stock SwiftUI `Picker` for dropdowns — use `FloatingDropdown` or `ArrayFloatingDropdown`
- Do NOT create custom button styles without checking if one already exists in `Button.swift`
- Do NOT use `.help()` for tooltips — use `CustomTooltip` for consistent styling
- Do NOT create floating panels manually — use the `FloatingPanel` NSPanel subclass
