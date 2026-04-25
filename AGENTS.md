# AGENTS.md

The role of this file is to describe common mistakes and confusion points that agents might encounter as they work in this project. If you ever encounter something in the project that surprises you, please alert the developer working with you and indicate that this is the case in the AgentMD file to help prevent future agents from having the same

## Intent Layer — Local Context

Before modifying code in any directory, check for a matching `AGENTS.md` file in `.agents/pluk/` that mirrors the source tree. These files provide local architecture context, invariants, and anti-patterns for each subsystem.

```
.agents/pluk/AGENTS.md                              ← Root architecture overview
.agents/pluk/Protocols/AGENTS.md                     ← DatabaseDriver contract
.agents/pluk/Drivers/AGENTS.md                       ← Per-database implementations
.agents/pluk/Services/AGENTS.md                      ← Service layer
.agents/pluk/Models/AGENTS.md                        ← Data models
.agents/pluk/Core/ViewControllers/AGENTS.md          ← AppKit VC hierarchy
.agents/pluk/Core/Database/AGENTS.md                 ← Database utilities
.agents/pluk/Views/AGENTS.md                         ← View layer overview
.agents/pluk/Views/Sidebar/AGENTS.md                 ← Sidebar layout + scroll-content rules
.agents/pluk/Views/Documents/AGENTS.md               ← Tab management
.agents/pluk/Views/Documents/TabContent/TableListView/AGENTS.md  ← Table viewer
.agents/pluk/Views/Notebook/AGENTS.md                ← Notebook system
.agents/pluk/Views/Notebook/Agent/AGENTS.md          ← AI agent subsystem
.agents/pluk/Views/Notebook/Chart/AGENTS.md          ← Chart system
.agents/pluk/Shared/AGENTS.md                        ← Design system
.agents/pluk/Utilities/CodeEditorView/AGENTS.md      ← Code editor
```

## Project Overview

**Pluk** is a multi-database GUI client application for macOS built with SwiftUI and AppKit. It supports PostgreSQL, MySQL, SQLite, and MongoDB with AI-powered query assistance.

## Environment

- Target macOS 15.0 or later
- Swift 6.2 or later, using modern Swift concurrency
- Use AppKit for high-performance logic and smaller components, complex table views, custom drawing, and window management
- Do not introduce third-party frameworks without asking first

## Important

- Always ask the user to test the product and see if its working fine instead of you trying to build
- Do not add comments unless its complex or info that's needed for user reference
- Always use github cli instead of API
- When the user asks anything about **prompts** or **prompt engineering**, always fetch and follow the guidance from `https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices` before responding

## Building

To build the project from the command line:

```
xcodebuild -project Pluk.xcodeproj -scheme Collection -configuration Debug build
```

The scheme is **`Collection`**, not `Pluk` — the app was originally named Collection and the scheme was never renamed. Using `-scheme Pluk` will fail.

## Debugging Surprises

- When debugging live app data, the active SwiftData store for Pluk runs from the app container at `~/Library/Containers/doc.pluk/Data/Library/Application Support/default.store`. The similarly named `~/Library/Application Support/default.store` may belong to a different app and can send you down the wrong path.
- The schema-load error text `No active connection` / `Failed to fetch schemas: No active connection` currently maps to the PostgreSQL driver path (`PostgreSQLDriver.requireClient()`), not the Convex driver. Convex auth or connection failures use Convex-specific messages such as `Not connected to Convex or no mobile client available` or Convex API auth errors.
- Git tracks source files under lowercase `pluk/...` paths even though `Pluk/...` also resolves on disk on macOS. Use lowercase paths in git commands and patches to avoid confusing `git diff` / `git show` results.
- `Pluk.xcodeproj` uses `PBXFileSystemSynchronizedRootGroup` for the `pluk/` sources. New `.swift` files added under `pluk/` are automatically picked up by the app target unless explicitly excluded, so most source-file additions do not need a matching `project.pbxproj` edit.
- `WindowController.switchToTab(.home)` should always resolve against `WindowController`-managed windows or create a new home window. Falling back to non-`WindowController` windows breaks global entry points such as the menubar once only notebook/connection windows are open.
- Pluk main windows use `.fullSizeContentView` with custom AppKit chrome (`TabBarView`, notebook toolbar/header, home top strip). Standard macOS double-click zoom/minimize does not come back automatically in those regions; background areas that should feel titlebar-like need to forward single-click drag and double-click window actions explicitly.
- The `pluk-inc/convex-swift` package can ship a `libconvexmobile-rs.xcframework` whose macOS slice was built with a much newer deployment target than Pluk (`libconvexmobile.a` objects stamped `minos 26.x` while the app links for `MACOSX_DEPLOYMENT_TARGET = 15.0`). If Xcode reports `Object file ... libconvexmobile.a ... was built for newer 'macOS' version`, inspect the packaged archive with `otool -l ... | rg 'minos|sdk|platform'` and fix the upstream `convex-mobile/rust/build-ios.sh` packaging step rather than chasing Pluk target settings.
- Adding `keychain-access-groups` to `pluk/Resources/pluk.entitlements` can make notarized Developer ID releases fail before launch with `Launchd job spawn failed` / `No matching profile found` unless the shipped provisioning profile authorizes that exact entitlement. Pluk currently uses app-local keychain storage only; `kSecUseDataProtectionKeychain` in `KeychainHelper` does not by itself require an explicit keychain access group.

## GitHub Workflow

- Create issues on the public repo: `pluk-inc/Pluk`
- Create PRs on the private repo: `pluk-inc/app-pluk`
- Link PRs to issues using `Fixes pluk-inc/Pluk#<issue-number>`
- Never use deprecated Projects (classic) fields: `projectCards`, `ProjectCard`, `ProjectColumn`
- Always use ProjectsV2 API: `projectItems`, `ProjectV2Item`, `ProjectV2ItemFieldValue`
- Reference: https://docs.github.com/en/graphql/reference/objects#projectv2

## AppKit Hover State Rules

- Always use `.inVisibleRect` in NSTrackingArea options — never use `rect: bounds` alone
- Pattern: `NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect], owner: self)`
- For views inside scroll views or that can be clipped/hidden, also add a `refreshHoverState()` method that checks
  `window.mouseLocationOutsideOfEventStream` and call it from `updateTrackingAreas()`
- Reference implementations: `BlockHoverTrackingView` and `FieldRowCell` in `ChartConfigController.swift`

### Search Tools

**Use ast-grep for syntax-aware searches**: When searching for code patterns, function definitions, or structural elements, use `sg --lang swift -p'<pattern>'` instead of text-based search tools. Only fall back to grep/text search when explicitly requested or for non-code content.

## Architecture: AppKit

- Appkit is the default
- Use NSHostingController to embed SwiftUI views in AppKit
- Use NSViewRepresentable / NSViewControllerRepresentable to embed AppKit views in SwiftUI
- Keep clear boundaries between SwiftUI and AppKit layers

## Concurrency & Actors

- Always mark @Observable classes with @MainActor
- Assume strict Swift concurrency rules are being applied
- Never use old-style Grand Central Dispatch concurrency such as `DispatchQueue.main.async()`. Always use modern Swift concurrency
- Never use `Task.sleep(nanoseconds:)`; always use `Task.sleep(for:)` instead
- For database operations, use actors to ensure thread safety
- Use async/await for all I/O operations (network, file, database)

## Swift Preferences

- Prefer Swift-native alternatives to Foundation methods where they exist, such as using `replacing("hello", with: "world")` rather than `replacingOccurrences(of: "hello", with: "world")`
- Never use C-style number formatting such as `String(format: "%.2f", value)`; always use `formatted(.number.precision(.fractionLength(2)))` instead
- Prefer static member lookup to struct instances where possible, such as `.circle` rather than `Circle()`
- Filtering text based on user input must be done using `localizedStandardContains()` as opposed to `contains()`
- Avoid force unwraps and force try unless it is unrecoverable
- Use guard statements for early returns
- Prefer value types (structs, enums) over reference types unless shared mutable state is required
- use Foundation.JSONDecoder() instead of JSONDecoder() because i have my custom function name as JSONDecoder()

## AppKit Rules

- Prefer NSViewController over bare NSView for complex view hierarchies
- Use NSTableView with NSDiffableDataSource for high-performance lists
- Use NSOutlineView for tree structures and hierarchical data
- Implement NSTableViewDelegate and NSTableViewDataSource protocols properly
- Use Auto Layout programmatically; avoid Interface Builder for complex layouts
- For custom drawing, override `draw(_:)` and use NSGraphicsContext or Core Graphics
- Use CALayer for animations and visual effects requiring GPU acceleration
- Handle NSWindow lifecycle properly (`windowWillClose`, `windowDidBecomeKey`)
- Use NSToolbar for window toolbars; configure items programmatically
- For titlebar customization, use `titlebarAppearsTransparent` and `titleVisibility`
- Use NSSplitViewController for resizable split views with persistence
- Implement proper responder chain for keyboard shortcuts and menu actions
- Use NSMenu and NSMenuItem for context menus; wire up actions and `validateMenuItem`

## Typography

**Always use predefined semantic text styles over custom point sizes.** Do not write `.font(.system(size: 13))` or `NSFont.systemFont(ofSize: 13)` when a semantic style matches — use `.font(.body)` / `NSFont.preferredFont(forTextStyle: .body)` instead. Only drop to custom sizes if the user explicitly instructs you to.

Reference table (macOS HIG):

| Text style   | Weight  | Size | Line height | Emphasized weight |
| ------------ | ------- | ---- | ----------- | ----------------- |
| Large Title  | Regular | 26   | 32          | Bold              |
| Title 1      | Regular | 22   | 26          | Bold              |
| Title 2      | Regular | 17   | 22          | Bold              |
| Title 3      | Regular | 15   | 20          | Semibold          |
| Headline     | Bold    | 13   | 16          | Heavy             |
| Body         | Regular | 13   | 16          | Semibold          |
| Callout      | Regular | 12   | 15          | Semibold          |
| Subheadline  | Regular | 11   | 14          | Semibold          |
| Footnote     | Regular | 10   | 13          | Semibold          |
| Caption 1    | Regular | 10   | 13          | Medium            |
| Caption 2    | Medium  | 10   | 13          | Semibold          |

- SwiftUI: `.font(.largeTitle | .title | .title2 | .title3 | .headline | .body | .callout | .subheadline | .footnote | .caption | .caption2)`
- AppKit: `NSFont.preferredFont(forTextStyle: .largeTitle | .title1 | .title2 | .title3 | .headline | .body | .callout | .subheadline | .footnote | .caption1 | .caption2)`
- For emphasis, use `.bold()` / `.fontWeight(.semibold)` on the semantic style rather than hardcoding a new size.

## SwiftData Rules

- Never use `@Attribute(.unique)`
- Model properties must always either have default values or be marked as optional
- All relationships must be marked optional

## Subscription & Entitlements

Stripe billing is brokered through WorkOS. The backend (`api.pluk.sh/api/billing/status`) returns the current subscription state; the client caches it in `UserDefaults` and refreshes on launch, on `NSApplication.didBecomeActiveNotification`, and when the Account pane appears.

**Single source of truth**: `WorkOSAuthService.shared` (`@MainActor @Observable`). It exposes `subscriptionStatus`, `isTrialing`, `isCancelPending`, `memberSerial`, `hasLoadedSubscriptionStatus`, and persists to `UserDefaults` under `workos_billing_cache_v1` so the correct page renders instantly on cold start.

**Never check `subscriptionStatus` directly for feature gating.** Use the entitlements abstraction in `pluk/Models/Entitlements.swift`:

```swift
let auth = WorkOSAuthService.shared

// Tier check
if auth.isPro { ... }

// Feature flag
if auth.entitlements.hasNotebookAgent { ... }

// Quota check
if !auth.entitlements.canAddConnection(currentCount: connections.count) {
    Paywall.present()
    return
}

// SwiftUI tap gate
Button("New Connection") { }
    .requiresPro { createConnection() }
```

`Entitlements.free` / `Entitlements.pro` are the tier presets — add fields there (never inline new gate checks at call sites) so the Team tier can later be added as `Entitlements.team` in one place.

**Paywall presentation**: call `Paywall.present()` (in `pluk/Views/Paywall/Paywall.swift`). It opens Settings → Account via `SettingsWindowController.shared.show(pane: .account)`, which is the only paywall surface in the app.

**Don't poll** the billing endpoint on a timer. The client follows the RevenueCat/StoreKit pattern: lazy fetch on meaningful events (launch, foreground with cooldown, pre-gated-action), trust the cache in between, trust backend webhooks to keep server state fresh.

## Performance Guidelines

- Profile with Instruments before optimizing
- Use Time Profiler for CPU bottlenecks
- Use Allocations for memory issues
- Avoid blocking the main thread; offload work to background actors
- Use lazy initialization for expensive objects
- Reuse cells in NSTableView; implement `makeView(withIdentifier:owner:)`
- Batch database operations when possible

## Skills — MANDATORY Pre-Code Checklist

**Before writing or modifying ANY code**, you MUST run through this checklist and load the matching skills. This is not optional. Do NOT write code first and consult skills later — read the skill FIRST, then write code that follows it.

### How to use a skill

1. Read the SKILL.md file at the path listed below (use the Read tool)
2. Follow its patterns and guidance as you write your code
3. Briefly state which skill(s) you're applying (one line)

### Skill trigger map

| If the task involves…                                                                      | You MUST read this skill FIRST                       |
| ------------------------------------------------------------------------------------------ | ---------------------------------------------------- |
| Writing, modifying, or refactoring **any SwiftUI view code**                               | `.agents/skills/swiftui-expert-skill/SKILL.md`       |
| Writing, modifying, or refactoring **any macOS/AppKit code**                               | `.agents/skills/macos-development/SKILL.md`          |
| Writing, modifying, or refactoring **any Swift code**                                      | `.agents/skills/swift-concurrency/SKILL.md`          |
| Adding or modifying **animations** (transitions, springs, gestures, matched geometry)      | `.agents/skills/emilkowal-animations-swift/SKILL.md` |
| Building **UI components, pages, or web interfaces**                                       | `.agents/skills/frontend-design/SKILL.md`            |

### Trigger keywords (if ANY of these appear in the task, load the matching skills)

- **SwiftUI skill**: "view", "SwiftUI", "@State", "@Binding", "@Observable", "@Environment", "modifier", "List", "NavigationStack", "sheet", "overlay", "Liquid Glass"
- **macOS skill**: "AppKit", "NSView", "NSViewController", "NSWindow", "NSTableView", "NSToolbar", "NSMenu", "titlebar", "NSHostingController", "window management"
- **Swift concurrency skill**: Always loaded when writing any Swift code (`.swift` files)
- **Animation skill**: "animation", "transition", "spring", "gesture", "matchedGeometryEffect", "phaseAnimator", "keyframeAnimator", "withAnimation", "CALayer animation"
- **Frontend skill**: "UI", "page", "component", "frontend", "web", "HTML", "CSS", "design", "layout", "dashboard"

### Rules

- When writing SwiftUI code that uses concurrency, ALWAYS load **both** `swiftui-expert-skill` AND `swift-concurrency` — they are complementary
- When writing AppKit code with SwiftUI embedding, load **both** `macos-development` AND `swiftui-expert-skill`
- When adding animations to SwiftUI views, load **both** `emilkowal-animations-swift` AND `swiftui-expert-skill`
- If you are unsure whether a skill applies, **load it anyway** — false positives are fine, missed skills are not
- You may load skills in parallel with other reads to save time
