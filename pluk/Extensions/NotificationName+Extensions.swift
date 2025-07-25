import Foundation

extension Notification.Name {
    static let didRequestDelete = Notification.Name("didRequestDelete")
    static let foreignKeyNavigationRequested = Notification.Name("ForeignKeyNavigationRequested")
    
    /// Table refresh naming
    static let tableRefresh = Notification.Name("tableRefresh")
    static let addNewRecord = Notification.Name("addNewRecord")
}
