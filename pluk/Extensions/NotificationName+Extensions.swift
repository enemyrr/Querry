import Foundation

extension Notification.Name {
    static let didRequestDelete = Notification.Name("didRequestDelete")
    static let didRequestCopy = Notification.Name("didRequestCopy")
    static let didRequestPaste = Notification.Name("didRequestPaste")
    static let markRowAsDeleted = Notification.Name("markRowAsDeleted")
    static let foreignKeyNavigationRequested = Notification.Name("ForeignKeyNavigationRequested")
    
    /// Table refresh naming
    static let tableRefresh = Notification.Name("tableRefresh")
    static let addNewRecord = Notification.Name("addNewRecord")
    
    /// Request an NSTableView-level reload without refetching data
    static let tableReloadData = Notification.Name("tableReloadData")

    /// Toggle the left sidebar in the main split view
    static let toggleLeftSidebar = Notification.Name("ToggleLeftSidebar")

    /// Toggle the right sidebar (row details)
    static let toggleRightSidebar = Notification.Name("ToggleRightSidebar")

    /// Tab change notification
    static let tabDidChange = Notification.Name("tabDidChange")

    /// Connection database updates
    static let databasesUpdated = Notification.Name("databasesUpdated")
    static let connectedDatabaseChanged = Notification.Name("connectedDatabaseChanged")
    static let toggleFilterBuilder = Notification.Name("ToggleFilterBuilder")

    /// Schema mode context menu actions
    static let schemaTableRefresh = Notification.Name("schemaTableRefresh")
    static let schemaAddColumn = Notification.Name("schemaAddColumn")
    static let indexTableRefresh = Notification.Name("indexTableRefresh")
    static let indexAddIndex = Notification.Name("indexAddIndex")

    /// Quick Look popover
    static let cellQuickLookRequested = Notification.Name("cellQuickLookRequested")
}
