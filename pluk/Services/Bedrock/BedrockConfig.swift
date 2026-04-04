import Foundation

enum BedrockConfig {
    static let region = "us-east-1"
    static let identityPoolId = "us-east-1:e863e357-a433-41b9-b1fa-e188555b52b1"
    static let roleArn = "arn:aws:iam::416783822214:role/PlukBedrockUnauthRole"
    static let modelId = haikuModelId
    static let haikuModelId = "us.anthropic.claude-haiku-4-5-20251001-v1:0"
    static let glm47ModelId = "zai.glm-4.7"
    static let glm5ModelId = "zai.glm-5"
    static let anthropicVersion = "bedrock-2023-05-31"

    static func bedrockEndpoint(for model: String = modelId) -> URL {
        URL(string: "https://bedrock-runtime.\(region).amazonaws.com/model/\(model)/invoke")!
    }

    static func bedrockStreamEndpoint(for model: String = modelId) -> URL {
        URL(string: "https://bedrock-runtime.\(region).amazonaws.com/model/\(model)/invoke-with-response-stream")!
    }

    static var bedrockRuntimeChatCompletionsURL: URL {
        URL(string: "https://bedrock-runtime.\(region).amazonaws.com/openai/v1/chat/completions")!
    }

    static var cognitoEndpoint: URL {
        URL(string: "https://cognito-identity.\(region).amazonaws.com")!
    }

    static var stsEndpoint: URL {
        URL(string: "https://sts.\(region).amazonaws.com")!
    }
}
