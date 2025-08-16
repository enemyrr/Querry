//
//  SQLiteFieldsView.swift
//  Pluk
//
//  Created by Fauzaan on 8/16/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct SQLiteFieldsView: View {
    @Binding var filePath: String
    @State private var showFileImporter = false
    
    private var displayText: String {
        if filePath.isEmpty {
            return "No file selected - use Browse button to select SQLite database"
        } else if filePath.hasPrefix("bookmark:"),
                  let (_, path) = BookmarkManager.shared.decodeBookmark(filePath) {
            return URL(fileURLWithPath: path).relativePath
        } else {
            return URL(fileURLWithPath: filePath).lastPathComponent
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Database Config")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            
            VStack(spacing: 12) {
                FormField(label: "File Path") {
                    if filePath.isEmpty {
                        // Phase 1: No file selected - show center-aligned select button
                        Button(action: {
                            showFileImporter = true
                        }) {
                            VStack(spacing: 8) {
                                VStack(spacing: 4) {
                                    Text("Select File")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text("Choose a .db, .sqlite, or .sqlite3 file")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                            }
                        }
                        .fileSelectionStyle()
                    } else {
                        // Phase 2: File selected - show file details with change button
                        HStack(spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "externaldrive.fill")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                Text(displayText)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(.controlColor).opacity(0.05))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(.separator.opacity(0.5), lineWidth: 1)
                            )
                            
                            Button("Change") {
                                showFileImporter = true
                            }
                            .fileChangeStyle()
                        }
                    }
                }
            }
            .padding(16)
            .background(Color(.controlColor).opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.separator, lineWidth: 1)
            )
            .cornerRadius(16)
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.database, .item],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    print("📂 Selected file: \(url.path)")
                    
                    // CRITICAL: Start accessing security-scoped resource immediately
                    guard url.startAccessingSecurityScopedResource() else {
                        print("❌ Failed to start accessing security-scoped resource")
                        filePath = url.path
                        return
                    }
                    
                    print("🔓 Successfully started accessing security-scoped resource")
                    
                    // Now check file accessibility with security scope active
                    print("📏 File exists: \(FileManager.default.fileExists(atPath: url.path))")
                    print("📖 Readable: \(FileManager.default.isReadableFile(atPath: url.path))")
                    print("✏️ Writable: \(FileManager.default.isWritableFile(atPath: url.path))")
                    
                    do {
                        // Try to access the file content
                        let _ = try Data(contentsOf: url)
                        print("✅ File content is accessible")
                        
                        // Create security-scoped bookmark while we have access
                        let bookmarkData = try url.bookmarkData(
                            options: [.withSecurityScope],
                            includingResourceValuesForKeys: nil,
                            relativeTo: nil
                        )
                        
                        // Stop accessing for now - we'll restart when needed
                        url.stopAccessingSecurityScopedResource()
                        
                        // Encode bookmark with path for storage
                        filePath = BookmarkManager.shared.encodeBookmark(bookmarkData, withPath: url.path)
                        
                        print("✅ Successfully created security-scoped bookmark for: \(url.path)")
                    } catch {
                        // Stop accessing on error
                        url.stopAccessingSecurityScopedResource()
                        print("⚠️ Failed to create bookmark, using direct path: \(error)")
                        print("📋 Error details: \(String(reflecting: error))")
                        
                        // Still store the path, but warn user
                        filePath = url.path
                        
                        // In a real implementation, you might want to show an alert here
                        // explaining that the file can be used now but may not be accessible
                        // after the app restarts unless they use the Browse button again
                    }
                }
            case .failure(let error):
                print("❌ Error selecting file: \(error)")
            }
        }
    }
}
