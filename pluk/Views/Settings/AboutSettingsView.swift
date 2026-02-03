//
//  AboutSettingsView.swift
//  Pluk
//

import SwiftUI

struct AboutSettingsView: View {
    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    if let appIcon = NSApplication.shared.applicationIconImage {
                        Image(nsImage: appIcon)
                            .resizable()
                            .frame(width: 64, height: 64)
                            .clipShape(.rect(cornerRadius: 14))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pluk")
                            .font(.title)
                            .fontWeight(.medium)

                        Text("Version \(Bundle.main.appVersion) (\(Bundle.main.buildNumber))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .padding(.vertical, 8)

                Button("Check for Updates") {
                    SparkleUpdaterManager.shared.checkForUpdates()
                }
            }

            Section {
                LabeledContent("Website") {
                    Button("pluk.sh") {
                        NSWorkspace.shared.open(URL(string: "https://pluk.sh")!)
                    }
                    .buttonStyle(.link)
                    .foregroundStyle(.orange)
                }

                LabeledContent("GitHub") {
                    Button("pluk-inc/Pluk") {
                        NSWorkspace.shared.open(URL(string: "https://github.com/pluk-inc/Pluk")!)
                    }
                    .buttonStyle(.link)
                    .foregroundStyle(.orange)
                }

                LabeledContent("Support") {
                    Button("support@pluk.sh") {
                        NSWorkspace.shared.open(URL(string: "mailto:support@pluk.sh")!)
                    }
                    .buttonStyle(.link)
                    .foregroundStyle(.orange)
                }
            }

            Section {
                Text("Copyright © 2025-\(Date.now.formatted(.dateTime.year())) Pluk, Inc.\nAll Rights Reserved.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .tint(.orange)
    }
}

#Preview {
    AboutSettingsView()
        .frame(width: 500, height: 400)
}
