//
//  CreateConnection.swift
//  Collection
//
//  Created by Fauzaan on 1/31/25.
//

import Foundation
import MongoCore
import MongoKitten
import Network
import PostHog
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import WebKit

// MARK: - Data Extension for Base64URL Encoding
extension Data {
    func base64URLEncodedString() -> String {
        return base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Simple HTTP Server for OAuth Loopback
struct HTTPRequest {
    let method: String
    let path: String
    let query: String?
}

struct HTTPResponse {
    let statusCode: Int
    let body: String

    var data: Data {
        let response = """
            HTTP/1.1 \(statusCode) \(statusCode == 200 ? "OK" : "Not Found")
            Content-Type: text/html
            Content-Length: \(body.utf8.count)
            Connection: close

            \(body)
            """
        return response.data(using: .utf8) ?? Data()
    }
}

class HTTPServer {
    private let port: Int
    private let handler: (HTTPRequest) -> HTTPResponse
    private var listener: NWListener?
    private var isRunning = false

    init(port: Int, handler: @escaping (HTTPRequest) -> HTTPResponse) {
        self.port = port
        self.handler = handler
    }

    func start() {
        guard !isRunning else { return }

        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true

            listener = try NWListener(
                using: parameters,
                on: NWEndpoint.Port(integerLiteral: UInt16(port))
            )

            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }

            listener?.start(queue: DispatchQueue.global(qos: .background))
            isRunning = true

        } catch {
            print("Failed to start HTTP server: \(error)")
        }
    }

    func stop() {
        isRunning = false
        listener?.cancel()
        listener = nil
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: DispatchQueue.global(qos: .background))

        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) {
            [weak self] data, _, isComplete, error in
            guard let self = self, let data = data, !data.isEmpty else {
                connection.cancel()
                return
            }

            let requestString = String(data: data, encoding: .utf8) ?? ""
            let request = self.parseHTTPRequest(requestString)
            let response = self.handler(request)

            connection.send(
                content: response.data,
                completion: .contentProcessed { _ in
                    connection.cancel()
                }
            )
        }
    }

    private func parseHTTPRequest(_ requestString: String) -> HTTPRequest {
        let lines = requestString.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else {
            return HTTPRequest(method: "GET", path: "/", query: nil)
        }

        let components = firstLine.components(separatedBy: " ")
        guard components.count >= 2 else {
            return HTTPRequest(method: "GET", path: "/", query: nil)
        }

        let method = components[0]
        let fullPath = components[1]

        if let urlComponents = URLComponents(string: fullPath) {
            return HTTPRequest(
                method: method,
                path: urlComponents.path,
                query: urlComponents.query
            )
        }

        return HTTPRequest(method: method, path: fullPath, query: nil)
    }
}

struct CreateConnection: View {
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @Binding var showSheet: Bool

    var body: some View {
        Button(action: {
            showSheet.toggle()
        }) {
            Image(systemName: "plus.circle").font(.title3).foregroundStyle(
                .secondary
            )
        }
        .buttonStyle(ActionButtonStyle())
        .sheet(isPresented: $showSheet) {
            ZStack {
                VisualEffectView(
                    material: .hudWindow,
                    blendingMode: .behindWindow
                )
                .ignoresSafeArea()
                
                CreateConnectionForm()
                    .frame(width: 560)
            }
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
    @State private var color: ConnectionColor? = nil
    @State private var selectedEnvironment: ConnectionEnvironment? = .local
    @State private var uriError: String? = nil
    @State private var showDatabaseField = false
    @State private var isWebViewLoading = false
    @FocusState private var uriFieldIsFocused: Bool
    @FocusState private var nameFieldIsFocused: Bool
    @State private var isTestingConnection = false
    @State private var testResultMessage: String? = nil
    @State private var testSucceeded: Bool? = nil
    
    @State private var databaseService = DatabaseService()
    
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

    init(connection: Connection? = nil, onDisconnect: (() async -> Void)? = nil)
    {
        self.connection = connection
        self.onDisconnect = onDisconnect
        _color = State(initialValue: .blue)
    }

    private var isFormValid: Bool {
        guard let databaseType = selectedDatabaseType else { return false }

        // For Convex using OAuth
        if databaseType == .convex {
            return !name.isEmpty
        }

        if databaseType.category == .cloud {
            return !name.isEmpty
        }

        // For PostgreSQL databases using field-based input
        if (databaseType == .postgres || databaseType == .mysql
            || databaseType == .supabase) && useFieldBasedInput
        {
            return !name.isEmpty
        }

        // For SQLite databases using file path in URI field
        if databaseType == .sqlite {
            return !name.isEmpty && !uri.isEmpty
        }

        // For other databases or URI-based input
        return !uri.isEmpty && !name.isEmpty && uriError == nil
    }

    private func validateConnectionString(
        _ uri: String,
        for databaseType: DatabaseType
    ) {
        guard !uri.isEmpty else {
            uriError = nil
            return
        }

        switch databaseType {
        case .mongodb:
            validateMongoUri(uri)
        case .postgres, .supabase:
            validatePostgresUri(uri)
        case .mysql:
            validateMySQLUri(uri)
        case .sqlite:
            validateSQLiteUri(uri)
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
            uriError =
                "PostgreSQL URI should start with postgresql:// or postgres://"
        }
    }

    private func validateMySQLUri(_ uri: String) {
        if uri.hasPrefix("mysql://") {
            uriError = nil
        } else {
            uriError = "MySQL URI should start with mysql://"
        }
    }

    private func validateSQLiteUri(_ uri: String) {
        if uri.hasPrefix("sqlite://") || uri.hasPrefix("file:")
            || uri.hasPrefix("/") || uri == ":memory:"
        {
            uriError = nil
        } else {
            uriError =
                "SQLite path should be a file path, start with sqlite://, file:, or use :memory:"
        }
    }

    private func sanitizePostgresURI(_ uri: String) -> String {
        guard uri.hasPrefix("postgresql://") || uri.hasPrefix("postgres://")
        else {
            return uri  // Return as-is if not a PostgreSQL URI
        }

        guard let url = URL(string: uri) else {
            return uri  // Return original if URL parsing fails
        }

        // Extract core components
        let scheme = url.scheme ?? "postgresql"
        let user = url.user
        let password = url.password
        let host = url.host ?? "localhost"
        let port = url.port
        let database = url.path.isEmpty ? "" : String(url.path.dropFirst())  // Remove leading "/"

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
            components.password = password  // Will be nil if not present
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
                    DatabaseSelectionView(
                        selectedDatabaseType: $selectedDatabaseType
                    )
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 1).combined(
                                with: .opacity
                            ),
                            removal: .scale(scale: 0.9).combined(with: .opacity)
                        )
                    )
                } else if selectedDatabaseType?.category == .cloud {
                    if selectedDatabaseType == .convex {
                        ConvexOAuthView(
                            selectedDatabaseType: $selectedDatabaseType,
                            convexAccessToken: $password,
                            dismiss: dismiss
                        )
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .trailing).combined(
                                    with: .opacity
                                ),
                                removal: .scale(scale: 0.9).combined(
                                    with: .opacity
                                )
                            )
                        )
                    }
                } else {
                    connectionFormView
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .trailing).combined(
                                    with: .opacity
                                ),
                                removal: .scale(scale: 0.9).combined(
                                    with: .opacity
                                )
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

                // Focus on first field after switching database types
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    nameFieldIsFocused = true
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selectedDatabaseType)
        .postHogScreenView("CreateConnection")
    }
    
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    
    private var connectionFormView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with database type info
                HStack(spacing: 16) {
                    if let databaseType = selectedDatabaseType {
                        Image(databaseType.icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                            .foregroundStyle(databaseType.accentColor)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(
                            "Configure \(selectedDatabaseType?.displayName ?? "") Connection"
                        )
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)

                        Text("Enter your connection details to get started")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(.horizontal, 32)
                .padding(.top, 32)
                

                // Connection Form
                VStack(spacing: 18) {
                    FormSection(title: "Basic Information") {
                        FormField(label: "Name") {
                            TextField("e.g first connection", text: $name)
                                .textFieldStyle(CustomTextFieldStyle())
                                .focused($nameFieldIsFocused)
                        }
                    }

                    if selectedDatabaseType == .postgres
                        || selectedDatabaseType == .supabase
                    {
                        // PostgreSQL field-based input
                        PostgreSQLFieldsView(
                            hostname: $hostname,
                            port: $port,
                            username: $username,
                            password: $password,
                            defaultDatabase: $defaultDatabase,
                            sslMode: $sslMode,
                            showURIImportSheet: $showURIImportSheet,
                            testBackground: fieldTestBackground,
                            isTesting: isTestingConnection,
                            onTest: { Task { await testConnection() } }
                        )
                    } else if selectedDatabaseType == .sqlite {
                        SQLiteFieldsView(filePath: $uri)
                    } else if selectedDatabaseType == .mysql {
                        MySQLFieldsView(
                            hostname: $hostname,
                            port: $port,
                            username: $username,
                            password: $password,
                            defaultDatabase: $defaultDatabase,
                            sslMode: $sslMode,
                            showURIImportSheet: $showURIImportSheet,
                            testBackground: fieldTestBackground,
                            isTesting: isTestingConnection,
                            onTest: { Task { await testConnection() } }
                        )
                    } else if selectedDatabaseType == .mongodb {
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
                                    TextField(
                                        selectedDatabaseType?.placeholderURI
                                            ?? "",
                                        text: $uri
                                    )
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .focused($uriFieldIsFocused)
                                    .onChange(of: uri) { oldValue, newValue in
                                        if uriFieldIsFocused {
                                            if let selectedDatabaseType =
                                                selectedDatabaseType
                                            {
                                                validateConnectionString(
                                                    uri,
                                                    for: selectedDatabaseType
                                                )
                                            }
                                        }
                                    }

                                    if showDatabaseField {
                                        Text("/")
                                            .foregroundColor(.secondary)

                                        TextField(
                                            "database",
                                            text: $defaultDatabase
                                        )
                                        .textFieldStyle(CustomTextFieldStyle())
                                        .frame(width: 100)
                                    }
                                }
                            }
                        }
                    }

                    FormSection(title: "Display Settings") {
                        HStack(spacing: 20) {
                            EnvironmentPicker(
                                selectedEnvironment: $selectedEnvironment
                            )
                            ConnectionColorPicker(selectedColor: $color)
                        }
                    }
                }
                .padding(.horizontal, 32)

                // Action buttons
                HStack(spacing: 12) {
                    Button("Cancel") {
                        if connection != nil {
                            dismiss()
                        } else {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedDatabaseType = nil
                            }
                        }
                    }
                    .customCancelButtonStyle()

                    Spacer()

                    Button(
                        connection != nil
                            ? "Update Connection" : "Create Connection"
                    ) {
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
                    if let db = selectedDatabaseType {
                        switch db {
                        case .postgres, .supabase:
                            parsePostgresURI(uri)
                        case .mysql:
                            parseMySQLURI(uri)
                        default:
                            break
                        }
                    }
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
    
    private func buildUriForTest() -> String? {
        guard let db = selectedDatabaseType else { return nil }
        switch db {
        case .postgres, .supabase:
            var uri = "postgresql://"
            if !username.isEmpty {
                uri += username
                if !password.isEmpty { uri += ":\(password)" }
                uri += "@"
            }
            let p = Int(port) ?? 5432
            uri += "\(hostname.isEmpty ? "localhost" : hostname):\(p)"
            if !defaultDatabase.isEmpty { uri += "/\(defaultDatabase)" }
            if sslMode != "prefer" { uri += "?sslmode=\(sslMode)" }
            return uri
        case .mysql:
            var uri = "mysql://"
            if !username.isEmpty {
                uri += username
                if !password.isEmpty { uri += ":\(password)" }
                uri += "@"
            }
            let p = Int(port) ?? 3306
            uri += "\(hostname.isEmpty ? "127.0.0.1" : hostname):\(p)"
            if !defaultDatabase.isEmpty { uri += "/\(defaultDatabase)" }
            if sslMode != "prefer" { uri += "?sslmode=\(sslMode)" }
            return uri
        case .sqlite:
            return uri
        case .mongodb:
            return uri
        case .convex:
            return nil
        }
    }
    
    private var fieldTestBackground: Color? {
        guard let success = testSucceeded else { return nil }
        return success ? Color.green : Color.red
    }
    
    private func testConnection() async {
        guard let db = selectedDatabaseType, let uri = buildUriForTest() else { return }
        await MainActor.run { isTestingConnection = true; testResultMessage = nil; testSucceeded = nil }
        let result = await databaseService.testConnection(databaseType: db, uri: uri)
        await MainActor.run {
            isTestingConnection = false
            switch result {
            case .success:
                testResultMessage = "Success"
                testSucceeded = true
            case .failure(_):
                testResultMessage = "Failed"
                testSucceeded = false
            }
        }
        try? await Task.sleep(for: .seconds(2))
        await MainActor.run {
            testResultMessage = nil
            testSucceeded = nil
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
            uri = connection.url ?? ""
            name = connection.name
            color = connection.color
            selectedEnvironment = connection.environment
            selectedDatabaseType = DatabaseType(
                rawValue: connection.databaseType.rawValue
            )
            defaultDatabase = connection.defaultDatabase ?? ""

            // Check if connection uses new field-based approach
            if connection.usesFieldBasedConnection {
                // Use the stored individual fields directly
                hostname = connection.hostname ?? ""
                port = connection.port ?? ""
                username = connection.username ?? ""
                sslMode = connection.sslMode ?? "prefer"

                // Get password from keychain
                password = connection.password ?? ""
            } else if let databaseType = selectedDatabaseType,
                      (databaseType == .postgres || databaseType == .mysql),
                      let connectionUrl = connection.url, !connectionUrl.isEmpty {
                // For legacy URI-based connections, parse the URI to populate fields
                if databaseType == .postgres {
                    parsePostgresURI(connectionUrl)
                } else if databaseType == .mysql {
                    parseMySQLURI(connectionUrl)
                }
            }

            // Validate the URI to properly set showDatabaseField
            if let databaseType = selectedDatabaseType, !uri.isEmpty {
                validateConnectionString(uri, for: databaseType)
            }
        }
    }

    private func parsePostgresURI(_ uriString: String) {
        guard let url = URL(string: uriString),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return }

        parseURIComponents(components, url: url)

        if hostname.isEmpty { hostname = "localhost" }
        if port.isEmpty { port = "5432" }
        if username.isEmpty { username = "postgres" }
        if defaultDatabase.isEmpty { defaultDatabase = "postgres" }
    }

    private func parseMySQLURI(_ uriString: String) {
        guard let url = URL(string: uriString),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return }

        parseURIComponents(components, url: url)

        if hostname.isEmpty { hostname = "127.0.0.1" }
        if port.isEmpty { port = "3306" }
        if username.isEmpty { username = "root" }
        if sslMode.isEmpty { sslMode = "prefer" }
    }

    private func parseURIComponents(_ components: URLComponents, url: URL) {
        hostname = components.host ?? ""
        port = components.port?.description ?? ""
        username = components.user ?? ""
        password = components.password ?? ""

        let path = url.path
        if !path.isEmpty && path != "/" {
            defaultDatabase = String(path.dropFirst())
        }

        if let sslModeItem = components.queryItems?.first(where: { $0.name.lowercased() == "sslmode" }) {
            sslMode = sslModeItem.value ?? "prefer"
        }
    }

    private func constructPostgresURI() -> String {
        var components = URLComponents()
        components.scheme = "postgresql"
        components.host = hostname.isEmpty ? "localhost" : hostname
        components.port = Int(port) ?? 5432
        components.user = username.isEmpty ? "postgres" : username
        components.password = password.isEmpty ? nil : password
        components.path =
            defaultDatabase.isEmpty ? "/postgres" : "/\(defaultDatabase)"

        // Add SSL mode as query parameter
        if sslMode != "prefer" {
            components.queryItems = [
                URLQueryItem(name: "sslmode", value: sslMode)
            ]
        }

        return components.url?.absoluteString ?? ""
    }

    private func saveConnection() {
        // Fill in missing default values before saving
        fillMissingDefaults()

        Task {
            await saveConnectionAsync()
        }
    }

    private func fillMissingDefaults() {
        guard let databaseType = selectedDatabaseType else { return }
        guard databaseType != .convex else { return }

        // Fill defaults for PostgreSQL databases using field-based input
        if (databaseType == .postgres || databaseType == .supabase
            || databaseType == .mysql) && useFieldBasedInput
        {
            if hostname.isEmpty {
                if databaseType == .mysql {
                    hostname = "127.0.0.1"
                } else {
                    hostname = "localhost"
                }
            }

            if port.isEmpty {
                if databaseType == .mysql {
                    port = "3306"
                } else {
                    port = "5432"
                }
            }

            if username.isEmpty {
                if databaseType == .mysql {
                    username = "root"
                } else {
                    username = "postgres"
                }
            }

            if sslMode.isEmpty {
                sslMode = "prefer"
            }
        }
    }

    private func saveConnectionAsync() async {
        guard let databaseType = selectedDatabaseType else { return }
        guard let databaseTypeEnum = DatabaseType(rawValue: databaseType.rawValue) else { return }

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
            
            // Update existing connection
            existing.name = name
            existing.color = color.unsafelyUnwrapped
            existing.environment = selectedEnvironment
            existing.defaultDatabase = defaultDatabase

            // For PostgreSQL databases using field-based input, update individual fields
            if (databaseType == .postgres || databaseType == .mysql)
                && useFieldBasedInput
            {
                existing.hostname = hostname
                existing.port = port
                existing.username = username
                existing.password = password
                existing.sslMode = sslMode
                // Set URL to nil since we're using field-based storage
                existing.url = nil
            } else {
                if databaseType != .convex {
                    // For non-PostgreSQL or URI-based input, use the URI approach
                    let sanitizedURI: String
                    if databaseType == .postgres || databaseType == .supabase {
                        sanitizedURI = sanitizePostgresURI(uri)
                    } else {
                        sanitizedURI = uri
                    }
                    existing.url = sanitizedURI
                    // Clear field-based data for URI-based connections
                    existing.hostname = nil
                    existing.port = nil
                    existing.username = nil
                    existing.password = nil
                    existing.sslMode = nil
                }
            }

            try? modelContext.save()
            savedConnection = existing
        } else {
            // Create new connection
            let newConnection: Connection

            // For PostgreSQL databases using field-based input, use the new initializer
            if (databaseType == .postgres || databaseType == .mysql)
                && useFieldBasedInput
            {
                newConnection = Connection(
                    databaseType: databaseTypeEnum,
                    name: name,
                    color: color.unsafelyUnwrapped,
                    environment: selectedEnvironment ?? .local,
                    hostname: hostname,
                    port: port,
                    username: username,
                    password: password.isEmpty ? nil : password,
                    database: defaultDatabase,
                    sslMode: sslMode
                )
            } else {
                // For non-PostgreSQL or URI-based input, use the legacy initializer
                let sanitizedURI: String
                if databaseType == .postgres || databaseType == .supabase {
                    sanitizedURI = sanitizePostgresURI(uri)
                } else {
                    sanitizedURI = uri
                }

                newConnection = Connection(
                    databaseType: databaseTypeEnum,
                    url: sanitizedURI,
                    name: name,
                    color: color.unsafelyUnwrapped,
                    environment: selectedEnvironment ?? .local,
                    defaultDatabase: defaultDatabase
                )
            }

            modelContext.insert(newConnection)

            // Save to get persistentModelID, then store password in keychain
            try? modelContext.save()

            // For field-based connections, store password in keychain after getting persistentModelID
            if (databaseType == .postgres || databaseType == .supabase)
                && useFieldBasedInput
            {
                if !password.isEmpty {
                    newConnection.password = password
                }
            }

            savedConnection = newConnection

            let connectionCount = (try? modelContext.fetchCount(FetchDescriptor<Connection>())) ?? 0
            let isFirstConnection = connectionCount == 1
            AnalyticsService.shared.trackConnectionCreated(
                databaseType: databaseTypeEnum,
                isFirstConnection: isFirstConnection
            )

            let allConnections = (try? modelContext.fetch(FetchDescriptor<Connection>())) ?? []
            let databaseTypes = Array(Set(allConnections.map { $0.databaseType.rawValue }))
            AnalyticsService.shared.updateConnectionSuperProperties(
                totalConnections: connectionCount,
                databaseTypes: databaseTypes
            )
        }

        // If we edited an existing connection that was disconnected, reconnect to it
        if isEditingExistingConnection {
            // Only reconnect if the connection was previously connected
            // The onDisconnect callback indicates it was connected when editing started
            if onDisconnect != nil {
                let instanceId = sidebarViewModel.createNewConnectionInstance(
                    for: savedConnection
                )
                
                // Create new native tab
                if let connectionInstance = ConnectionService.shared.getInstance(instanceId) {
                    WindowController.newTab(
                        tabType: .connection(instanceId),
                        connectionInstance: connectionInstance
                    )
                }
            }
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
