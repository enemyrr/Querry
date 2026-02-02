//
//  AppViewModel.swift
//  Pluk
//

import SwiftUI
import Observation

@MainActor @Observable
final class AppViewModel {
    var isRightSidebarVisible = false
    var rightSidebarWidth: CGFloat = 300
}
