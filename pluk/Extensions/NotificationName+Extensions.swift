//
//  NotificationName+Extensions.swift
//  Pluk
//
//  Created by Claude on 6/14/25.
//

import Foundation

extension Notification.Name {
    static let tabSwitched = Notification.Name("tabSwitched")
    static let tabCreated = Notification.Name("tabCreated")
    static let tabClosed = Notification.Name("tabClosed")
}