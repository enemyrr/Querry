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
    @State private var showBookmarkError = false
    @State private var bookmarkErrorMessage = ""
    @State private var showNoSQLiteFilesError = false
    @State private var showWALModeWarning = false
    
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
                                    .truncationMode(.middle)
                                    .lineLimit(1)
                                
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
            allowedContentTypes: [.database, .item, .folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    debugLog("📂 Selected file: \(url.path)")
                    
                    // CRITICAL: Start accessing security-scoped resource immediately
                    guard url.startAccessingSecurityScopedResource() else {
                        debugLog("❌ Failed to start accessing security-scoped resource")
                        filePath = url.path
                        return
                    }
                    
                    debugLog("🔓 Successfully started accessing security-scoped resource")
                    
                    // Check if the selected item is a directory
                    var isDirectory: ObjCBool = false
                    FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
                    
                    let finalURL: URL
                    if isDirectory.boolValue {
                        debugLog("📁 Directory selected, searching for SQLite files...")
                        
                        // Search for SQLite files in the directory
                        do {
                            if let sqliteFileURL = try findFirstSQLiteFileInDirectory(url) {
                                debugLog("📁 Found SQLite file in directory: \(sqliteFileURL.lastPathComponent)")
                                finalURL = sqliteFileURL
                            } else {
                                url.stopAccessingSecurityScopedResource()
                                debugLog("❌ No SQLite files found in the selected folder")
                                showNoSQLiteFilesError = true
                                return
                            }
                        } catch {
                            url.stopAccessingSecurityScopedResource()
                            debugLog("❌ Error searching directory: \(error)")
                            return
                        }
                    } else {
                        // It's a file, check if it's in WAL mode
                        if SQLiteWALDetector.isInWALMode(at: url) {
                            url.stopAccessingSecurityScopedResource()
                            debugLog("⚠️ SQLite file is in WAL mode, user should select directory")
                            showWALModeWarning = true
                            return
                        }
                        finalURL = url
                    }
                    
                    // Now check file accessibility with security scope active
                    debugLog("📏 File exists: \(FileManager.default.fileExists(atPath: finalURL.path))")
                    debugLog("📖 Readable: \(FileManager.default.isReadableFile(atPath: finalURL.path))")
                    debugLog("✏️ Writable: \(FileManager.default.isWritableFile(atPath: finalURL.path))")
                    
                    do {
                        // Try to access the file content
                        let _ = try Data(contentsOf: finalURL)
                        debugLog("✅ File content is accessible")
                        
                        // Create security-scoped bookmark for the original directory (to maintain access)
                        // but store the path to the specific SQLite file found
                        let bookmarkData = try url.bookmarkData(
                            options: [.withSecurityScope],
                            includingResourceValuesForKeys: nil,
                            relativeTo: nil
                        )
                        
                        // Stop accessing for now - we'll restart when needed
                        url.stopAccessingSecurityScopedResource()
                        
                        // Store the bookmark with the SQLite file path
                        filePath = BookmarkManager.shared.encodeBookmark(bookmarkData, withPath: finalURL.path)
                        
                        debugLog("✅ Successfully created security-scoped bookmark for: \(finalURL.path)")
                    } catch {
                        // Stop accessing on error
                        url.stopAccessingSecurityScopedResource()
                        debugLog("⚠️ Failed to create bookmark: \(error)")
                        debugLog("📋 Error details: \(String(reflecting: error))")
                        
                        // Show user-friendly error message
                        bookmarkErrorMessage = """
                        Unable to save file access permissions.
                        
                        The selected file can be used now, but you may need to select it again after restarting the app.
                        
                        Error: \(error.localizedDescription)
                        """
                        showBookmarkError = true
                        
                        // Store the path anyway for current session use
                        filePath = finalURL.path
                    }
                }
            case .failure(let error):
                print("❌ Error selecting file: \(error)")
            }
        }
        .alert("File Access Warning", isPresented: $showBookmarkError) {
            Button("OK") { }
        } message: {
            Text(bookmarkErrorMessage)
        }
        .alert("No SQLite Files Found", isPresented: $showNoSQLiteFilesError) {
            Button("OK") { }
        } message: {
            Text("No SQLite database files were found in the selected folder.\n\nPlease select a folder containing .db, .sqlite, or .sqlite3 files, or choose a specific database file instead.")
        }
        .alert("This Database Uses WAL Mode", isPresented: $showWALModeWarning) {
            Button("Select Folder Instead") {
                showFileImporter = true
            }
            Button("Cancel") { }
        } message: {
            Text("""
             This database is using Write-Ahead Logging (WAL) mode. 
             To work properly, it requires access to additional files (*.wal, *.shm).

             Please select the folder that contains this database, rather than the file itself, so all related files can be accessed.
             """)
        }
    }
    
    // MARK: - Helper Methods
    
    private func findFirstSQLiteFileInDirectory(_ directoryURL: URL) throws -> URL? {
        let fileManager = FileManager.default
        
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else {
            return nil
        }
        
        // Define SQLite file extensions to look for
        let sqliteExtensions = ["db", "sqlite", "sqlite3"]
        var walModeFiles: [URL] = []
        
        // First, look for files with standard SQLite extensions (prefer non-WAL)
        for fileURL in contents {
            let fileExtension = fileURL.pathExtension.lowercased()
            if sqliteExtensions.contains(fileExtension) {
                // Check if it's a file (not a directory)
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey]),
                   let isDirectory = resourceValues.isDirectory, !isDirectory {
                    // Basic SQLite file validation - check if file starts with "SQLite format 3"
                    if isSQLiteFile(at: fileURL) {
                        if SQLiteWALDetector.isInWALMode(at: fileURL) {
                            // Store WAL mode files as fallback
                            walModeFiles.append(fileURL)
                        } else {
                            // Return first non-WAL file found
                            return fileURL
                        }
                    }
                }
            }
        }
        
        // If no files with standard extensions found, look for files without extensions (prefer non-WAL)
        for fileURL in contents {
            let fileExtension = fileURL.pathExtension
            if fileExtension.isEmpty {
                // Check if it's a file (not a directory)
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey]),
                   let isDirectory = resourceValues.isDirectory, !isDirectory {
                    // Check if it's a SQLite file by examining its header
                    if isSQLiteFile(at: fileURL) {
                        if SQLiteWALDetector.isInWALMode(at: fileURL) {
                            // Store WAL mode files as fallback
                            walModeFiles.append(fileURL)
                        } else {
                            // Return first non-WAL file found
                            return fileURL
                        }
                    }
                }
            }
        }
        
        // If only WAL mode files found, return the first one
        return walModeFiles.first
    }
    
    private func isSQLiteFile(at url: URL) -> Bool {
        guard let fileData = try? Data(contentsOf: url) else {
            return false
        }
        
        // SQLite files start with "SQLite format 3\0" (16 bytes)
        let sqliteHeader = "SQLite format 3\0".data(using: .utf8)!
        
        if fileData.count >= sqliteHeader.count {
            let headerData = fileData.prefix(sqliteHeader.count)
            return headerData == sqliteHeader
        }
        
        return false
    }
}
