import Foundation

enum BedrockGLMError: LocalizedError {
    case invalidResponse
    case missingMessage
    case httpError(statusCode: Int, body: String)
    case invalidToolArguments(name: String, arguments: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Bedrock GLM returned an invalid response."
        case .missingMessage:
            "Bedrock GLM returned no assistant message."
        case .httpError(let statusCode, let body):
            "Bedrock GLM request failed with HTTP \(statusCode): \(body)"
        case .invalidToolArguments(let name, let arguments):
            "Bedrock GLM returned invalid arguments for \(name): \(arguments)"
        }
    }
}

// MARK: - Public Types

struct BedrockGLMToolDefinition: Sendable {
    let name: String
    let description: String
    let inputSchema: [String: JSONValue]
}

struct BedrockGLMToolCall: Sendable {
    let id: String
    let name: String
    let arguments: String
}

enum BedrockThinkingMode: String, Sendable {
    case enabled
    case disabled
}

struct BedrockGLMChatMessage: Sendable {
    enum Role: String, Sendable {
        case system
        case user
        case assistant
        case tool
    }

    let role: Role
    var content: String?
    var reasoningContent: String?
    var toolCalls: [BedrockGLMToolCall]?
    var toolCallId: String?
    var name: String?
}

struct BedrockGLMChatResult: Sendable {
    let assistantMessage: BedrockGLMChatMessage
    let content: [ResponseContentBlock]
    var stopReason: String? = nil
    var tokenUsage: BedrockTokenUsage? = nil
}

struct BedrockTokenUsage: Sendable, Equatable {
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationInputTokens: Int
    let cacheReadInputTokens: Int

    var totalTokens: Int {
        inputTokens + outputTokens + cacheCreationInputTokens + cacheReadInputTokens
    }
}

// MARK: - Service

final class BedrockGLMService: Sendable {

    static let shared = BedrockGLMService()
    private let credentialManager = CognitoCredentialManager.shared

    private init() {}

    // MARK: - Streaming

    func chatCompletionStream(
        messages: [BedrockGLMChatMessage],
        systemPrompt: String? = nil,
        tools: [BedrockGLMToolDefinition] = [],
        maxTokens: Int = 32_000,
        model: String = BedrockConfig.glm5ModelId,
        temperature: Double = 1.0,
        thinkingMode: BedrockThinkingMode = .enabled,
        onTextDelta: @MainActor @Sendable (String) -> Void,
        onThinkingDelta: @MainActor @Sendable (String) -> Void = { _ in }
    ) async throws -> BedrockGLMChatResult {
        let (request, body) = try await buildSignedRequest(
            messages: messages, systemPrompt: systemPrompt, tools: tools,
            maxTokens: maxTokens, model: model, stream: true,
            temperature: temperature, thinkingMode: thinkingMode
        )

        var mutableRequest = request
        mutableRequest.httpBody = body

        let (bytes, response) = try await URLSession.shared.bytes(for: mutableRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BedrockGLMError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            var errorBody = ""
            for try await line in bytes.lines { errorBody += line }
            throw BedrockGLMError.httpError(statusCode: httpResponse.statusCode, body: errorBody)
        }

        var fullText = ""
        var fullReasoning = ""
        var toolCallsByIndex: [Int: StreamingToolCall] = [:]

        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst(6))
            if payload == "[DONE]" { break }

            guard let chunkData = payload.data(using: .utf8),
                  let chunk = try? Foundation.JSONDecoder().decode(StreamChunk.self, from: chunkData),
                  let choice = chunk.choices.first else { continue }

            if let reasoning = choice.delta.reasoningContent, !reasoning.isEmpty {
                fullReasoning += reasoning
                await onThinkingDelta(reasoning)
            }

            if let content = choice.delta.content, !content.isEmpty {
                fullText += content
                await onTextDelta(content)
            }

            if let toolCalls = choice.delta.toolCalls {
                for partialCall in toolCalls {
                    let index = partialCall.index ?? 0
                    var existing = toolCallsByIndex[index] ?? StreamingToolCall()
                    if let id = partialCall.id, !id.isEmpty { existing.id = id }
                    if let type = partialCall.type, !type.isEmpty { existing.type = type }
                    if let function = partialCall.function {
                        if let name = function.name, !name.isEmpty { existing.name = name }
                        if let arguments = function.arguments, !arguments.isEmpty { existing.arguments += arguments }
                    }
                    toolCallsByIndex[index] = existing
                }
            }
        }

        let toolCalls = toolCallsByIndex.keys.sorted().compactMap { index -> BedrockGLMToolCall? in
            guard let call = toolCallsByIndex[index], !call.name.isEmpty else { return nil }
            return BedrockGLMToolCall(id: call.id.isEmpty ? "tool_\(index)" : call.id, name: call.name, arguments: call.arguments)
        }

        let assistantMessage = BedrockGLMChatMessage(
            role: .assistant,
            content: fullText.isEmpty ? nil : fullText,
            reasoningContent: fullReasoning.isEmpty ? nil : fullReasoning,
            toolCalls: toolCalls.isEmpty ? nil : toolCalls
        )

        return BedrockGLMChatResult(assistantMessage: assistantMessage, content: buildResponseContent(from: assistantMessage))
    }

    // MARK: - Non-streaming

    func chatCompletion(
        messages: [BedrockGLMChatMessage],
        systemPrompt: String? = nil,
        tools: [BedrockGLMToolDefinition] = [],
        maxTokens: Int = 16_000,
        model: String = BedrockConfig.glm5ModelId,
        temperature: Double = 1.0,
        thinkingMode: BedrockThinkingMode = .enabled
    ) async throws -> BedrockGLMChatResult {
        let (request, body) = try await buildSignedRequest(
            messages: messages, systemPrompt: systemPrompt, tools: tools,
            maxTokens: maxTokens, model: model, stream: false,
            temperature: temperature, thinkingMode: thinkingMode
        )

        var mutableRequest = request
        mutableRequest.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: mutableRequest)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw BedrockGLMError.httpError(statusCode: code, body: errorBody)
        }

        let completion = try Foundation.JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let message = completion.choices.first?.message else {
            throw BedrockGLMError.missingMessage
        }

        let assistantMessage = BedrockGLMChatMessage(
            role: .assistant,
            content: message.content,
            reasoningContent: message.reasoningContent,
            toolCalls: message.toolCalls?.map {
                BedrockGLMToolCall(id: $0.id, name: $0.function.name, arguments: $0.function.arguments)
            }
        )

        return BedrockGLMChatResult(assistantMessage: assistantMessage, content: buildResponseContent(from: assistantMessage))
    }

    // MARK: - Request Building

    private func buildSignedRequest(
        messages: [BedrockGLMChatMessage],
        systemPrompt: String?,
        tools: [BedrockGLMToolDefinition],
        maxTokens: Int,
        model: String,
        stream: Bool,
        temperature: Double,
        thinkingMode: BedrockThinkingMode
    ) async throws -> (URLRequest, Data) {
        let credentials = try await credentialManager.getCredentials()

        var requestMessages: [OpenAIMessage] = []
        if let systemPrompt, !systemPrompt.isEmpty {
            requestMessages.append(OpenAIMessage(role: BedrockGLMChatMessage.Role.system.rawValue, content: systemPrompt))
        }

        for msg in messages {
            var m = OpenAIMessage(role: msg.role.rawValue, content: msg.content)
            m.reasoningContent = msg.reasoningContent
            m.toolCallId = msg.toolCallId
            m.name = msg.name
            if let toolCalls = msg.toolCalls {
                m.toolCalls = toolCalls.map {
                    OpenAIToolCall(id: $0.id, type: "function", function: .init(name: $0.name, arguments: $0.arguments))
                }
            }
            requestMessages.append(m)
        }

        let openAITools: [OpenAIToolDef]? = tools.isEmpty ? nil : tools.map {
            OpenAIToolDef(function: .init(name: $0.name, description: $0.description, parameters: $0.inputSchema))
        }

        let requestBody = ChatCompletionRequest(
            model: model,
            messages: requestMessages,
            tools: openAITools,
            stream: stream,
            temperature: temperature,
            maxTokens: maxTokens,
            thinking: ThinkingParam(type: thinkingMode.rawValue)
        )

        let encodedBody = try Foundation.JSONEncoder().encode(requestBody)

        var request = URLRequest(url: BedrockConfig.bedrockRuntimeChatCompletionsURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(stream ? "text/event-stream" : "application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 300

        AWSSignatureV4.sign(request: &request, body: encodedBody, credentials: credentials, region: BedrockConfig.region, service: "bedrock")

        return (request, encodedBody)
    }

    // MARK: - Response Content Building

    private func buildResponseContent(from message: BedrockGLMChatMessage) -> [ResponseContentBlock] {
        var content: [ResponseContentBlock] = []

        if let reasoning = message.reasoningContent, !reasoning.isEmpty {
            content.append(.thinking(reasoning, signature: ""))
        }
        if let text = message.content, !text.isEmpty {
            content.append(.text(text))
        }
        for toolCall in message.toolCalls ?? [] {
            let inputData = Data(toolCall.arguments.utf8)
            if let parsed = try? Foundation.JSONDecoder().decode([String: JSONValue].self, from: inputData) {
                content.append(.toolUse(id: toolCall.id, name: toolCall.name, input: parsed.mapValues { $0.toSendable() }))
            } else {
                content.append(.toolUse(id: toolCall.id, name: toolCall.name, input: [:]))
            }
        }

        return content
    }
}

// MARK: - OpenAI-compatible Request Types

private struct OpenAIMessage: Encodable {
    let role: String
    let content: String?
    var reasoningContent: String?
    var toolCalls: [OpenAIToolCall]?
    var toolCallId: String?
    var name: String?

    enum CodingKeys: String, CodingKey {
        case role, content
        case reasoningContent = "reasoning_content"
        case toolCalls = "tool_calls"
        case toolCallId = "tool_call_id"
        case name
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(reasoningContent, forKey: .reasoningContent)
        try container.encodeIfPresent(toolCalls, forKey: .toolCalls)
        try container.encodeIfPresent(toolCallId, forKey: .toolCallId)
        try container.encodeIfPresent(name, forKey: .name)
    }
}

private struct OpenAIToolCall: Encodable {
    let id: String
    let type: String
    let function: OpenAIFunction

    struct OpenAIFunction: Encodable {
        let name: String
        let arguments: String
    }
}

private struct OpenAIToolDef: Encodable {
    let type = "function"
    let function: FunctionDef

    struct FunctionDef: Encodable {
        let name: String
        let description: String
        let parameters: [String: JSONValue]
    }
}

private struct ThinkingParam: Encodable {
    let type: String
}

private struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [OpenAIMessage]
    let tools: [OpenAIToolDef]?
    let stream: Bool
    let temperature: Double
    let maxTokens: Int
    let thinking: ThinkingParam

    enum CodingKeys: String, CodingKey {
        case model, messages, tools, stream, temperature, thinking
        case maxTokens = "max_tokens"
    }
}

// MARK: - OpenAI-compatible Response Types

private struct ChatCompletionResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: ResponseMessage
    }

    struct ResponseMessage: Decodable {
        let content: String?
        let reasoningContent: String?
        let toolCalls: [ResponseToolCall]?

        enum CodingKeys: String, CodingKey {
            case content
            case reasoningContent = "reasoning_content"
            case toolCalls = "tool_calls"
        }
    }

    struct ResponseToolCall: Decodable {
        let id: String
        let function: ResponseFunction
    }

    struct ResponseFunction: Decodable {
        let name: String
        let arguments: String
    }
}

private struct StreamChunk: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let delta: Delta
    }
}

private struct Delta: Decodable {
    let content: String?
    let reasoningContent: String?
    let toolCalls: [DeltaToolCall]?

    enum CodingKeys: String, CodingKey {
        case content
        case reasoningContent = "reasoning_content"
        case toolCalls = "tool_calls"
    }
}

private struct DeltaToolCall: Decodable {
    let index: Int?
    let id: String?
    let type: String?
    let function: DeltaToolFunction?
}

private struct DeltaToolFunction: Decodable {
    let name: String?
    let arguments: String?
}

private struct StreamingToolCall {
    var id = ""
    var type = ""
    var name = ""
    var arguments = ""
}
