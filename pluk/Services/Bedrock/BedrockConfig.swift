import Foundation

enum BedrockConfig {
    static let region = "us-east-1"
    static let identityPoolId = "us-east-1:e863e357-a433-41b9-b1fa-e188555b52b1"
    static let roleArn = "arn:aws:iam::416783822214:role/PlukBedrockUnauthRole"
//    static let modelId = "us.anthropic.claude-sonnet-4-5-20250929-v1:0"
    static let modelId = "global.anthropic.claude-sonnet-4-6"
    static let anthropicVersion = "bedrock-2023-05-31"

    static var bedrockEndpoint: URL {
        URL(string: "https://bedrock-runtime.\(region).amazonaws.com/model/\(modelId)/invoke")!
    }

    static var bedrockStreamEndpoint: URL {
        URL(string: "https://bedrock-runtime.\(region).amazonaws.com/model/\(modelId)/invoke-with-response-stream")!
    }

    static var cognitoEndpoint: URL {
        URL(string: "https://cognito-identity.\(region).amazonaws.com")!
    }

    static var stsEndpoint: URL {
        URL(string: "https://sts.\(region).amazonaws.com")!
    }
}
