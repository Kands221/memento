import Foundation

/// Cloud fallback for iPhones that can't run Apple's on-device model (e.g. iPhone 12).
/// Memento calls OpenRouter directly with a key from a git-ignored `CloudAI.plist`. That's fine for a
/// personal demo build, but a shipping app would route through a server so no key lives in the binary.
public struct CloudAIConfig: Sendable, Equatable {
    public static let defaultModel = "anthropic/claude-haiku-5.5"

    public var apiKey: String
    public var solModel: String
    public var taggingModel: String

    public init(apiKey: String, solModel: String = defaultModel, taggingModel: String = defaultModel) {
        self.apiKey = apiKey
        self.solModel = solModel
        self.taggingModel = taggingModel
    }

    /// Keys: `OpenRouterAPIKey`, and optionally `Model`, `SolModel`, `TaggingModel`.
    public init?(plist: [String: Any]) {
        guard let key = (plist["OpenRouterAPIKey"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              key.hasPrefix("sk-") else { return nil }
        let model = plist["Model"] as? String ?? Self.defaultModel
        self.init(apiKey: key, solModel: plist["SolModel"] as? String ?? model,
                  taggingModel: plist["TaggingModel"] as? String ?? model)
    }

    /// Reads `CloudAI.plist` from the app bundle; nil when the build has no key.
    public static func load(from bundle: Bundle = .main) -> CloudAIConfig? {
        guard let url = bundle.url(forResource: "CloudAI", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }
        return CloudAIConfig(plist: plist)
    }
}

public enum CloudAIError: Error, Equatable, Sendable {
    case unauthorized, outOfCredit, rateLimited, unavailable, badResponse
}

public struct CloudMessage: Sendable, Equatable {
    public enum Role: String, Sendable { case system, user, assistant }
    public var role: Role
    public var content: String

    public init(_ role: Role, _ content: String) {
        self.role = role
        self.content = content
    }
}

/// Moves bytes over the network; tests swap in a fake.
public protocol CloudTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (status: Int, body: Data)
    func lines(_ request: URLRequest) async throws -> (status: Int, lines: AsyncThrowingStream<String, any Error>)
}

public struct URLSessionTransport: CloudTransport {
    public init() {}

    public func send(_ request: URLRequest) async throws -> (status: Int, body: Data) {
        let (data, response) = try await URLSession.shared.data(for: request)
        return ((response as? HTTPURLResponse)?.statusCode ?? 0, data)
    }

    public func lines(_ request: URLRequest) async throws -> (status: Int, lines: AsyncThrowingStream<String, any Error>) {
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        let stream = AsyncThrowingStream<String, any Error> { continuation in
            let task = Task {
                do {
                    for try await line in bytes.lines { continuation.yield(line) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
        return ((response as? HTTPURLResponse)?.statusCode ?? 0, stream)
    }
}

/// OpenRouter chat completions with strict JSON-schema output.
public struct OpenRouterClient: Sendable {
    public static let endpoint = URL(string: "https://openrouter.ai/api/v1/chat/completions")!

    let apiKey: String
    let transport: any CloudTransport
    let retryDelay: Duration

    public init(apiKey: String, transport: any CloudTransport = URLSessionTransport(), retryDelay: Duration = .milliseconds(800)) {
        self.apiKey = apiKey
        self.transport = transport
        self.retryDelay = retryDelay
    }

    /// One JSON object matching `schema`. Retried once on rate limits, server errors and dropped connections.
    public func json(model: String, messages: [CloudMessage], schemaName: String, schema: String,
                     temperature: Double, maxTokens: Int) async throws -> String {
        let request = try makeRequest(model: model, messages: messages, schemaName: schemaName, schema: schema,
                                      temperature: temperature, maxTokens: maxTokens, stream: false)
        var attempt = 0
        while true {
            attempt += 1
            do {
                let (status, body) = try await transport.send(request)
                try Self.check(status: status, body: body)
                guard let content = Self.content(from: body) else { throw CloudAIError.badResponse }
                return content
            } catch where attempt < 2 && Self.isRetryable(error) {
                try await Task.sleep(for: retryDelay)
            } catch {
                throw Self.map(error)
            }
        }
    }

    /// Streams the growing JSON text. Retried once, only if nothing has arrived yet.
    public func streamJSON(model: String, messages: [CloudMessage], schemaName: String, schema: String,
                           temperature: Double, maxTokens: Int) -> AsyncThrowingStream<String, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var text = ""
                var attempt = 0
                while true {
                    attempt += 1
                    do {
                        let request = try makeRequest(model: model, messages: messages, schemaName: schemaName, schema: schema,
                                                      temperature: temperature, maxTokens: maxTokens, stream: true)
                        let (status, lines) = try await transport.lines(request)
                        if !(200..<300).contains(status) {
                            var body = ""
                            for try await line in lines { body += line }
                            try Self.check(status: status, body: Data(body.utf8))
                        }
                        for try await line in lines {
                            guard let delta = try Self.delta(fromEvent: line) else { continue }
                            text += delta
                            continuation.yield(text)
                        }
                        continuation.finish()
                        return
                    } catch where attempt < 2 && text.isEmpty && Self.isRetryable(error) {
                        try? await Task.sleep(for: retryDelay)
                    } catch {
                        continuation.finish(throwing: Self.map(error))
                        return
                    }
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func makeRequest(model: String, messages: [CloudMessage], schemaName: String, schema: String,
                     temperature: Double, maxTokens: Int, stream: Bool) throws -> URLRequest {
        let schemaObject = try JSONSerialization.jsonObject(with: Data(schema.utf8))
        let body: [String: Any] = [
            "model": model,
            "messages": messages.map { ["role": $0.role.rawValue, "content": $0.content] },
            "temperature": temperature,
            "max_tokens": maxTokens,
            "stream": stream,
            "response_format": ["type": "json_schema",
                                "json_schema": ["name": schemaName, "strict": true, "schema": schemaObject]],
            // Only route to providers that don't collect prompts and keep zero data.
            "provider": ["data_collection": "deny", "zdr": true],
        ]
        var request = URLRequest(url: Self.endpoint, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Memento", forHTTPHeaderField: "X-Title")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    static func check(status: Int, body: Data) throws {
        switch status {
        case 200..<300: return
        case 401, 403: throw CloudAIError.unauthorized
        case 402: throw CloudAIError.outOfCredit
        case 429: throw CloudAIError.rateLimited
        case 408, 500...599: throw CloudAIError.unavailable
        default: throw CloudAIError.badResponse
        }
    }

    static func content(from body: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let message = (object["choices"] as? [[String: Any]])?.first?["message"] as? [String: Any],
              let content = message["content"] as? String,
              !content.isEmpty else { return nil }
        return content
    }

    /// The text delta in one server-sent event line, if any. Errors sent mid-stream throw.
    static func delta(fromEvent line: String) throws -> String? {
        guard line.hasPrefix("data:") else { return nil }
        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
        guard payload != "[DONE]",
              let object = try? JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any] else { return nil }
        if object["error"] != nil { throw CloudAIError.unavailable }
        let delta = (object["choices"] as? [[String: Any]])?.first?["delta"] as? [String: Any]
        guard let content = delta?["content"] as? String, !content.isEmpty else { return nil }
        return content
    }

    static func isRetryable(_ error: any Error) -> Bool {
        switch error {
        case CloudAIError.rateLimited, CloudAIError.unavailable, CloudAIError.badResponse: true
        case is URLError: true
        default: false
        }
    }

    static func map(_ error: any Error) -> any Error {
        switch error {
        case is CloudAIError, is CancellationError: error
        default: CloudAIError.unavailable
        }
    }
}

/// Decoding model JSON, tolerating code fences and stray whitespace.
enum JSONText {
    static func decode<T: Decodable>(_ type: T.Type, from text: String) throws -> T {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("```") {
            t = t.drop(while: { $0 != "\n" }).trimmingCharacters(in: .whitespacesAndNewlines)
            if t.hasSuffix("```") { t = String(t.dropLast(3)) }
        }
        return try JSONDecoder().decode(T.self, from: Data(t.utf8))
    }

    /// Serializes a schema written as Swift literals.
    static func schema(_ object: [String: Any]) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data("{}".utf8)
        return String(decoding: data, as: UTF8.self)
    }
}

/// Reads string fields out of a JSON object that is still streaming in.
enum PartialJSON {
    static func string(_ key: String, in text: String) -> String? {
        guard let start = text.range(of: #""\#(key)"\s*:\s*""#, options: .regularExpression) else { return nil }
        var out = ""
        var i = start.upperBound
        while i < text.endIndex {
            let c = text[i]
            if c == "\"" { return out }
            if c == "\\" {
                let n = text.index(after: i)
                guard n < text.endIndex else { return out }
                switch text[n] {
                case "n": out.append("\n")
                case "t": out.append("\t")
                case "r": break
                case "u":
                    let hexStart = text.index(after: n)
                    guard let hexEnd = text.index(hexStart, offsetBy: 4, limitedBy: text.endIndex) else { return out }
                    if let value = UInt32(text[hexStart..<hexEnd], radix: 16), let scalar = Unicode.Scalar(value) {
                        out.unicodeScalars.append(scalar)
                    }
                    i = hexEnd
                    continue
                default: out.append(text[n])
                }
                i = text.index(after: n)
                continue
            }
            out.append(c)
            i = text.index(after: i)
        }
        return out
    }
}
