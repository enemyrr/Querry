//
//  AISettingsView.swift
//  Pluk
//

import SwiftUI

struct AISettingsView: View {
    @AppStorage("enableAIFeatures") private var enableAIFeatures = true
    @AppStorage("showAIErrorSuggestions") private var showAIErrorSuggestions = true

    @AppStorage("aiProvider") private var aiProvider = AIProvider.anthropic.rawValue
    @AppStorage("aiModel") private var aiModel = AIModel.claudeSonnet.rawValue
    @AppStorage("aiApiKey") private var aiApiKey = ""
    @State private var showApiKey = false

    @AppStorage("includeSchemaInContext") private var includeSchemaInContext = true
    @AppStorage("autoSuggestQueries") private var autoSuggestQueries = false
    @AppStorage("aiMaxTokens") private var aiMaxTokens = 2048
    @AppStorage("aiTemperature") private var aiTemperature = 0.3

    @AppStorage("sendQueryHistoryToAI") private var sendQueryHistoryToAI = false
    @AppStorage("anonymizeNamesInAIRequests") private var anonymizeNamesInAIRequests = false

    var body: some View {
        Form {
            aiFeaturesSection
            modelConfigSection
            behaviorSection
            privacySection
        }
        .formStyle(.grouped)
    }

    private var aiFeaturesSection: some View {
        Section("AI Features") {
            Toggle("Enable AI features", isOn: $enableAIFeatures)
            Toggle("Show AI suggestions for query errors", isOn: $showAIErrorSuggestions)
        }
    }

    private var modelConfigSection: some View {
        Section("Model Configuration") {
            Picker("AI Provider", selection: $aiProvider) {
                ForEach(AIProvider.allCases, id: \.rawValue) { provider in
                    Label(provider.rawValue, systemImage: provider.icon).tag(provider.rawValue)
                }
            }

            Picker("Model", selection: $aiModel) {
                ForEach(AIModel.allCases, id: \.rawValue) { model in
                    Label(model.rawValue, systemImage: model.icon).tag(model.rawValue)
                }
            }

            HStack {
                Text("API Key")
                Spacer()
                if showApiKey {
                    TextField("", text: $aiApiKey)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                } else {
                    SecureField("", text: $aiApiKey)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                }
                Button(showApiKey ? "Hide" : "Reveal") {
                    showApiKey.toggle()
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private var behaviorSection: some View {
        Section("Behavior") {
            Toggle("Include table schema in AI context", isOn: $includeSchemaInContext)
            Toggle("Auto-suggest queries based on table structure", isOn: $autoSuggestQueries)

            HStack {
                Text("Max tokens")
                Spacer()
                TextField("", value: $aiMaxTokens, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
            }

            VStack(alignment: .leading) {
                HStack {
                    Text("Temperature")
                    Spacer()
                    Text(aiTemperature.formatted(.number.precision(.fractionLength(1))))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $aiTemperature, in: 0...1, step: 0.1)
            }
        }
    }

    private var privacySection: some View {
        Section("Privacy") {
            Toggle("Send query history to AI for context", isOn: $sendQueryHistoryToAI)
            Toggle("Anonymize table/column names in AI requests", isOn: $anonymizeNamesInAIRequests)
        }
    }
}

#Preview {
    AISettingsView()
        .frame(width: 500, height: 500)
}
