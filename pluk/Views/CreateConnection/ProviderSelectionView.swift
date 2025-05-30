//
//  ProviderSelectionView.swift
//  Pluk
//
//  Created by Fauzaan on 5/30/25.
//

import Foundation
import SwiftUI

struct ProviderSelectionView: View {
    @Binding var selectedProvider: DatabaseProvider?
    @State private var searchText = ""
    @State private var hoveredProvider: DatabaseProvider? = nil
    @Environment(\.dismiss) var dismiss
    
    var filteredProviders: [DatabaseProvider] {
        if searchText.isEmpty {
            return DatabaseProvider.allCases
        }
        return DatabaseProvider.allCases.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var groupedProviders: [(ProviderCategory, [DatabaseProvider])] {
        let grouped = Dictionary(grouping: filteredProviders) { $0.category }
        return ProviderCategory.allCases.compactMap { category in
            guard let providers = grouped[category], !providers.isEmpty else { return nil }
            return (category, providers)
        }
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                // Header Section
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Connect Your Database")
                            .font(.title)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("Choose from cloud-hosted solutions or connect to your existing database")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 16)
                    
                    // Modern Search Bar
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        TextField("Search providers", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 15))
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.2))
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.separatorColor).opacity(0.5), lineWidth: 1)
                    )
                    .cornerRadius(12)
                }
                .padding(.horizontal, 32)
                .padding(.top, 32)
                
                // Provider Grid
                ScrollView {
                    LazyVStack(spacing: 32) {
                        ForEach(groupedProviders, id: \.0) { category, providers in
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text(category.rawValue)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                        .tracking(1)
                                    
                                    Spacer()
                                }
                                
                                LazyVGrid(columns: [
                                    GridItem(.flexible(), spacing: 16),
                                    GridItem(.flexible(), spacing: 16)
                                ], spacing: 16) {
                                    ForEach(providers) { provider in
                                        ProviderCard(
                                            provider: provider,
                                            isSelected: selectedProvider == provider,
                                            isHovered: hoveredProvider == provider
                                        ) {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                selectedProvider = provider
                                            }
                                        }
                                        .onHover { isHovered in
                                            withAnimation(.easeInOut(duration: 0.15)) {
                                                hoveredProvider = isHovered ? provider : nil
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 24)
                }
            }
            .padding(.bottom, 32)
            
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(XMarkButtonStyle())
            .padding(.top, 16)
            .padding(.trailing, 16)
        }
    }
}

// MARK: - Provider Card
struct ProviderCard: View {
    let provider: DatabaseProvider
    let isSelected: Bool
    let isHovered: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    HStack {
                        // Provider icon and name
                        HStack(spacing: 12) {
                            Image(provider.icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 32, height: 32)
                                .scaleEffect(isHovered ? 1.05 : 1.0)
                                .animation(.easeInOut(duration: 0.15), value: isHovered)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 8) {
                                    Text(provider.displayName)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)
                                    
                                    // Inline status text
                                    if provider.status == .beta {
                                        Text("• \(statusText)")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(statusColor)
                                    }
                                }
                                
                                if provider.status == .comingSoon {
                                    Text("Comming Soon")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                    
                                }
                            }
                        }
                        
                        Spacer()
                    }
                }
                .padding(20)
            }
            .background(cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor)
                    .blendMode(.plusLighter)
            )
            .cornerRadius(16)
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                x: 0,
                y: shadowOffset
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(provider.status == .comingSoon)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
    
    private var statusColor: Color {
        switch provider.status {
        case .beta: return .orange
        default: return .clear
        }
    }
    
    private var statusText: String {
        switch provider.status {
        case .beta: return "Beta"
        case .comingSoon: return "Comming Soon"
        default: return ""
        }
    }
    
    private var cardBackground: Color {
        if isSelected {
            return Color(.controlColor)
        } else if isHovered {
            return Color(.controlColor).opacity(0.5)
        } else {
            return Color(.controlColor).opacity(0.1)
        }
    }
    
    private var borderColor: Color {
        if isSelected {
            return provider.accentColor
        } else if isHovered {
            return provider.accentColor
        } else {
            return Color(.separatorColor).opacity(0.5)
        }
    }
    
    private var borderWidth: CGFloat {
        isSelected ? 2 : 1
    }
    
    private var shadowColor: Color {
        if isSelected {
            return provider.accentColor.opacity(0.2)
        } else if isHovered {
            return Color.black.opacity(0.1)
        } else {
            return Color.clear
        }
    }
    
    private var shadowRadius: CGFloat {
        if isSelected {
            return 8
        } else if isHovered {
            return 4
        } else {
            return 0
        }
    }
    
    private var shadowOffset: CGFloat {
        isHovered || isSelected ? 2 : 0
    }
}
