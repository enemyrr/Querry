//
//  WelcomeWindow.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/4/25.
//

import SwiftUI
import SwiftData
import AppKit

struct WindowConfigurator: NSViewRepresentable {
    let configure: (NSWindow) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                configure(window)
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct CustomCloseButton: View {
    var action: () -> Void
    @State private var isHovering: Bool = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.secondary)
                .padding(4)
                .background(
                    Circle()
                    
                        .fill(isHovering ? Color.gray.opacity(0.3) : Color.gray.opacity(0.1)) // Changes color on hover
                )
        }
        .buttonStyle(.plain)
        .padding(.top, 10)
        .padding(.leading, 10)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}



struct WelcomeWindow: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var connections: [Connection]
    @State private var selection: PersistentIdentifier? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        ZStack {
            WindowConfigurator { window in
                let frame = NSRect(x: 0, y: 0, width: 740, height: 440)
                window.setFrame(frame, display: true)
                window.center()
                window.styleMask.remove(.resizable)
                window.isMovableByWindowBackground = true
                window.standardWindowButton(.closeButton)?.isHidden = true
                window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                window.standardWindowButton(.zoomButton)?.isHidden = true
            }
            HStack(spacing: 0) {
                ZStack(alignment: .topLeading) { // Align content to the top-left corner
                    VStack(spacing: 0) {
                        CustomCloseButton {
                            dismiss()
                        }
                        .ignoresSafeArea(.all)
                        .padding(0) // Add padding for placement
                        
                        Spacer() // Push the rest of the content downward
                    }
                    
                    VStack {
                        ZStack {
                            // Background dark glow/shadow effect
                            Color.clear
                                .padding(0)
                                .overlay(
                                    Circle()
                                        .fill(Color.blue.opacity(0.16))
                                        .blur(radius: 30)
                                        .frame(width: 190, height: 190)
                                )
                                .frame(height: 100)
                            
                            Image("xcode")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 140, height: 140)
                                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        
                        Text("DocumentPlus")
                            .font(.system(size: 40, weight: .bold))
                        
                        Text("Version 0.1 Beta (15A5160n)")
                            .font(.subheadline)
                            .foregroundColor(Color(NSColor.secondaryLabelColor))
                        
                        VStack(spacing: 6) {
                            //                                                        Button(action: {
                            //                                                            let newConnection = Connection(
                            //                                                                name: "Taxpool (Local)",
                            //                                                                databaseType: DatabaseType.mongodb,
                            //                                                                url: "mongodb://localhost:27017/taxpool"
                            //                                                            )
                            //                                                            modelContext.insert(newConnection)
                            //                                                        }) {
                            //                                                            Text("Mock Data")
                            //                                                        }
                            CustomActionButton(icon: "plus", text: "Create New Project...")
                            CustomActionButton(icon: "arrow.down", text: "Clone Git Repository...")
                            CustomActionButton(icon: "folder", text: "Open Existing Project...")
                        }
                        .padding(.top, 20)
                    }.padding(.top, 50)
                }
                .frame(width: 465, height: 455)
                .background(Color.black.opacity(0.2))
                
                List(connections, selection: $selection) { connection in
                    ConnectionItem(connection: connection)
                        .tag(connection.id)
                }
                .contextMenu(forSelectionType: PersistentIdentifier.self) { connection in
                        } primaryAction: { connectionId in
                            if let connectionId = connectionId.first {
                                dismiss()
                                openWindow(id: "connectionDetails", value: connectionId)
                            }
                        }
                .listStyle(.sidebar)
                .edgesIgnoringSafeArea(.all)
            }
            .frame(width: 740, height: 455)
        }
    }
}



struct CustomActionButton: View {
    let icon: String
    let text: String
    
    var body: some View {
        Button(action: {
        }) {
            HStack(alignment: .center, spacing: 8) { // Add spacing between icon and text
                Image(systemName: icon)
                    .frame(width: 20, alignment: .leading) // Icon aligns to the left
                Text(text)
                    .frame(maxWidth: .infinity, alignment: .leading) // Ensures text aligns left and expands
            }
        }
        .padding(8)
        .buttonStyle(.plain)
        .frame(maxWidth: 350)
        .background(Color(NSColor.lightGray).opacity(0.1))
        .cornerRadius(6)
    }
}

struct ConnectionItem: View {
    let connection: Connection
    
    var body: some View {
        HStack {
            Image("mongodb.white")
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .padding(.horizontal, 12)
                .background(
                    Circle()
                        .fill(Color(red: 0/255, green: 104/255, blue: 74/255)) // Forest Green background
                        .overlay(
                            Circle()
                                .strokeBorder(Color(red: 0/255, green: 237/255, blue: 100/255), lineWidth: 1) // Sprint Green border
                        )
                        .frame(width: 32, height: 32)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(connection.name)
                Text(connection.url)
                    .font(.system(size: 10))
                    .foregroundColor(Color(NSColor.secondaryLabelColor))
            }
        }
    }
}


#Preview {
    WelcomeWindow()
}
