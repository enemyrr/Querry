import Foundation
import CryptoKit

enum AWSSignatureV4 {

    struct AWSCredentials: Sendable {
        let accessKeyId: String
        let secretAccessKey: String
        let sessionToken: String
        let expiration: Date
    }

    static func sign(
        request: inout URLRequest,
        body: Data,
        credentials: AWSCredentials,
        region: String,
        service: String
    ) {
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        dateFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        let amzDate = dateFormatter.string(from: now)

        dateFormatter.dateFormat = "yyyyMMdd"
        let dateStamp = dateFormatter.string(from: now)

        let bodyHash = SHA256.hash(data: body).hexString
        guard let url = request.url, let host = url.host else { return }
        let rawPath = url.path.isEmpty ? "/" : url.path
        let path = uriEncodePath(rawPath)

        request.setValue(host, forHTTPHeaderField: "Host")
        request.setValue(amzDate, forHTTPHeaderField: "X-Amz-Date")
        request.setValue(credentials.sessionToken, forHTTPHeaderField: "X-Amz-Security-Token")
        request.setValue(bodyHash, forHTTPHeaderField: "X-Amz-Content-Sha256")

        let signedHeaders = "content-type;host;x-amz-content-sha256;x-amz-date;x-amz-security-token"

        let canonicalRequest = [
            request.httpMethod ?? "POST",
            path,
            "",
            "content-type:\(request.value(forHTTPHeaderField: "Content-Type") ?? "application/json")",
            "host:\(host)",
            "x-amz-content-sha256:\(bodyHash)",
            "x-amz-date:\(amzDate)",
            "x-amz-security-token:\(credentials.sessionToken)",
            "",
            signedHeaders,
            bodyHash,
        ].joined(separator: "\n")

        let credentialScope = "\(dateStamp)/\(region)/\(service)/aws4_request"
        let canonicalRequestHash = SHA256.hash(data: Data(canonicalRequest.utf8)).hexString

        let stringToSign = [
            "AWS4-HMAC-SHA256",
            amzDate,
            credentialScope,
            canonicalRequestHash,
        ].joined(separator: "\n")

        let signingKey = deriveSigningKey(
            secretKey: credentials.secretAccessKey,
            dateStamp: dateStamp,
            region: region,
            service: service
        )

        let signatureData = HMAC<SHA256>.authenticationCode(for: Data(stringToSign.utf8), using: signingKey)
        let signature = Data(signatureData).hexString

        let authorization = "AWS4-HMAC-SHA256 Credential=\(credentials.accessKeyId)/\(credentialScope), SignedHeaders=\(signedHeaders), Signature=\(signature)"
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
    }

    /// URI-encode each path segment per SigV4 spec: encode everything except unreserved chars (A-Z a-z 0-9 - _ . ~) and forward slashes.
    private static func uriEncodePath(_ path: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~/")
        return path.addingPercentEncoding(withAllowedCharacters: allowed) ?? path
    }

    private static func deriveSigningKey(secretKey: String, dateStamp: String, region: String, service: String) -> SymmetricKey {
        let kDate = hmacSHA256(key: SymmetricKey(data: Data("AWS4\(secretKey)".utf8)), data: Data(dateStamp.utf8))
        let kRegion = hmacSHA256(key: kDate, data: Data(region.utf8))
        let kService = hmacSHA256(key: kRegion, data: Data(service.utf8))
        return hmacSHA256(key: kService, data: Data("aws4_request".utf8))
    }

    private static func hmacSHA256(key: SymmetricKey, data: Data) -> SymmetricKey {
        let signature = HMAC<SHA256>.authenticationCode(for: data, using: key)
        return SymmetricKey(data: Data(signature))
    }
}

private extension Sequence where Element == UInt8 {
    var hexString: String {
        map { let s = String($0, radix: 16); return $0 < 16 ? "0\(s)" : s }.joined()
    }
}
