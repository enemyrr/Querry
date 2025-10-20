import Foundation

extension Notification.Name {
    static let didRequestDelete = Notification.Name("didRequestDelete")
    static let foreignKeyNavigationRequested = Notification.Name("ForeignKeyNavigationRequested")
    
    /// Table refresh naming
    static let tableRefresh = Notification.Name("tableRefresh")
    static let addNewRecord = Notification.Name("addNewRecord")
    
    /// Request an NSTableView-level reload without refetching data
    static let tableReloadData = Notification.Name("tableReloadData")

    /// Collapse the primary sidebar in the main split view
    static let collapseSidebar = Notification.Name("CollapseSidebar")

    /// Tab change notification
    static let tabDidChange = Notification.Name("tabDidChange")

    /// Connection database updates
    static let databasesUpdated = Notification.Name("databasesUpdated")
    static let connectedDatabaseChanged = Notification.Name("connectedDatabaseChanged")
    static let toggleFilterBuilder = Notification.Name("ToggleFilterBuilder")
}
