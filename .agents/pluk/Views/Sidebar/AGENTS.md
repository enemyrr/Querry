# Views/Sidebar/

## Purpose

SwiftUI sidebar components used inside the left connection sidebar, including the connection details view, schema selector, and feedback UI.

## Key Files

- `pluk/Views/Sidebar/ConnectionDetails/CollectionDetails.swift` — Main connection sidebar shell
- `pluk/Views/Sidebar/ConnectionDetails/DatabaseList.swift` — Table/function list content
- `pluk/Views/Sidebar/ConnectionDetails/DatabaseHeader.swift` — Sidebar header controls
- `pluk/Views/Sidebar/SchemaSelectorView.swift` — Schema picker
- `pluk/Views/Sidebar/FeedbackForm.swift` — Feedback popover content

## Invariants

- `ConnectionDetailsSidebar` is content-driven. Do not make promo cards, notices, or CTAs behave like pinned footers unless the design explicitly calls for a footer.
- Supplemental UI that should appear "below the table view" must live inside the scroll content, after `DatabaseList` or the history list. Do not add it as a sibling below the `ScrollView`.
- Putting cards outside the `ScrollView` makes the list expand to fill the sidebar height and creates broken spacing that looks like the whole window is being forced taller.
- If the user explicitly asks for a floating action/footer treatment, render the card outside the scroll content as an overlay aligned to the bottom of the scroll region, and add bottom padding/inset to the scroll content so rows do not disappear behind it.
- Preserve the current header order: connection name, database controls, optional search, then scroll content.
- Keep sidebar spacing tight and content-relative; avoid layouts that depend on spare window height.

## Anti-Patterns

- Do NOT place upgrade promos, banners, or onboarding cards as footer siblings of the `ScrollView` in `CollectionDetails.swift`.
- Do NOT “fix” sidebar placement with large spacer values or container-level height forcing.
- Do NOT use a plain sibling footer when the desired effect is a floating action card; use an overlay plus scroll-content bottom inset instead.
- Do NOT move table-adjacent UI above the database controls unless the user explicitly asks for a header treatment.

## Surprise

- A card rendered after the `ScrollView` but still inside the outer sidebar `VStack` reads like a pinned footer, not content below the tables. In this sidebar, “below the table view” means inside the scrollable list content.
