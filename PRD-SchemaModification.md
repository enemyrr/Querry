# Product Requirement Document (PRD)
## Schema Modification Feature - Columns and Indexes

## 1. Overview

The Schema Modification feature enables users to add, modify, and delete table columns and indexes directly within Pluk's schema mode interface. Currently in read-only mode, this enhancement transforms the schema view into a fully functional editor supporting PostgreSQL initially, with architecture designed for future database driver support. Users can double-click any field to edit immediately, add new columns/indexes inline, and save changes via Cmd+S or save button.

**Key Features:**
- Add, edit, and delete table columns (inline editing)
- Add and delete indexes (inline editing)
- Double-click to edit any field immediately
- Inline addition of new columns and indexes (no modals)
- Modification tracking with visual indicators
- Confirmation dialogs for destructive operations
- Automatic schema refresh after successful modifications
- PostgreSQL driver implementation with extensible architecture

**Integration Points:**
- Existing `SchemaModeView` component
- `DatabaseDriver` protocol extensions
- `TableModificationTracker` pattern adaptation
- `SchemaTableView` and `IndexTableView` coordinators
- `SchemaModeActionBar` for save/cancel/undo actions

## 2. Navigation Integration

```
pluk/
├── Views/
│   └── Documents/
│       └── TabContent/
│           └── TableListView/
│               ├── TableCoordinator.swift
│               └── TableListViewController.swift
```

The schema modification feature lives within the existing schema mode view hierarchy. No new navigation routes are required as this is an enhancement to the current schema mode interface.

**Screen Configuration:**
- Parent: `SchemaModeView` (existing)
- Mode: Always editable (no mode toggle)
- Split View: Columns (top/left 60%) | Indexes (bottom/right 40%)

## 3. Screen/Component Architecture

```
pluk/
├── Views/
│   └── Documents/
│       └── TabContent/
│           └── TableListView/
│               └── ViewModes/
│                   └── SchemaModeView/
│                       ├── SchemaModeView.swift (enhance for double-click editing)
│                       ├── SchemaTableView.swift (enhance for inline editing)
│                       ├── SchemaTableCoordinator.swift (add double-click handlers)
│                       ├── IndexTableView.swift (enhance for inline editing)
│                       ├── IndexTableCoordinator.swift (add double-click handlers)
│                       ├── SchemaModeActionBar.swift (add save/cancel/undo)
│                       └── SchemaModificationTracker.swift (NEW)
├── Protocols/
│   └── DatabaseDriver.swift (extend with schema modification methods)
├── Drivers/
│   ├── PostgreSQL/
│   │   └── PostgreSQLDriver.swift (implement schema methods)
│   ├── MySQL/
│   │   └── MySQLDriver.swift (future implementation)
│   └── SQLite/
│       └── SQLiteDriver.swift (future implementation)
└── Services/
    └── SchemaModificationService.swift (NEW - business logic)
```

**Component Hierarchy:**

```
SchemaModeView (root)
├── SchemaModeViewHeader
│   ├── Table name field (read-only)
│   ├── Search field
│   └── Add column button (in table header)
├── SplitView
│   ├── SchemaTableView (left/top)
│   │   └── NSTableView (double-click editable cells)
│   └── IndexTableView (right/bottom)
│       └── NSTableView (double-click editable cells)
└── SchemaModeActionBar
    ├── Column count label
    ├── Refresh button
    ├── Undo button
    ├── Save changes button (visible when hasModifications)
    └── Cancel button (visible when hasModifications)
```

**State Management Pattern:**

| State Type | Solution | Purpose |
|------------|----------|---------|
| `schemaModifications` | `SchemaModificationTracker` class | Track pending column and index changes |
| `selectedColumn` | `@State` in `SchemaTableView` | Track currently selected column for edit/delete |
| `selectedIndex` | `@State` in `IndexTableView` | Track currently selected index for delete |
| `isLoading` | `@State` in `SchemaModeView` | Show loading state during save operations |
| `errorState` | `@State` in `SchemaModeView` | Display operation errors |
| `isAddingColumn` | `@State` in `SchemaTableView` | Control inline add column row visibility |
| `isAddingIndex` | `@State` in `IndexTableView` | Control inline add index row visibility |

## 4. Features

### 4.1 Double-Click to Edit

**Visual Representation:**
```
User double-clicks any cell:
┌──────┬─────────┬──────────┬─────────┬──────┬────────────┐
│  #   │ Name    │ Type     │ Default │ Null │ Constraints │
├──────┼─────────┼──────────┼─────────┼──────┼────────────┤
│  1   │ id      │ INTEGER  │         │ ☐    │ PK         │
│  2   │ name    │[VARCHAR] │ [NULL]  │ [☑]  │ -          │ ← editing
│  3   │ email   │ VARCHAR  │         │ ☑    │ UNIQUE     │
└──────┴─────────┴──────────┴─────────┴──────┴────────────┘
```

**User Interactions:**
1. Double-click any editable cell
2. Cell becomes editable immediately (no mode toggle)
3. Edit based on cell type:
   - Text fields: Direct text editing
   - Dropdowns: Inline dropdown appears
   - Checkboxes: Toggle with click
4. Press Enter or click away to save edit
5. Press Escape to cancel edit

**Workflow:**
1. User double-clicks cell
2. Cell enters edit mode immediately
3. User modifies value
4. On blur/enter, validation runs
5. If valid, change tracked in `SchemaModificationTracker`
6. Visual indicator shows pending change
7. Save button appears in action bar with change count

**Special Cases:**
- **Primary key columns**: Name and type read-only (prevent breaking PK)
- **Foreign key columns**: Constraint editing opens inline editor
- **Auto increment**: Only shown for supported types

**API Integration:**
- No API call during edit (tracked locally)
- SQL generated on save: `ALTER TABLE table_name ALTER COLUMN column_name [TYPE data_type] [SET DEFAULT value] [DROP NOT NULL];`

### 4.2 Add Column (Inline)

**Visual Representation:**
```
Click "+" button in header or right-click → "Add Column":
┌──────┬─────────┬──────────┬─────────┬──────┬────────────┐
│  #   │ Name    │ Type     │ Default │ Null │ Constraints │
├──────┼─────────┼──────────┼─────────┼──────┼────────────┤
│  1   │ id      │ INTEGER  │         │ ☐    │ PK         │
│  2   │ name    │ VARCHAR  │         │ ☑    │ -          │
│  3   │ email   │ VARCHAR  │         │ ☑    │ UNIQUE     │
├──────┼─────────┼──────────┼─────────┼──────┼────────────┤
│  +   │[new_col]│[VARCHAR▼]│ [NULL]  │ [☑]  │ -          │ ← new row
└──────┴─────────┴──────────┴─────────┴──────┴────────────┘
```

**User Interactions:**
1. Click "+" button in table header OR right-click → "Add Column"
2. New row appears at bottom with editable cells
3. User fills in column properties inline:
   - Name: Text field (validated for uniqueness)
   - Type: Inline dropdown with database types
   - Default: Text field (type validation)
   - Nullable: Checkbox
   - Constraints: Click to open inline constraint editor
4. Press Enter or click away to save new column
5. Press Escape to cancel add

**Workflow:**
1. User clicks add column button or context menu
2. New inline row appears with "+" indicator
3. User enters column name (validated for uniqueness, valid identifiers)
4. User selects data type from inline dropdown
5. User sets nullable, default, constraints inline
6. On blur/enter, validation runs:
   - Column name is unique
   - Column name is valid identifier
   - Type is valid for database
   - Default value matches type
7. Pending change added to tracker
8. New column shown with "new" indicator (green dot/plus)

**API Integration:**
- No API call during add (tracked locally)
- SQL generated on save: `ALTER TABLE table_name ADD COLUMN column_name data_type [constraints];`

### 4.3 Edit Column Properties

**Visual Representation:**
Inline editing cells become editable:
- **Name cell**: Text field with validation
- **Type cell**: Inline dropdown with database types
- **Nullable cell**: Checkbox (toggles)
- **Default cell**: Text field
- **Constraints cell**: Click to open inline constraint editor

```
Row with edit indicators:
┌──────┬─────────┬──────────┬─────────┬──────┬────────────┐
│  #   │ Name    │ Type     │ Default │ Null │ Constraints │
├──────┼─────────┼──────────┼─────────┼──────┼────────────┤
│  1   │[id*]   │INTEGER   │         │ ☐    │ PK         │ ← read-only (PK)
│  2   │[name*] │[VARCHAR▼]│[NULL]   │ ☑    │ -          │ ← editing
│  3   │ email   │VARCHAR   │         │ ☑    │ UNIQUE     │
└──────┴─────────┴──────────┴─────────┴──────┴────────────┘
       ↑            ↑                              ↑
   Primary key   Type dropdown              Click for constraints
   (read-only)  (editable)                (complex edit)
```

**User Interactions:**
1. Double-click editable cell to edit
2. Type dropdown shows available types inline
3. Nullable checkbox toggles with click
4. Default value text field accepts input
5. Constraints cell opens inline constraint editor

**Workflow:**
1. User double-clicks cell
2. Cell becomes editable (text field, dropdown, or checkbox)
3. User modifies value
4. On blur/enter, validation runs
5. If valid, update tracked
6. If invalid, show error and revert
7. Visual indicator shows pending change (e.g., blue dot or asterisk)

**Special Cases:**
- **Primary key columns**: Read-only name, type, nullable (must prevent breaking PK)
- **Foreign key columns**: Constraint editing opens inline FK editor
- **Auto increment**: Only shown for supported types

**API Integration:**
- No API call during edit (tracked locally)
- SQL generated on save: `ALTER TABLE table_name ALTER COLUMN column_name [TYPE data_type] [SET DEFAULT value] [DROP NOT NULL];`

### 4.4 Delete Column

**Visual Representation:**
Right-click context menu on column row:
```
┌─────────────────┐
│ Edit Column     │
│ Delete Column   │
└─────────────────┘
```

**Confirmation Dialog:**
```
┌─────────────────────────────────────────┐
│ Delete Column "email"?              │
│                                   │
│ This action cannot be undone. All   │
│ data in this column will be lost.   │
│                                   │
│ The column is not part of any       │
│ constraints.                       │
│                                   │
│  [Cancel]        [Delete]         │
└─────────────────────────────────────────┘
```

**User Interactions:**
1. Right-click on column row
2. Select "Delete Column" from menu
3. Confirmation dialog appears
4. User confirms deletion

**Workflow:**
1. User right-clicks column
2. Context menu shows delete option
3. On delete click:
   - Check if column is part of constraints (PK, FK, unique)
   - If yes, show error: "Cannot delete column with constraints"
   - If no, show confirmation dialog
4. User confirms
5. Column marked for deletion with strike-through and red indicator
6. Change tracked in modification tracker

**Safety Checks:**
- Cannot delete columns with constraints
- Cannot delete all columns (must leave at least one)
- Cannot drop columns referenced by FKs from other tables

**API Integration:**
- No API call during delete (tracked locally)
- SQL generated on save: `ALTER TABLE table_name DROP COLUMN column_name;`

### 4.5 Add Index (Inline)

**Visual Representation:**
```
Click "+" button in index header or right-click → "Add Index":
┌──────┬─────────┬──────────┬─────────┬──────┬────────────┐
│  #   │ Name    │ Type     │ Columns │ Unique│ Condition  │
├──────┼─────────┼──────────┼─────────┼──────┼────────────┤
│  1   │ pk_idx  │ btree    │ id      │ ☑    │ -          │
│  2   │ email_uq│ btree    │ email   │ ☑    │ -          │
├──────┼─────────┼──────────┼─────────┼──────┼────────────┤
│  +   │[new_idx]│[btree▼]  │[+col]   │ [☐]  │ [NULL]     │ ← new row
└──────┴─────────┴──────────┴─────────┴──────┴────────────┘
```

**User Interactions:**
1. Click "+" button in index table header OR right-click → "Add Index"
2. New row appears at bottom with editable cells
3. User fills in index properties inline:
   - Name: Text field (validated for uniqueness)
   - Type: Inline dropdown (btree, hash, gin, gist, etc.)
   - Columns: Click to add columns selector (multi-select with ASC/DESC)
   - Unique: Checkbox
   - Condition: Text field (WHERE clause)
4. Press Enter or click away to save new index
5. Press Escape to cancel add

**Workflow:**
1. User clicks add index button or context menu
2. New inline row appears with "+" indicator
3. User enters index name (validated for uniqueness)
4. User selects index type from inline dropdown
5. User adds columns via inline multi-select with sort direction
6. User sets unique, condition inline
7. On blur/enter, validation runs:
   - Index name is unique
   - At least one column selected
   - Columns exist in table
   - Index type supported by database
8. Pending change added to tracker
9. New index shown with "new" indicator (green dot/plus)

**API Integration:**
- No API call during add (tracked locally)
- SQL generated on save: `CREATE [UNIQUE] INDEX index_name ON table_name (column1 ASC, column2 DESC) [WHERE condition] [INCLUDE (col1, col2)];`

### 4.6 Delete Index

**Visual Representation:**
Right-click context menu on index row:
```
┌─────────────────┐
│ Delete Index   │
└─────────────────┘
```

**Confirmation Dialog:**
```
┌─────────────────────────────────────────┐
│ Delete Index "idx_users_email"?      │
│                                   │
│ This will remove the index from the  │
│ database. Performance may be affected │
│ for queries using this index.        │
│                                   │
│  [Cancel]        [Delete]         │
└─────────────────────────────────────────┘
```

**User Interactions:**
1. Right-click on index row
2. Select "Delete Index"
3. Confirmation dialog appears
4. User confirms deletion

**Workflow:**
1. User right-clicks index
2. Context menu shows delete option
3. On delete click:
   - Check if index is primary key
   - If PK, show warning: "Cannot drop primary key index"
   - If not PK, show confirmation
4. User confirms
5. Index marked for deletion with strike-through and red indicator
6. Change tracked

**Safety Checks:**
- Cannot drop primary key indexes (must be handled via column PK removal)
- Warn about performance impact

**API Integration:**
- No API call during delete (tracked locally)
- SQL generated on save: `DROP INDEX index_name;`

### 4.7 Save Changes

**Visual Representation:**
Action bar with pending changes indicator:
```
┌────────────────────────────────────────────────┐
│ 5 Columns  │ [Refresh] │ [◀ Undo] │ [Save Changes (3)] │
└────────────────────────────────────────────────┘
                                    ↑
                           Shows count of pending changes
```

**Save Flow:**
```
User clicks "Save Changes" OR presses Cmd+S
       ↓
Validate all pending changes
       ↓
Generate SQL statements
       ↓
Execute in transaction
       ↓
Success? → Refresh schema
       ↓
Clear modification tracker
```

**User Interactions:**
1. User clicks "Save Changes" button (shows pending count) OR presses Cmd+S
2. Progress indicator appears
3. Changes are applied to database
4. Success notification or error message
5. Schema refreshes with updated state

**Workflow:**
1. User clicks save button or presses Cmd+S
2. System validates all pending changes:
   - Column names are unique
   - No constraint conflicts
   - Index names are unique
   - All types are valid
3. If validation fails, show error dialog
4. If valid, start transaction
5. Execute SQL statements in dependency order:
   - Drop constraints first
   - Drop columns/indexes
   - Add columns
   - Add constraints
   - Add indexes
6. If any statement fails, rollback transaction
7. If all succeed, commit transaction
8. Refresh schema from database
9. Clear modification tracker
10. Show success toast

**Error Handling:**
- Rollback transaction on any failure
- Show specific error message (e.g., "Column 'email' already has index")
- Allow user to retry or cancel

**API Integration:**
- Execute SQL via `DatabaseDriver.executeRawQuery()`
- Use transaction: `BEGIN; ... SQL statements ...; COMMIT;`

### 4.8 Undo/Cancel Modifications

**Visual Representation:**
```
[◀ Undo] button in action bar
[Cancel] button to discard all changes
```

**User Interactions:**
1. Click "Undo" to revert last change
2. Click "Cancel" to discard all pending changes
3. Confirmation dialog for cancel

**Workflow:**

**Undo:**
1. User clicks undo button
2. Most recent modification is reverted
3. Visual indicators update
4. Can undo multiple times

**Cancel All:**
1. User clicks cancel button
2. Confirmation dialog: "Discard all pending changes?"
3. If confirmed, clear modification tracker
4. Reload original schema data

**API Integration:**
- No API calls (client-side only)
- Uses modification history from tracker

### 4.9 Visual Indicators for Pending Changes

**Visual Representation:**
```
Columns table with pending indicators:
┌──────┬─────────┬──────────┬─────────┬──────┬────────────┐
│  #   │ Name    │ Type     │ Default │ Null │ Constraints │
├──────┼─────────┼──────────┼─────────┼──────┼────────────┤
│  1   │ id      │ INTEGER  │         │ ☐    │ PK         │
│  2   │ name    │ VARCHAR* │ [new]   │ ☑    │ -          │ ← edited
│  3   │ email   │ VARCHAR  │         │ ☑    │ UNIQUE     │
│  4   │ ~age~  │ INTEGER  │         │ ☐    │ -          │ ← deleted
│  5   │ +status │ TEXT     │         │ ☑    │ -          │ ← new
└──────┴─────────┴──────────┴─────────┴──────┴────────────┘
      ↑         ↑                                      ↑
   Blue dot  Strike-through + red              Green dot + plus
   (edited)  text (deleted)                    (new)
```

**User Interactions:**
- Visual indicators show pending state
- Hover shows tooltip with pending change details
- Click can show diff between original and new value

## 5. API Integration

### 5.1 DatabaseDriver Protocol Extensions

New methods to add to `DatabaseDriver` protocol:

```swift
protocol DatabaseDriver {
    // Existing methods...
    
    // Schema modification methods
    func addColumn(
        to tableName: String,
        schema: String?,
        column: DatabaseSchemaInfo
    ) async throws
    
    func modifyColumn(
        in tableName: String,
        schema: String?,
        columnName: String,
        newColumn: DatabaseSchemaInfo
    ) async throws
    
    func dropColumn(
        from tableName: String,
        schema: String?,
        columnName: String
    ) async throws
    
    func createIndex(
        on tableName: String,
        schema: String?,
        index: DatabaseIndexInfo
    ) async throws
    
    func dropIndex(
        indexName: String,
        tableName: String,
        schema: String?
    ) async throws
}
```

### 5.2 API Endpoints (PostgreSQL Driver)

**Add Column**
- **Method**: Execute raw SQL
- **SQL**: `ALTER TABLE {schema}.{table} ADD COLUMN {column_name} {data_type} [NOT NULL] [DEFAULT {default_value}]`
- **Request**: `DatabaseSchemaInfo` object
- **Response**: Success or error
- **Error Handling**: Catch unique constraint, type mismatch, invalid default

**Modify Column**
- **Method**: Execute raw SQL
- **SQL**: `ALTER TABLE {schema}.{table} ALTER COLUMN {column_name} TYPE {new_type}`
- **Additional**: `ALTER TABLE ... ALTER COLUMN ... SET DEFAULT ...` / `DROP DEFAULT`
- **Additional**: `ALTER TABLE ... ALTER COLUMN ... SET NOT NULL` / `DROP NOT NULL`
- **Request**: Column name, new `DatabaseSchemaInfo`
- **Response**: Success or error
- **Error Handling**: Catch type conversion errors, constraint violations

**Drop Column**
- **Method**: Execute raw SQL
- **SQL**: `ALTER TABLE {schema}.{table} DROP COLUMN {column_name} CASCADE`
- **Request**: Column name
- **Response**: Success or error
- **Error Handling**: Cascade warnings, constraint errors

**Create Index**
- **Method**: Execute raw SQL
- **SQL**: `CREATE [UNIQUE] INDEX {index_name} ON {schema}.{table} ({columns} [ASC|DESC]) [WHERE {condition}] [INCLUDE ({columns})]`
- **Request**: `DatabaseIndexInfo` object
- **Response**: Success or error
- **Error Handling**: Duplicate index, invalid columns, type mismatch

**Drop Index**
- **Method**: Execute raw SQL
- **SQL**: `DROP INDEX IF EXISTS {schema}.{index_name}`
- **Request**: Index name
- **Response**: Success or error
- **Error Handling**: Index not found (handled with IF EXISTS)

### 5.3 TypeScript Interfaces (for future web version)

```typescript
interface SchemaModification {
    type: 'addColumn' | 'modifyColumn' | 'dropColumn' | 'createIndex' | 'dropIndex';
    tableName: string;
    schemaName?: string;
    timestamp: Date;
}

interface ColumnModification extends SchemaModification {
    type: 'addColumn' | 'modifyColumn' | 'dropColumn';
    columnName?: string;
    column: DatabaseSchemaInfo;
    originalColumn?: DatabaseSchemaInfo; // For modify
}

interface IndexModification extends SchemaModification {
    type: 'createIndex' | 'dropIndex';
    indexName?: string;
    index: DatabaseIndexInfo;
}

interface SchemaModificationRequest {
    modifications: SchemaModification[];
    executeInTransaction: boolean;
}
```

### 5.4 Error Handling

**Common Error Types:**
```swift
enum SchemaModificationError: Error {
    case columnAlreadyExists(String)
    case columnNotFound(String)
    case columnHasConstraints(String, [String])
    case invalidColumnName(String)
    case invalidDataType(String)
    case indexAlreadyExists(String)
    case indexNotFound(String)
    case invalidIndexDefinition(String)
    case constraintViolation(String)
    case transactionFailed(String)
    case permissionDenied(String)
}
```

**Error Response Format:**
```swift
struct SchemaModificationResult {
    let success: Bool
    let errors: [SchemaModificationError]
    let succeededModifications: [SchemaModification]
    let failedModifications: [SchemaModification]
}
```

## 6. UI/UX Requirements

### 6.1 Loading States

**Initial Load:**
- Show spinner in split view areas
- Disable editing until schema loads
- Display "Loading schema..." message

**Save Operation:**
- Overlay with progress indicator
- Show "Saving changes..." with step indicator
  - Validating changes (1/5)
  - Executing modifications (2/5)
  - Refreshing schema (3/5)
- Dim background to prevent interaction

**Button Loading:**
- Save button shows spinner while saving
- Disable all buttons during save
- Prevent window closing during save

### 6.2 Error States

**Validation Errors (Real-time):**
- Red border around invalid fields
- Error tooltip on hover
- Inline error message below field
- Examples:
  - "Column name already exists"
  - "Invalid data type"
  - "Default value doesn't match type"

**Operation Errors (Dialogs):**
```
┌─────────────────────────────────────────┐
│ Error Saving Changes                 │
│                                   │
│ Failed to add column 'email':       │
│ Column 'email' already exists.      │
│                                   │
│ [Retry]           [Cancel]        │
└─────────────────────────────────────────┘
```

**Empty States:**
- No columns: "No columns in table - add one to get started"
- No indexes: "No indexes defined - improve query performance by adding indexes"

### 6.3 Success Feedback

**Toast Notification:**
```
┌──────────────────────────┐
│ ✓ Changes saved        │
│ 3 modifications applied │
└──────────────────────────┘
  (auto-dismiss after 3s)
```

**Visual Feedback:**
- Save button changes to green checkmark briefly
- Success sound (optional, user-configurable)

### 6.4 Keyboard Handling

**Global Shortcuts:**
- `Cmd + S`: Save changes (when hasModifications)
- `Cmd + Z`: Undo last modification
- `Cmd + Shift + Z`: Redo (if implementing redo)
- `Cmd + .`: Cancel all modifications
- `Escape`: Cancel current edit/close inline editor

**Table Shortcuts:**
- `Enter`: Confirm cell edit / Move to next cell
- `Tab`: Move to next cell
- `Shift + Tab`: Move to previous cell
- `Delete` / `Backspace`: Delete selected row (with confirmation)
- `Space`: Toggle checkbox
- `+`: Add new column/index (when table has focus)

**Double-Click Editing:**
- Double-click any cell to start editing immediately
- No mode switching required

### 6.5 Accessibility Requirements

**Screen Reader Labels:**
- Column names: "Column name, name value, double-click to edit"
- Type dropdown: "Data type, current value VARCHAR, double-click to change"
- Nullable checkbox: "Nullable, checked, column allows null values, double-click to toggle"
- Pending indicator: "Column name, edited, double-click to see changes"
- Delete button: "Delete column name, this action cannot be undone"

**Touch Target Sizes:**
- Edit button: 44x44 points minimum
- Add button: 44x44 points minimum
- Row selection: Full row height (28 points) with padding
- Checkbox: 22x22 points with 10 point padding

**Contrast Requirements:**
- Text: Minimum 4.5:1 contrast ratio
- Active states: 3:1 contrast ratio
- Error indicators: Use system colors with WCAG AA compliance

**Dynamic Type Support:**
- Respect user's font size settings
- Table rows expand with larger fonts
- Maintain minimum touch targets even at large sizes
- Truncate text with ellipsis when needed

**VoiceOver Navigation:**
- Logical order: Table header → Rows → Cells → Actions
- Status announcements: "3 changes pending", "Changes saved"
- Focus management: Return focus to table after inline editor closes

## 7. Data Flow Diagrams

### 7.1 User Action Flow - Double-Click Edit

```
User double-clicks cell
       ↓
NSTableViewDelegate.doubleClickAction
       ↓
Cell enters edit mode
       ↓
User modifies value
       ↓
NSTextFieldDelegate.textDidChange
       ↓
Call SchemaModificationTracker.trackColumnEdit()
       ↓
Update internal state
       ↓
Tracker.publishChange()
       ↓
UI updates:
       ├─ Show pending indicator
       ├─ Update save button count
       └─ Enable save button
```

### 7.2 User Action Flow - Add Column Inline

```
User clicks "+" button OR right-click → "Add Column"
       ↓
Create new inline row
       ↓
Row appears with editable cells
       ↓
User fills in properties
       ↓
User presses Enter or clicks away
       ↓
Validate input
       ├─ Invalid → Show error, keep row in edit mode
       └─ Valid ↓
Create ColumnModification
       ↓
Add to SchemaModificationTracker
       ↓
Update UI (show new row with indicator)
       ↓
Enable "Save Changes" button
```

### 7.3 Save Flow

```
User clicks "Save Changes" OR presses Cmd+S
       ↓
Get all modifications from tracker
       ↓
Validate dependencies
       ├─ Invalid → Show error, abort
       └─ Valid ↓
Begin database transaction
       ↓
For each modification:
       ├─ Generate SQL
       ├─ Execute SQL
       ├─ Error? → Rollback, show error
       └─ Success? → Continue
       ↓
All successful?
       ├─ No → Rollback, show partial results
       └─ Yes ↓
Commit transaction
       ↓
Refresh schema from database
       ↓
Clear modification tracker
       ↓
Show success toast
```

### 7.4 State Update Flow

```
User edits cell (double-click)
       ↓
NSTextFieldDelegate.textDidChange
       ↓
Call SchemaModificationTracker.trackColumnEdit()
       ↓
Update internal state
       ↓
Tracker.publishChange()
       ↓
UI updates:
       ├─ Show pending indicator
       ├─ Update save button count
       └─ Enable save button
```

### 7.5 Error Handling Flow

```
Operation fails
       ↓
Catch DatabaseError
       ↓
Determine error type
       ├─ Validation error → Show inline error
       ├─ Permission error → Show error dialog
       ├─ Constraint error → Show specific message
       └─ Unknown error → Show generic error
       ↓
Rollback transaction (if in progress)
       ↓
Restore UI state
       ↓
Show error dialog with retry option
```

## 8. Implementation Checklist

### Phase 1: Foundation (Week 1)

**Deliverables:**
- Extended `DatabaseDriver` protocol with schema methods
- `SchemaModificationTracker` class
- Basic UI scaffolding for inline editing

**Tasks:**
- [ ] Add schema modification methods to `DatabaseDriver` protocol
- [ ] Create `SchemaModificationTracker` class (adapt from `TableModificationTracker`)
- [ ] Create `ColumnModification` and `IndexModification` structs
- [ ] Add pending changes counter to action bar
- [ ] Add "Save" and "Cancel" buttons to action bar (initially disabled)
- [ ] Add "+" buttons to table headers
- [ ] Implement right-click context menus for tables

### Phase 2: Double-Click Editing (Week 1-2)

**Deliverables:**
- Double-click to edit functionality
- Inline editing for all cell types

**Tasks:**
- [ ] Implement double-click detection in table coordinators
- [ ] Add inline text editing for name/default cells
- [ ] Add inline dropdown for type cells
- [ ] Add inline checkbox for nullable cells
- [ ] Add inline constraint editor
- [ ] Implement validation for inline edits
- [ ] Add visual indicators for edited cells
- [ ] Implement Enter/Escape key handling for inline edits

### Phase 3: Column Operations (Week 2-3)

**Deliverables:**
- Add column inline functionality
- Delete column with safety checks

**Tasks:**
- [ ] Implement inline add column row
- [ ] Add column name uniqueness check
- [ ] Implement data type dropdown with database-specific types
- [ ] Add nullable checkbox for new columns
- [ ] Add default value text field with type validation
- [ ] Add constraint checkboxes (PK, unique, auto increment)
- [ ] Implement "Add Column" workflow
- [ ] Add visual indicators for new columns
- [ ] Implement right-click context menu for columns
- [ ] Implement "Delete Column" workflow
- [ ] Add safety checks (constraints, references)
- [ ] Add confirmation dialog for deletion
- [ ] Add visual indicators for deleted columns

### Phase 4: Index Operations (Week 3-4)

**Deliverables:**
- Add index inline functionality
- Delete index with warnings

**Tasks:**
- [ ] Implement inline add index row
- [ ] Add inline column selector for index
- [ ] Add sort direction (ASC/DESC) per column
- [ ] Implement index type dropdown
- [ ] Add unique checkbox
- [ ] Add condition (WHERE clause) text field
- [ ] Add include columns selector
- [ ] Implement "Add Index" workflow
- [ ] Add visual indicators for new indexes
- [ ] Implement right-click context menu for indexes
- [ ] Implement "Delete Index" workflow
- [ ] Add confirmation dialog
- [ ] Add visual indicators for deleted indexes

### Phase 5: PostgreSQL Driver Implementation (Week 4-5)

**Deliverables:**
- Full PostgreSQL schema modification support
- SQL generation for all operations

**Tasks:**
- [ ] Implement `addColumn()` in `PostgreSQLDriver`
- [ ] Implement `modifyColumn()` in `PostgreSQLDriver`
- [ ] Implement `dropColumn()` in `PostgreSQLDriver`
- [ ] Implement `createIndex()` in `PostgreSQLDriver`
- [ ] Implement `dropIndex()` in `PostgreSQLDriver`
- [ ] Add SQL generation utilities
- [ ] Test all operations with sample tables
- [ ] Add error handling specific to PostgreSQL

### Phase 6: Save and Validation (Week 5-6)

**Deliverables:**
- Complete save workflow
- Transaction support
- Comprehensive validation

**Tasks:**
- [ ] Implement modification validation logic
- [ ] Check for duplicate column names
- [ ] Check for constraint conflicts
- [ ] Check for duplicate index names
- [ ] Implement transaction management
- [ ] Add step-by-step progress indicator
- [ ] Implement error rollback
- [ ] Add schema refresh after save
- [ ] Clear modification tracker after successful save
- [ ] Show success toast notification
- [ ] Handle partial failures

### Phase 7: Undo/Cancel (Week 6)

**Deliverables:**
- Undo functionality
- Cancel all modifications

**Tasks:**
- [ ] Implement modification history in tracker
- [ ] Add undo button to action bar
- [ ] Implement undo logic
- [ ] Add cancel button to action bar
- [ ] Implement cancel all confirmation dialog
- [ ] Clear tracker on cancel
- [ ] Reload original schema data

### Phase 8: Keyboard Shortcuts (Week 6)

**Deliverables:**
- Complete keyboard support
- Cmd+S save functionality

**Tasks:**
- [ ] Implement Cmd+S save shortcut
- [ ] Implement Cmd+Z undo shortcut
- [ ] Implement Cmd+. cancel shortcut
- [ ] Implement Escape key for canceling edits
- [ ] Implement Enter key for confirming edits
- [ ] Implement Tab navigation between cells
- [ ] Implement + key for adding new rows

### Phase 9: Polish and UX (Week 6-7)

**Deliverables:**
- Complete UX polish
- Accessibility support
- Animations and transitions

**Tasks:**
- [ ] Implement loading states
- [ ] Add error dialogs
- [ ] Add success notifications
- [ ] Add screen reader labels
- [ ] Adjust contrast ratios
- [ ] Test dynamic type support
- [ ] Add tooltips
- [ ] Implement hover states
- [ ] Add animations for state transitions
- [ ] Add visual feedback for pending changes

### Phase 10: Testing (Week 7)

**Deliverables:**
- Comprehensive test coverage
- Bug fixes

**Tasks:**
- [ ] Test double-click editing for all cell types
- [ ] Test add column with all data types
- [ ] Test edit column properties
- [ ] Test delete column with various constraints
- [ ] Test add index with various configurations
- [ ] Test delete index
- [ ] Test save workflow with multiple changes
- [ ] Test Cmd+S save shortcut
- [ ] Test error handling
- [ ] Test undo functionality
- [ ] Test cancel functionality
- [ ] Performance testing with large tables
- [ ] Accessibility testing
- [ ] Bug fixes

## 9. Database Schema (Not Applicable)

**Note**: This feature modifies database schemas, so no new schema is required. The feature works with existing database structures.

## 10. API Endpoint Summary

| Method | Endpoint/Operation | Purpose | Auth Required |
|--------|------------------|----------|---------------|
| `addColumn()` | `ALTER TABLE ... ADD COLUMN` | Add new column to table | Yes (DB connection) |
| `modifyColumn()` | `ALTER TABLE ... ALTER COLUMN` | Modify existing column | Yes (DB connection) |
| `dropColumn()` | `ALTER TABLE ... DROP COLUMN` | Delete column from table | Yes (DB connection) |
| `createIndex()` | `CREATE INDEX ...` | Create new index | Yes (DB connection) |
| `dropIndex()` | `DROP INDEX ...` | Delete index | Yes (DB connection) |
| `executeRawQuery()` | `BEGIN/COMMIT/ROLLBACK` | Transaction management | Yes (DB connection) |
| `getSchema()` | Query information_schema | Refresh schema after changes | Yes (DB connection) |
| `getIndexes()` | Query pg_indexes | Refresh indexes after changes | Yes (DB connection) |

## 11. Design System Integration

### 11.1 Colors

**From existing design system:**
- **Primary action (Save)**: `Color.accentColor` or `.blue`
- **Destructive action (Delete)**: `.red`
- **Warning state**: `.orange`
- **Error state**: `.red`
- **Success state**: `.green`
- **Pending indicator**: `.blue` (small dot)
- **New item indicator**: `.green` (plus icon)
- **Deleted item indicator**: `.red` (strikethrough)

**Dark/Light Mode:**
- Use semantic colors: `.primary`, `.secondary`, `.tertiary`
- Adapt indicators for contrast in dark mode
- Use `Color(.separatorColor)` for borders

### 11.2 Typography

**From existing system:**
- **Table headers**: `NSFont.systemFont(ofSize: 12, weight: .regular)`
- **Cell content**: `NSFont.monospacedSystemFont(ofSize: 11-12, weight: .regular)`
- **Pending indicators**: System symbols (SF Symbols)
- **Inline dropdowns**: `.system(size: 11)`
- **Error messages**: `.system(size: 12, weight: .medium)`

### 11.3 Spacing Scale

**Based on existing patterns:**
- **Cell padding**: 8 points horizontal
- **Row height**: 28 points
- **Inline editor padding**: 4 points
- **Button padding**: `EdgeInsets(top: 7, leading: 8, bottom: 7, trailing: 8)`
- **Action bar spacing**: 5 points between buttons
- **Form field spacing**: 16 points vertical

### 11.4 Components to Reuse

**Existing components:**
- `ActionButtonStyle`: For save/cancel/undo buttons
- `FilterTextFieldStyle`: For inline text inputs
- `VisualEffectView`: For error dialog backgrounds
- `NSTableView` pattern: Existing coordinator pattern
- `SplitView`: Already used in schema mode

**New components needed:**
- `InlineTypeDropdown`: Dropdown for data type selection
- `InlineConstraintEditor`: Inline constraint configuration
- `PendingIndicatorView`: Visual indicator for modified items
- `ConfirmationDialog`: Standardized confirmation dialog component

## 12. Success Criteria

### 12.1 Functional Requirements

- [ ] Users can double-click any field to edit immediately
- [ ] Users can add new columns inline (no modal)
- [ ] Users can edit column name, type, nullable, default value inline
- [ ] Users can delete columns (with proper validation)
- [ ] Users can add indexes inline (no modal)
- [ ] Users can delete indexes (with confirmation)
- [ ] Pending changes are visually indicated
- [ ] Users can undo individual changes
- [ ] Users can cancel all pending changes
- [ ] Users can save changes via Cmd+S or save button
- [ ] Schema refreshes automatically after successful save
- [ ] Validation prevents invalid operations
- [ ] Safety checks prevent data loss
- [ ] Confirmation dialogs shown for destructive actions
- [ ] PostgreSQL driver implements all schema operations
- [ ] Operations execute in transactions
- [ ] Errors are properly handled and displayed

### 12.2 Non-Functional Requirements

**Performance:**
- [ ] Double-click to edit activates in < 50ms
- [ ] Cell edits update UI in < 50ms
- [ ] Save operations complete within 5 seconds for < 10 changes
- [ ] Schema refresh completes within 3 seconds
- [ ] UI remains responsive during save operations

**Accessibility:**
- [ ] All actions have screen reader labels
- [ ] Keyboard navigation works for all features
- [ ] Touch targets meet minimum size requirements
- [ ] Contrast ratios meet WCAG AA standards
- [ ] Dynamic type support is implemented
- [ ] VoiceOver navigation is logical

**Reliability:**
- [ ] No data loss during save failures
- [ ] Transactions properly roll back on errors
- [ ] Concurrent edits are prevented
- [ ] Permission errors are handled gracefully
- [ ] Network errors are retried or reported

**Security:**
- [ ] Write operations require database permissions
- [ ] SQL injection prevention (use parameterized queries)
- [ ] Sensitive data is not logged
- [ ] User permissions are validated

### 12.3 Testing Requirements

**Unit Tests:**
- [ ] `SchemaModificationTracker` tests
- [ ] Column modification validation tests
- [ ] Index modification validation tests
- [ ] SQL generation tests
- [ ] Transaction rollback tests

**Integration Tests:**
- [ ] PostgreSQL driver schema operation tests
- [ ] End-to-end add/edit/delete column tests
- [ ] End-to-end add/delete index tests
- [ ] Multi-change save workflow tests
- [ ] Error handling tests

**UI Tests:**
- [ ] Double-click editing tests
- [ ] Inline add column tests
- [ ] Form validation UI tests
- [ ] Keyboard shortcut tests
- [ ] Accessibility tests

**Manual Tests:**
- [ ] Test with various PostgreSQL versions
- [ ] Test with large tables (100+ columns)
- [ ] Test with complex constraints
- [ ] Test with special characters in names
- [ ] Test with concurrent users (if applicable)

### 12.4 Platform Support

- [ ] macOS 14.0+ (current minimum)
- [ ] Tested on Intel and Apple Silicon
- [ ] Dark mode support
- [ ] Light mode support
- [ ] High contrast mode support
- [ ] Reduced motion support (disable animations)

---

**End of PRD**