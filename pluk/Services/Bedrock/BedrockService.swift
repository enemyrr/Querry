import Foundation

final class BedrockService: Sendable {

    static let shared = BedrockService()

    private let credentialManager = CognitoCredentialManager()

    private init() {}

    func warmUpCredentials() {
        Task { try? await credentialManager.getCredentials() }
    }

    func messageRequest(
        messages: [AnthropicMessage],
        system: String,
        tools: [AnthropicToolDefinition],
        maxTokens: Int = 8192
    ) async throws -> BedrockAnthropicResponse {
        let (request, body) = try await buildSignedRequest(
            url: BedrockConfig.bedrockEndpoint,
            messages: messages,
            system: system,
            tools: tools,
            maxTokens: maxTokens,
            thinking: nil,
            additionalHeaders: [("Accept", "application/json")]
        )

        var mutableRequest = request
        mutableRequest.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: mutableRequest)
        try validateHTTPResponse(response, data: data)
        return try Foundation.JSONDecoder().decode(BedrockAnthropicResponse.self, from: data)
    }

    // MARK: - Streaming

    func messageRequestStream(
        messages: [AnthropicMessage],
        system: String,
        tools: [AnthropicToolDefinition],
        maxTokens: Int = 64_000,
        thinking: ThinkingConfig? = .adaptive,
        onTextDelta: @MainActor @Sendable (String) -> Void,
        onThinkingDelta: @MainActor @Sendable (String) -> Void = { _ in }
    ) async throws -> BedrockAnthropicResponse {
        let (request, body) = try await buildSignedRequest(
            url: BedrockConfig.bedrockStreamEndpoint,
            messages: messages,
            system: system,
            tools: tools,
            maxTokens: maxTokens,
            thinking: thinking
        )

        var mutableRequest = request
        mutableRequest.httpBody = body

        let (asyncBytes, response) = try await URLSession.shared.bytes(for: mutableRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BedrockError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            var errorData = Data()
            for try await byte in asyncBytes { errorData.append(byte) }
            let errorBody = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            print("[BedrockService] HTTP \(httpResponse.statusCode): \(errorBody)")
            throw BedrockError.httpError(statusCode: httpResponse.statusCode, body: errorBody)
        }

        var buffer = Data()
        var fullText = ""
        var responseId = ""
        var responseRole = "assistant"
        var stopReason: String?
        var inputTokens = 0
        var outputTokens = 0
        var textBlocks: [Int: String] = [:]
        var thinkingBlocks: [Int: (text: String, signature: String)] = [:]
        var toolUseBlocks: [Int: (id: String, name: String, inputJSON: String)] = [:]

        for try await byte in asyncBytes {
            buffer.append(byte)

            while buffer.count >= 12 {
                let totalLength = buffer.readBigEndianUInt32(at: 0)
                guard buffer.count >= totalLength else { break }

                let headersLength = buffer.readBigEndianUInt32(at: 4)
                let payloadStart = 12 + headersLength
                let payloadEnd = totalLength - 4
                let base = buffer.startIndex

                if payloadStart < payloadEnd {
                    let payload = Data(buffer[(base + payloadStart)..<(base + payloadEnd)])

                    if let wrapper = try? Foundation.JSONDecoder().decode(EventStreamChunk.self, from: payload),
                       let decoded = Data(base64Encoded: wrapper.bytes),
                       let event = try? Foundation.JSONDecoder().decode(AnthropicStreamEvent.self, from: decoded) {
                        switch event.type {
                        case "message_start":
                            if let msg = event.message {
                                responseId = msg.id ?? responseId
                                responseRole = msg.role ?? responseRole
                                if let u = msg.usage {
                                    inputTokens = u.input_tokens ?? inputTokens
                                }
                            }
                        case "content_block_start":
                            if let idx = event.index, let block = event.content_block {
                                switch block.type {
                                case "text": textBlocks[idx] = ""
                                case "thinking": thinkingBlocks[idx] = (text: "", signature: "")
                                case "tool_use": toolUseBlocks[idx] = (id: block.id ?? "", name: block.name ?? "", inputJSON: "")
                                default: break
                                }
                            }
                        case "content_block_delta":
                            if let idx = event.index, let delta = event.delta {
                                switch delta.type {
                                case "text_delta":
                                    if let text = delta.text {
                                        textBlocks[idx, default: ""] += text
                                        fullText += text
                                        await onTextDelta(text)
                                    }
                                case "thinking_delta":
                                    if let thinking = delta.thinking {
                                        if var existing = thinkingBlocks[idx] {
                                            existing.text += thinking
                                            thinkingBlocks[idx] = existing
                                        }
                                        await onThinkingDelta(thinking)
                                    }
                                case "signature_delta":
                                    if let sig = delta.signature, var existing = thinkingBlocks[idx] {
                                        existing.signature += sig
                                        thinkingBlocks[idx] = existing
                                    }
                                case "input_json_delta":
                                    if let json = delta.partial_json, var existing = toolUseBlocks[idx] {
                                        existing.inputJSON += json
                                        toolUseBlocks[idx] = existing
                                    }
                                default:
                                    print("[BedrockService] unhandled delta type: \(delta.type ?? "nil") at index \(idx)")
                                }
                            }
                        case "message_delta":
                            if let delta = event.delta {
                                stopReason = delta.stop_reason ?? stopReason
                                if let u = event.usage {
                                    outputTokens = u.output_tokens ?? outputTokens
                                }
                            }
                        default:
                            break
                        }
                    }
                }

                buffer = Data(buffer.dropFirst(totalLength))
            }
        }

        let content = buildResponseContent(
            textBlocks: textBlocks,
            thinkingBlocks: thinkingBlocks,
            toolUseBlocks: toolUseBlocks
        )

        return BedrockAnthropicResponse(
            id: responseId,
            type: "message",
            role: responseRole,
            content: content,
            stopReason: stopReason,
            usage: BedrockAnthropicResponse.Usage(inputTokens: inputTokens, outputTokens: outputTokens)
        )
    }

    // MARK: - Request Building

    private func buildSignedRequest(
        url: URL,
        messages: [AnthropicMessage],
        system: String,
        tools: [AnthropicToolDefinition],
        maxTokens: Int,
        thinking: ThinkingConfig?,
        additionalHeaders: [(String, String)] = []
    ) async throws -> (URLRequest, Data) {
        let credentials = try await credentialManager.getCredentials()

        let requestBody = BedrockAnthropicRequest(
            anthropicVersion: BedrockConfig.anthropicVersion,
            anthropicBeta: thinking != nil ? ["interleaved-thinking-2025-05-14"] : nil,
            maxTokens: maxTokens,
            system: system,
            messages: messages,
            tools: tools,
            thinking: thinking
        )

        let body = try Foundation.JSONEncoder().encode(requestBody)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (field, value) in additionalHeaders {
            request.setValue(value, forHTTPHeaderField: field)
        }
        request.timeoutInterval = 120

        AWSSignatureV4.sign(
            request: &request,
            body: body,
            credentials: credentials,
            region: BedrockConfig.region,
            service: "bedrock"
        )

        return (request, body)
    }

    private func validateHTTPResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BedrockError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[BedrockService] HTTP \(httpResponse.statusCode): \(errorBody)")
            throw BedrockError.httpError(statusCode: httpResponse.statusCode, body: errorBody)
        }
    }

    // MARK: - Response Content Building

    private func buildResponseContent(
        textBlocks: [Int: String],
        thinkingBlocks: [Int: (text: String, signature: String)],
        toolUseBlocks: [Int: (id: String, name: String, inputJSON: String)]
    ) -> [ResponseContentBlock] {
        let allIndices = Set(textBlocks.keys).union(thinkingBlocks.keys).union(toolUseBlocks.keys).sorted()
        return allIndices.map { idx -> ResponseContentBlock in
            if let thinking = thinkingBlocks[idx] {
                return .thinking(thinking.text, signature: thinking.signature)
            } else if let text = textBlocks[idx] {
                return .text(text)
            } else if let tool = toolUseBlocks[idx] {
                let inputData = Data(tool.inputJSON.utf8)
                let inputDict: [String: any Sendable]
                if let parsed = try? JSONSerialization.jsonObject(with: inputData) as? [String: Any] {
                    inputDict = parsed.mapValues { $0 as any Sendable }
                } else {
                    inputDict = [:]
                }
                return .toolUse(id: tool.id, name: tool.name, input: inputDict)
            } else {
                return .text("")
            }
        }
    }
}

// MARK: - Streaming Event Types

private struct EventStreamChunk: Decodable {
    let bytes: String
}

private struct AnthropicStreamEvent: Decodable {
    let type: String
    let index: Int?
    let message: StreamMessage?
    let content_block: StreamContentBlock?
    let delta: StreamDelta?
    let usage: StreamUsage?
}

private struct StreamMessage: Decodable {
    let id: String?
    let role: String?
    let usage: StreamUsage?
}

private struct StreamContentBlock: Decodable {
    let type: String
    let id: String?
    let name: String?
    let text: String?
}

private struct StreamDelta: Decodable {
    let type: String?
    let text: String?
    let thinking: String?
    let signature: String?
    let partial_json: String?
    let stop_reason: String?
}

private struct StreamUsage: Decodable {
    let input_tokens: Int?
    let output_tokens: Int?
}

// MARK: - Data helpers for big-endian reads

private extension Data {
    func readBigEndianUInt32(at offset: Int) -> Int {
        let b0 = Int(self[startIndex + offset]) << 24
        let b1 = Int(self[startIndex + offset + 1]) << 16
        let b2 = Int(self[startIndex + offset + 2]) << 8
        let b3 = Int(self[startIndex + offset + 3])
        return b0 | b1 | b2 | b3
    }
}

// MARK: - Errors

enum BedrockError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int, body: String)
    case cognitoError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Bedrock"
        case .httpError(let code, let body):
            return "Bedrock HTTP \(code): \(body)"
        case .cognitoError(let message):
            return "Cognito error: \(message)"
        }
    }
}

// MARK: - Cognito Credential Manager

private actor CognitoCredentialManager {

    private var cachedCredentials: AWSSignatureV4.AWSCredentials?
    private var refreshTask: Task<AWSSignatureV4.AWSCredentials, any Error>?

    func getCredentials() async throws -> AWSSignatureV4.AWSCredentials {
        if let cached = cachedCredentials, cached.expiration.timeIntervalSinceNow > 300 {
            return cached
        }

        if let existing = refreshTask {
            return try await existing.value
        }

        let task = Task<AWSSignatureV4.AWSCredentials, any Error> {
            defer { refreshTask = nil }
            let creds = try await fetchNewCredentials()
            cachedCredentials = creds
            return creds
        }
        refreshTask = task
        return try await task.value
    }

    // Basic (classic) auth flow: GetId → GetOpenIdToken → STS AssumeRoleWithWebIdentity
    // This avoids the scope-down session policy that Cognito's enhanced flow applies to unauthenticated identities.

    private func fetchNewCredentials() async throws -> AWSSignatureV4.AWSCredentials {
        let identityId = try await getIdentityId()
        let token = try await getOpenIdToken(identityId)
        return try await assumeRoleWithWebIdentity(token: token)
    }

    private func getIdentityId() async throws -> String {
        var request = URLRequest(url: BedrockConfig.cognitoEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-amz-json-1.1", forHTTPHeaderField: "Content-Type")
        request.setValue("AWSCognitoIdentityService.GetId", forHTTPHeaderField: "X-Amz-Target")

        let body: [String: String] = ["IdentityPoolId": BedrockConfig.identityPoolId]
        request.httpBody = try Foundation.JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"
            throw BedrockError.cognitoError("GetId failed: \(errorBody)")
        }

        struct GetIdResponse: Decodable { let IdentityId: String }
        return try Foundation.JSONDecoder().decode(GetIdResponse.self, from: data).IdentityId
    }

    private func getOpenIdToken(_ identityId: String) async throws -> String {
        var request = URLRequest(url: BedrockConfig.cognitoEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-amz-json-1.1", forHTTPHeaderField: "Content-Type")
        request.setValue("AWSCognitoIdentityService.GetOpenIdToken", forHTTPHeaderField: "X-Amz-Target")

        let body: [String: String] = ["IdentityId": identityId]
        request.httpBody = try Foundation.JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"
            throw BedrockError.cognitoError("GetOpenIdToken failed: \(errorBody)")
        }

        struct TokenResponse: Decodable { let Token: String }
        return try Foundation.JSONDecoder().decode(TokenResponse.self, from: data).Token
    }

    private func assumeRoleWithWebIdentity(token: String) async throws -> AWSSignatureV4.AWSCredentials {
        guard var components = URLComponents(url: BedrockConfig.stsEndpoint, resolvingAgainstBaseURL: false) else {
            throw BedrockError.cognitoError("Invalid STS endpoint URL")
        }
        components.queryItems = [
            URLQueryItem(name: "Action", value: "AssumeRoleWithWebIdentity"),
            URLQueryItem(name: "RoleArn", value: BedrockConfig.roleArn),
            URLQueryItem(name: "RoleSessionName", value: "PlukDesktop"),
            URLQueryItem(name: "WebIdentityToken", value: token),
            URLQueryItem(name: "Version", value: "2011-06-15"),
        ]

        guard let url = components.url else {
            throw BedrockError.cognitoError("Failed to construct STS request URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"
            throw BedrockError.cognitoError("AssumeRoleWithWebIdentity failed: \(errorBody)")
        }

        return try parseSTSResponse(data)
    }

    private func parseSTSResponse(_ data: Data) throws -> AWSSignatureV4.AWSCredentials {
        let xml = String(data: data, encoding: .utf8) ?? ""

        func extract(_ tag: String) -> String? {
            guard let start = xml.range(of: "<\(tag)>"),
                  let end = xml.range(of: "</\(tag)>", range: start.upperBound..<xml.endIndex) else { return nil }
            return String(xml[start.upperBound..<end.lowerBound])
        }

        guard let accessKeyId = extract("AccessKeyId"),
              let secretAccessKey = extract("SecretAccessKey"),
              let sessionToken = extract("SessionToken"),
              let expirationStr = extract("Expiration") else {
            throw BedrockError.cognitoError("Failed to parse STS response")
        }

        let formatter = ISO8601DateFormatter()
        let expiration = formatter.date(from: expirationStr) ?? Date().addingTimeInterval(3600)

        return AWSSignatureV4.AWSCredentials(
            accessKeyId: accessKeyId,
            secretAccessKey: secretAccessKey,
            sessionToken: sessionToken,
            expiration: expiration
        )
    }
}
