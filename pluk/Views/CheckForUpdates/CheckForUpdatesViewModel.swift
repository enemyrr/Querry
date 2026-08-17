//
//  CheckForUpdatesViewModel.swift
//  Pluk
//
//  Created by Fauzaan on 4/23/25.
//

import SwiftUI
import Sparkle
import Combine

@MainActor
final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false
    private var cancellable: AnyCancellable?

    init(updater: SPUUpdater) {
        cancellable = updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.canCheckForUpdates = value
            }
    }
}
