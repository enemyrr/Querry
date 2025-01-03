//
//  WelcomeScreen.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/4/25.
//

import SwiftUI
import AppKit

struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .sidebar
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

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


struct WelcomeScreen: View {
    @State private var selection: String?
    
    var body: some View {
        ZStack {
            WindowConfigurator { window in
                let frame = NSRect(x: 0, y: 0, width: 740, height: 455)
                window.setFrame(frame, display: true)
                window.center()
                window.styleMask.remove(.resizable) // Optional: Prevent resizing
                window.isMovableByWindowBackground = true
                window.standardWindowButton(.closeButton)?.isHidden = true
                window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                window.standardWindowButton(.zoomButton)?.isHidden = true
            }
            VisualEffectView()
                .edgesIgnoringSafeArea(.all)
            
            
            HStack(spacing: 0) {
                VStack {
                    Image("xcode")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .foregroundColor(.blue)
                    
                    Text("DocumentPlus")
                        .font(.system(size: 40, weight: .bold))
                    
                    Text("Version 16.2")
                        .font(.subheadline)
                        .foregroundColor(Color(NSColor.secondaryLabelColor))
                    
                    VStack(spacing: 6) {
                        CustomActionButton(icon: "plus", text: "Create New Project...")
                        CustomActionButton(icon: "arrow.down", text: "Clone Git Repository...")
                        CustomActionButton(icon: "folder", text: "Open Existing Project...")
                    }
                    .padding(.top, 20)
                }
                .frame(width: 465, height: 455)
                .background(Color.black.opacity(0.2))
                
                
                List(["DocumentPlus", "sampleproject", "w.calender", "iTerm2"], id: \.self, selection: $selection) { project in
                    RecentProjectRow(projectName: project)
                }
                .listStyle(.sidebar)
                .edgesIgnoringSafeArea(.all)
                .frame(width: 270, height: 455)
                .onChange(of: selection) { oldValue, newValue in
                    if let selectedCollection = newValue {
                        Task {
                            
                            //                            addTab(for: selectedCollection)
                        }
                    }
                }
                
            }
            
            .frame(width: 740, height: 455)
        }
    }
}

struct CustomActionButton: View {
    let icon: String
    let text: String
    
    var body: some View {
        Button(action: {}) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 20)
                Text(text)
                    .frame(width: 200, alignment: .leading)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
        }
        .buttonStyle(.plain)
        .background(Color(NSColor.lightGray).opacity(0.1))
        .cornerRadius(6)
    }
}

struct RecentProjectRow: View {
    let projectName: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: "folder")
                .resizable()
                .scaledToFit()
                .fontWeight(.ultraLight)
                .frame(width: 20, height: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(projectName)
                Text("~/Desktop/Webscroll")
                    .font(.system(size: 10))
                    .foregroundColor(Color(NSColor.secondaryLabelColor))
            }
        }
    }
}

#Preview {
    WelcomeScreen()
}
