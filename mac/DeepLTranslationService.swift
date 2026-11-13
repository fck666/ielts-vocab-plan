import Foundation
import Security

enum DeepLKeychain {
    private static let service = Bundle.main.bundleIdentifier ?? "local.ielts.vocabulary.lab"
    private static let account = "deepl-api-key"

    static func read() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            throw DeepLKeychainError(status: status)
        }
        return key
    }

    static func save(_ key: String) throws {
        let data = Data(key.utf8)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = baseQuery
            attributes.forEach { item[$0.key] = $0.value }
            let addStatus = SecItemAdd(item as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw DeepLKeychainError(status: addStatus) }
        } else if status != errSecSuccess {
            throw DeepLKeychainError(status: status)
        }
    }

    static func delete() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw DeepLKeychainError(status: status)
        }
    }

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

private struct DeepLKeychainError: LocalizedError {
    let status: OSStatus
    var errorDescription: String? { "无法访问 macOS 钥匙串（错误码 \(status)）。" }
}

struct DeepLTranslationService {
    private struct RequestBody: Encodable {
        let text: [String]
        let source_lang: String
        let target_lang: String
    }

    private struct ResponseBody: Decodable {
        struct Translation: Decodable { let text: String }
        let translations: [Translation]
    }

    private struct ErrorBody: Decodable { let message: String? }

    func translate(_ text: String, from source: String, to target: String, apiKey: String) async throws -> String {
        let endpoint = apiKey.hasSuffix(":fx")
            ? "https://api-free.deepl.com/v2/translate"
            : "https://api.deepl.com/v2/translate"
        guard let url = URL(string: endpoint) else { throw DeepLTranslationError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("DeepL-Auth-Key \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(RequestBody(
            text: [text],
            source_lang: source,
            target_lang: target
        ))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw DeepLTranslationError.invalidResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            let message = (try? JSONDecoder().decode(ErrorBody.self, from: data).message)
            throw DeepLTranslationError.service(message ?? "HTTP \(response.statusCode)")
        }
        guard let result = try JSONDecoder().decode(ResponseBody.self, from: data).translations.first?.text else {
            throw DeepLTranslationError.emptyResult
        }
        return result
    }
}

private enum DeepLTranslationError: LocalizedError {
    case invalidResponse
    case emptyResult
    case service(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "DeepL 返回了无法识别的响应。"
        case .emptyResult: "DeepL 没有返回译文。"
        case .service(let message): "DeepL 翻译失败：\(message)"
        }
    }
}
