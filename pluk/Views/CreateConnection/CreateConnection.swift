//
//  CreateConnection.swift
//  Collection
//
//  Created by Fauzaan on 1/31/25.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import MongoKitten
import MongoCore
import SwiftData
import Foundation
import MongoCore
import WebKit

struct CreateConnection: View {
    @Binding var showSheet: Bool
    
    var body: some View {
        Button(action: {
            showSheet.toggle()
        }) {
            Image(systemName: "plus.circle").font(.title3).foregroundStyle(.secondary)
        }
        .buttonStyle(ActionButtonStyle())
        .sheet(isPresented: $showSheet) {
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                    .ignoresSafeArea()
                CreateConnectionForm()
                    .frame(width: 560)
                
            }
        }
    }
    
}


// MARK: - Cloud Database Web View
struct CloudDatabaseWebView: NSViewRepresentable {
    let databaseType: DatabaseType
    @Binding var isLoading: Bool
    @Environment(\.dismiss) var dismiss
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        guard let url = getDatabaseTypeURL() else { return }
        let request = URLRequest(url: url)
        nsView.load(request)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func getDatabaseTypeURL() -> URL? {
        switch databaseType {
        case .supabase:
            return URL(string: "https://supabase.com/dashboard")
        case .neon:
            return URL(string: "https://console.neon.tech")
        default:
            return nil
        }
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: CloudDatabaseWebView
        
        init(_ parent: CloudDatabaseWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }
    }
}

// MARK: - Enhanced CreateConnectionForm
struct CreateConnectionForm: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedDatabaseType: DatabaseType? = nil
    @State private var uri = ""
    @State private var name = ""
    @State private var defaultDatabase = ""
    @State private var color: Optional<ConnectionColor> = nil
    @State private var selectedEnvironment: ConnectionEnvironment = .local
    @State private var uriError: String? = nil
    @State private var showDatabaseField = false
    @State private var isWebViewLoading = false
    @FocusState private var uriFieldIsFocused: Bool
    @FocusState private var nameFieldIsFocused: Bool
    
    // Field-based connection parameters
    @State private var useFieldBasedInput = true
    @State private var hostname = ""
    @State private var port = ""
    @State private var username = ""
    @State private var password = ""
    @State private var sslMode = "prefer"
    
    // URI import
    @State private var showURIImportSheet = false
    @State private var uriToImport = ""
    
    private let connection: Connection?
    private let onDisconnect: (() async -> Void)?
    
    @Environment(SidebarViewModel.self) private var sidebarViewModel
    
    init(connection: Connection? = nil, onDisconnect: (() async -> Void)? = nil) {
        self.connection = connection
        self.onDisconnect = onDisconnect
        _color = State(initialValue: .blue)
    }
    
    private var isFormValid: Bool {
        guard let databaseType = selectedDatabaseType else { return false }
        
        if databaseType.category == .cloud {
            return !name.isEmpty
        }
        
        if useFieldBasedInput && (databaseType == .postgres || databaseType == .supabase || databaseType == .neon) {
            return !name.isEmpty &&
                   !hostname.isEmpty &&
                   !port.isEmpty &&
                   !username.isEmpty
        }
        
        return !uri.isEmpty &&
        !name.isEmpty &&
        uriError == nil
    }
    
    private func validateConnectionString(_ uri: String, for databaseType: DatabaseType) {
        guard !uri.isEmpty else {
            uriError = nil
            return
        }
        
        switch databaseType {
        case .mongodb:
            validateMongoUri(uri)
        case .postgres, .supabase, .neon:
            validatePostgresUri(uri)
        case .mysql:
            validateMySQLUri(uri)
        default:
            uriError = nil
        }
    }
    
    private func validateMongoUri(_ uri: String) {
        do {
            _ = try ConnectionSettings(uri)
            uriError = nil
            showDatabaseField = false
        } catch let error as MongoInvalidUriError {
            uriError = error.description
        } catch {
            uriError = "The given MongoDB connection URI is invalid"
        }
    }
    
    private func validatePostgresUri(_ uri: String) {
        if uri.hasPrefix("postgresql://") || uri.hasPrefix("postgres://") {
            uriError = nil
            showDatabaseField = false
        } else {
            uriError = "PostgreSQL URI should start with postgresql:// or postgres://"
        }
    }
    
    private func validateMySQLUri(_ uri: String) {
        if uri.hasPrefix("mysql://") {
            uriError = nil
        } else {
            uriError = "MySQL URI should start with mysql://"
        }
    }
    
    private func sanitizePostgresURI(_ uri: String) -> String {
        guard uri.hasPrefix("postgresql://") || uri.hasPrefix("postgres://") else {
            return uri // Return as-is if not a PostgreSQL URI
        }
        
        guard let url = URL(string: uri) else {
            return uri // Return original if URL parsing fails
        }
        
        // Extract core components
        let scheme = url.scheme ?? "postgresql"
        let user = url.user
        let password = url.password
        let host = url.host ?? "localhost"
        let port = url.port
        let database = url.path.isEmpty ? "" : String(url.path.dropFirst()) // Remove leading "/"
        
        // Build clean URI with only essential components
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        
        // Add port if specified and not default
        if let port = port, port != 5432 {
            components.port = port
        }
        
        // Add user credentials if present
        if let user = user {
            components.user = user
            components.password = password // Will be nil if not present
        }
        
        // Add database path
        if !database.isEmpty {
            components.path = "/\(database)"
        }
        
        // Return the sanitized URI or original if construction fails
        return components.url?.absoluteString ?? uri
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if connection != nil {
                connectionFormView
            } else {
                if selectedDatabaseType == nil {
                    DatabaseSelectionView(selectedDatabaseType: $selectedDatabaseType)
                        .transition(
                            .asymmetric(
                                insertion: .scale(scale: 1).combined(with: .opacity),
                                removal: .scale(scale: 0.9).combined(with: .opacity)
                            )
                        )
                } else if selectedDatabaseType?.category == .cloud {
                    cloudDatabaseView
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .scale(scale: 0.9).combined(with: .opacity)
                            )
                        )
                } else {
                    connectionFormView
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .scale(scale: 0.9).combined(with: .opacity)
                            )
                        )
                }
                
            }
        }
        .onAppear {
            mapExistingConnectionData()
            
            // Focus on first field when form appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                nameFieldIsFocused = true
            }
        }
        .onChange(of: selectedDatabaseType) { oldValue, newValue in
            // Reset form when switching database types (but not on initial load or when editing)
            if connection == nil && oldValue != nil && newValue != oldValue {
                resetForm()
                
                // Set defaults for PostgreSQL
                if newValue == .postgres || newValue == .supabase || newValue == .neon {
                    hostname = "localhost"
                    port = "5432"
                    username = "postgres"
                    defaultDatabase = "postgres"
                }
                
                // Focus on first field after switching database types
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    nameFieldIsFocused = true
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selectedDatabaseType)
        .postHogScreenView("CreateConnection")
    }
    
    private var cloudDatabaseView: some View {
        VStack(spacing: 0) {
            // Modern header with back navigation
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedDatabaseType = nil
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .medium))
                        Text("Back")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.controlColor).opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text(selectedDatabaseType?.displayName ?? "")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Authenticate with your cloud database")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .customMenuButtonStyle()
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            
            // Web View Container
            if let databaseType = selectedDatabaseType {
                ZStack {
                    CloudDatabaseWebView(databaseType: databaseType, isLoading: $isWebViewLoading)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    
                    if isWebViewLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            
                            Text("Loading \(databaseType.displayName)...")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.controlColor).opacity(0.9))
                        .cornerRadius(16)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
    }
    
    private var connectionFormView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with database type info
                VStack(spacing: 16) {
                    HStack {
                        if connection == nil {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedDatabaseType = nil
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 14, weight: .medium))
                                    Text("Back")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.controlColor).opacity(0.1))
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Spacer()
                        }
                    }.padding(.top, 12)
                    
                    // Database type header with icon
                    HStack(spacing: 16) {
                        if let databaseType = selectedDatabaseType {
                            Image(databaseType.icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 32, height: 32)
                                .foregroundStyle(databaseType.accentColor)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Configure \(selectedDatabaseType?.displayName ?? "") Connection")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text("Enter your connection details to get started")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 16)
                
                // Connection Form
                VStack(spacing: 18) {
                    FormSection(title: "Basic Information") {
                        FormField(label: "Name") {
                            TextField("e.g first connection", text: $name)
                                .textFieldStyle(CustomTextFieldStyle())
                                .focused($nameFieldIsFocused)
                        }
                    }
                    
                    if selectedDatabaseType == .postgres || selectedDatabaseType == .supabase || selectedDatabaseType == .neon {
                        // PostgreSQL field-based input
                        PostgreSQLFieldsView(
                            hostname: $hostname,
                            port: $port,
                            username: $username,
                            password: $password,
                            defaultDatabase: $defaultDatabase,
                            sslMode: $sslMode,
                            showURIImportSheet: $showURIImportSheet
                        )
                    } else {
                        // Non-PostgreSQL databases use URI
                        FormSection(title: "Connection Details") {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("URI")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    if let error = uriError {
                                        Text(error)
                                            .font(.caption)
                                            .foregroundColor(.red)
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                    }
                                }
                                
                                HStack(spacing: 8) {
                                    TextField(selectedDatabaseType?.placeholderURI ?? "", text: $uri)
                                        .textFieldStyle(CustomTextFieldStyle())
                                        .focused($uriFieldIsFocused)
                                        .onChange(of: uri) { oldValue, newValue in
                                            if (uriFieldIsFocused) {
                                                if let selectedDatabaseType = selectedDatabaseType {
                                                    validateConnectionString(uri, for: selectedDatabaseType)
                                                }
                                            }
                                        }
                                    
                                    if showDatabaseField {
                                        Text("/")
                                            .foregroundColor(.secondary)
                                        
                                        TextField("database", text: $defaultDatabase)
                                            .textFieldStyle(CustomTextFieldStyle())
                                            .frame(width: 100)
                                    }
                                }
                            }
                        }
                    }
                    
                    FormSection(title: "Display Settings") {
                        HStack(spacing: 20) {
                            EnvironmentPicker(selectedEnvironment: $selectedEnvironment)
                            ConnectionColorPicker(selectedColor: $color)
                        }
                    }
                }
                .padding(.horizontal, 32)
                
                // Action buttons
                HStack(spacing: 12) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .customMenuButtonStyle()
                    
                    Spacer()
                    
                    Button(connection != nil ? "Update Connection" : "Create Connection") {
                        saveConnection()
                    }
                    .primaryStyle()
                    .disabled(!isFormValid)
                    .frame(width: 200)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $showURIImportSheet) {
            URIImportSheet(
                uriInput: $uriToImport,
                onImport: { uri in
                    parsePostgresURI(uri)
                    showURIImportSheet = false
                    uriToImport = ""
                },
                onCancel: {
                    showURIImportSheet = false
                    uriToImport = ""
                }
            )
        }
    }
    
    private var connectionFieldLabel: String {
        switch selectedDatabaseType {
        case .mongodb:
            return "MongoDB URI"
        default:
            return "Connection String"
        }
    }
    
    private func resetForm() {
        uri = ""
        name = ""
        defaultDatabase = ""
        uriError = nil
        showDatabaseField = false
        selectedEnvironment = .local
        color = .blue
        
        // Reset field-based inputs
        hostname = ""
        port = ""
        username = ""
        password = ""
        sslMode = "prefer"
        useFieldBasedInput = true
    }
    
    private func mapExistingConnectionData() {
        if let connection = connection {
            uri = connection.url
            name = connection.name
            color = connection.color
            selectedEnvironment = connection.environment
            selectedDatabaseType = DatabaseType(rawValue: connection.databaseType.rawValue)
            defaultDatabase = connection.defaultDatabase ?? ""
            
            // Parse URI for PostgreSQL field-based inputs
            if let databaseType = selectedDatabaseType,
               (databaseType == .postgres || databaseType == .supabase || databaseType == .neon) {
                parsePostgresURI(connection.url)
            }
            
            // Validate the URI to properly set showDatabaseField
            if let databaseType = selectedDatabaseType {
                validateConnectionString(uri, for: databaseType)
            }
        }
    }
    
    private func parsePostgresURI(_ uriString: String) {
        guard let url = URL(string: uriString) else { return }
        
        hostname = url.host ?? ""
        port = url.port?.description ?? ""
        username = url.user ?? ""
        password = url.password ?? ""
        
        // Parse database from path
        let path = url.path
        if !path.isEmpty && path != "/" {
            defaultDatabase = String(path.dropFirst()) // Remove leading "/"
        }
        
        // Parse SSL mode from query parameters
        if let query = url.query {
            let queryItems = URLComponents(string: "?\(query)")?.queryItems ?? []
            for item in queryItems {
                if item.name.lowercased() == "sslmode" {
                    sslMode = item.value ?? "prefer"
                    break
                }
            }
        }
        
        // Set default values if empty
        if hostname.isEmpty { hostname = "localhost" }
        if port.isEmpty { port = "5432" }
        if username.isEmpty { username = "postgres" }
        if defaultDatabase.isEmpty { defaultDatabase = "postgres" }
    }
    
    private func constructPostgresURI() -> String {
        var components = URLComponents()
        components.scheme = "postgresql"
        components.host = hostname.isEmpty ? "localhost" : hostname
        components.port = Int(port) ?? 5432
        components.user = username.isEmpty ? "postgres" : username
        components.password = password.isEmpty ? nil : password
        components.path = defaultDatabase.isEmpty ? "/postgres" : "/\(defaultDatabase)"
        
        // Add SSL mode as query parameter
        if sslMode != "prefer" {
            components.queryItems = [URLQueryItem(name: "sslmode", value: sslMode)]
        }
        
        return components.url?.absoluteString ?? ""
    }
    
    private func saveConnection() {
        Task {
            await saveConnectionAsync()
        }
    }
    
    private func saveConnectionAsync() async {
        guard let databaseType = selectedDatabaseType else { return }
        guard let databaseTypeEnum = DatabaseType(rawValue: databaseType.rawValue) else { return }
        
        // Construct or sanitize URI
        let sanitizedURI: String
        if (databaseType == .postgres || databaseType == .supabase || databaseType == .neon) && useFieldBasedInput {
            // Construct URI from fields
            sanitizedURI = constructPostgresURI()
        } else if databaseType == .postgres || databaseType == .supabase || databaseType == .neon {
            sanitizedURI = sanitizePostgresURI(uri)
        } else {
            sanitizedURI = uri
        }
        
        // If editing an existing connection, disconnect it first
        let isEditingExistingConnection = connection != nil
        if isEditingExistingConnection {
            await onDisconnect?()
        }
        
        let savedConnection: Connection
        if let id = connection?.persistentModelID,
           let existing = try? modelContext.fetch(
            FetchDescriptor<Connection>(
                predicate: #Predicate { $0.persistentModelID == id }
            )
           ).first {
            existing.url = sanitizedURI
            existing.name = name
            existing.color = color.unsafelyUnwrapped
            existing.environment = selectedEnvironment
            existing.defaultDatabase = defaultDatabase
            try? modelContext.save()
            savedConnection = existing
        } else {
            let newConnection = Connection(
                databaseType: databaseTypeEnum,
                url: sanitizedURI,
                name: name,
                color: color.unsafelyUnwrapped,
                environment: selectedEnvironment,
                defaultDatabase: defaultDatabase
            )
            modelContext.insert(newConnection)
            savedConnection = newConnection
        }
        
        // If we edited an existing connection, create a new instance and connect
        if isEditingExistingConnection {
            let instanceId = sidebarViewModel.createNewConnectionInstance(for: savedConnection)
            sidebarViewModel.changeActiveSidebarItem(.connection(instanceId))
        }
        
        dismiss()
    }
}

// MARK: - Form Components
struct FormSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            
            content
                .padding(16)
                .background(Color(.controlColor).opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.separator, lineWidth: 1)
                )
                .cornerRadius(16)
        }
    }
}
