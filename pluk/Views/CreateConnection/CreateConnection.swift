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
    @State private var showSheet = false
    
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

// MARK: - Database Provider Models
enum DatabaseProvider: String, CaseIterable, Identifiable {
    case supabase = "supabase"
    case neon = "neon"
    case postgres = "postgres"
    case mongodb = "MongoDB"
    case mysql = "mysql"
    case mariadb = "mariadb"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .supabase: return "Supabase"
        case .neon: return "Neon"
        case .postgres: return "PostgreSQL"
        case .mongodb: return "MongoDB"
        case .mysql: return "MySQL"
        case .mariadb: return "MariaDB"
        }
    }
    
    var icon: String {
        switch self {
        case .supabase: return "supabase"
        case .neon: return "neon"
        case .postgres: return "postgres"
        case .mongodb: return "mongodb"
        case .mysql: return "mysql"
        case .mariadb: return "mariadb"
        }
    }
    
    var accentColor: Color {
        switch self {
        case .supabase: return Color(hex: "#3ECF8E")
        case .neon: return Color(hex: "#00E599")
        case .postgres: return Color(hex: "#336791")
        case .mysql: return Color(hex: "#00546B")
        case .mongodb: return Color(hex: "#07EB65")
        case .mariadb: return Color(hex: "#C39A6C")
        }
    }
    
    var isConnected: Bool {
        switch self {
        case .supabase: return false
        default: return false
        }
    }
    
    var status: ProviderStatus {
        switch self {
        case .mongodb:
            return .beta
        case .neon, .supabase, .mysql, .mariadb:
            return .comingSoon
        default:
            return .available
        }
    }
    
    var placeholderURI: String {
        switch self {
        case .supabase:
            return "postgresql://username:password@host:5432/database"
        case .neon:
            return "postgresql://username:password@host:5432/database"
        case .postgres:
            return "postgresql://username:password@localhost:5432/database"
        case .mysql:
            return "mysql://username:password@localhost:3306/database"
        case .mongodb:
            return "mongodb+srv://user:password@cluster.mongodb.net"
        case .mariadb:
            return "mariadb://username:password@localhost:3306/database"
        }
    }
    
    var category: ProviderCategory {
        switch self {
        case .supabase, .neon:
            return .cloud
        case .postgres, .mysql, .mongodb, .mariadb:
            return .database
        }
    }
}

enum ProviderCategory: String, CaseIterable {
    case cloud = "Cloud Providers"
    case database = "Database"
}

enum ProviderStatus {
    case available
    case beta
    case comingSoon
    case notConnected
}

// MARK: - Cloud Provider Web View
struct CloudProviderWebView: NSViewRepresentable {
    let provider: DatabaseProvider
    @Binding var isLoading: Bool
    @Environment(\.dismiss) var dismiss
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        guard let url = getProviderURL() else { return }
        let request = URLRequest(url: url)
        nsView.load(request)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func getProviderURL() -> URL? {
        switch provider {
        case .supabase:
            return URL(string: "https://supabase.com/dashboard")
        case .neon:
            return URL(string: "https://console.neon.tech")
        default:
            return nil
        }
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: CloudProviderWebView
        
        init(_ parent: CloudProviderWebView) {
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
    
    @State private var selectedProvider: DatabaseProvider? = nil
    @State private var uri = ""
    @State private var name = ""
    @State private var defaultDatabase = ""
    @State private var color: Optional<ConnectionColor> = nil
    @State private var selectedEnvironment: ConnectionEnvironment = .local
    @State private var uriError: String? = nil
    @State private var showDatabaseField = false
    @State private var isWebViewLoading = false
    @FocusState private var uriFieldIsFocused: Bool
    
    private let connection: Connection?
    
    init(connection: Connection? = nil) {
        self.connection = connection
        _color = State(initialValue: .blue)
    }
    
    private var isFormValid: Bool {
        guard let provider = selectedProvider else { return false }
        
        if provider.category == .cloud {
            return !name.isEmpty
        }
        
        return !uri.isEmpty &&
        !name.isEmpty &&
        uriError == nil &&
        (!showDatabaseField || !defaultDatabase.isEmpty)
    }
    
    private func validateConnectionString(_ uri: String, for provider: DatabaseProvider) {
        guard !uri.isEmpty else {
            uriError = nil
            return
        }
        
        switch provider {
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
            let connectionSettings = try ConnectionSettings(uri)
            
            if let _ = connectionSettings.targetDatabase {
                showDatabaseField = false
            } else {
                defaultDatabase = ""
                showDatabaseField = true
            }
            uriError = nil
        } catch let error as MongoInvalidUriError {
            uriError = error.description
        } catch {
            uriError = "The given MongoDB connection URI is invalid"
        }
    }
    
    private func validatePostgresUri(_ uri: String) {
        if uri.hasPrefix("postgresql://") || uri.hasPrefix("postgres://") {
            uriError = nil
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
    
    var body: some View {
        VStack(spacing: 0) {
            if connection != nil {
                connectionFormView
            } else {
                if selectedProvider == nil {
                    ProviderSelectionView(selectedProvider: $selectedProvider)
                        .transition(
                            .asymmetric(
                                insertion: .scale(scale: 1).combined(with: .opacity),
                                removal: .scale(scale: 0.9).combined(with: .opacity)
                            )
                        )
                } else if selectedProvider?.category == .cloud {
                    cloudProviderView
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
        }
        .animation(.easeInOut(duration: 0.25), value: selectedProvider)
        
    }
    
    private var cloudProviderView: some View {
        VStack(spacing: 0) {
            // Modern header with back navigation
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedProvider = nil
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
                    Text(selectedProvider?.displayName ?? "")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Authenticate with your provider")
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
            if let provider = selectedProvider {
                ZStack {
                    CloudProviderWebView(provider: provider, isLoading: $isWebViewLoading)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    
                    if isWebViewLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            
                            Text("Loading \(provider.displayName)...")
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
            VStack(spacing: 32) {
                // Header with provider info
                VStack(spacing: 24) {
                    HStack {
                        if connection == nil {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedProvider = nil
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
                    }
                    
                    // Provider header with icon
                    HStack(spacing: 16) {
                        if let provider = selectedProvider {
                            Image(provider.icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 48, height: 48)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Configure \(selectedProvider?.displayName ?? "") Connection")
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
                .padding(.top, 24)
                
                // Connection Form
                VStack(spacing: 24) {
                    FormSection(title: "Connection Details") {
                        VStack(spacing: 20) {
                            FormField(label: "Name") {
                                TextField("e.g first connection", text: $name)
                                    .textFieldStyle(CustomTextFieldStyle())
                            }
                            
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
                                    TextField("e.g mongodb+srv://user:password@cluster.mongodb.net", text: $uri)
                                        .textFieldStyle(CustomTextFieldStyle())
                                        .focused($uriFieldIsFocused)
                                        .onChange(of: uri) { oldValue, newValue in
                                            if (uriFieldIsFocused) {
                                                validateMongoUri(newValue)
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
                    
                    FormSection(title: "Configuration") {
                        HStack(spacing: 20) {
                            EnvironmentPicker(selectedEnvironment: $selectedEnvironment)
                            ConnectionColorPicker(selectedColor: $color)
                        }
                    }
                }
                .padding(.horizontal, 32)
                
                // Action buttons
                HStack(spacing: 16) {
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
                .padding(.bottom, 32)
            }
        }
    }
    
    private var connectionFieldLabel: String {
        switch selectedProvider {
        case .mongodb:
            return "MongoDB URI"
        default:
            return "Connection String"
        }
    }
    
    private func mapExistingConnectionData() {
        if let connection = connection {
            uri = connection.url
            name = connection.name
            color = connection.color
            selectedEnvironment = connection.environment
            selectedProvider = DatabaseProvider(rawValue: connection.databaseType.rawValue)
            
            if connection.defaultDatabase != nil {
                showDatabaseField = true
                defaultDatabase = connection.defaultDatabase ?? ""
            }
        }
    }
    
    private func saveConnection() {
        guard let provider = selectedProvider else { return }
        guard let databaseType = DatabaseType(rawValue: provider.rawValue) else { return }
        
        if let id = connection?.persistentModelID,
           let existing = try? modelContext.fetch(
            FetchDescriptor<Connection>(
                predicate: #Predicate { $0.persistentModelID == id }
            )
           ).first {
            existing.url = uri
            existing.name = name
            existing.color = color.unsafelyUnwrapped
            existing.environment = selectedEnvironment
            existing.defaultDatabase = defaultDatabase
            try? modelContext.save()
        } else {
            let connection = Connection(
                databaseType: databaseType,
                url: uri,
                name: name,
                color: color.unsafelyUnwrapped,
                environment: selectedEnvironment,
                defaultDatabase: defaultDatabase
            )
            modelContext.insert(connection)
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
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            
            content
                .padding(24)
                .background(Color(.controlColor).opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.separator, lineWidth: 1)
                )
                .cornerRadius(16)
        }
    }
}
