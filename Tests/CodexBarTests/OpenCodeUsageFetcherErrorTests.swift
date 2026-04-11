import CodexBarCore
import Foundation
import Testing

@Suite(.serialized)
struct OpenCodeUsageFetcherErrorTests {
    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [OpenCodeStubURLProtocol.self]
        return URLSession(configuration: config)
    }

    @Test
    func `extracts api error from uppercase HTML title`() async throws {
        defer {
            OpenCodeStubURLProtocol.handler = nil
        }

        OpenCodeStubURLProtocol.handler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            let body = "<html><head><TITLE>403 Forbidden</TITLE></head><body>denied</body></html>"
            return Self.makeResponse(url: url, body: body, statusCode: 500, contentType: "text/html")
        }

        do {
            _ = try await OpenCodeUsageFetcher.fetchUsage(
                cookieHeader: "auth=test",
                timeout: 2,
                workspaceIDOverride: "wrk_TEST123",
                session: self.makeSession())
            Issue.record("Expected OpenCodeUsageError.apiError")
        } catch let error as OpenCodeUsageError {
            switch error {
            case let .apiError(message):
                #expect(message.contains("HTTP 500"))
                #expect(message.contains("403 Forbidden"))
            default:
                Issue.record("Expected apiError, got: \(error)")
            }
        }
    }

    @Test
    func `extracts api error from detail field`() async throws {
        defer {
            OpenCodeStubURLProtocol.handler = nil
        }

        OpenCodeStubURLProtocol.handler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            let body = #"{"detail":"Workspace missing"}"#
            return Self.makeResponse(url: url, body: body, statusCode: 500, contentType: "application/json")
        }

        do {
            _ = try await OpenCodeUsageFetcher.fetchUsage(
                cookieHeader: "auth=test",
                timeout: 2,
                workspaceIDOverride: "wrk_TEST123",
                session: self.makeSession())
            Issue.record("Expected OpenCodeUsageError.apiError")
        } catch let error as OpenCodeUsageError {
            switch error {
            case let .apiError(message):
                #expect(message.contains("HTTP 500"))
                #expect(message.contains("Workspace missing"))
            default:
                Issue.record("Expected apiError, got: \(error)")
            }
        }
    }

    @Test
    func `subscription get null skips post and returns graceful error`() async throws {
        defer {
            OpenCodeStubURLProtocol.handler = nil
        }

        var methods: [String] = []
        var urls: [URL] = []
        var queries: [String] = []
        var contentTypes: [String] = []
        OpenCodeStubURLProtocol.handler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            methods.append(request.httpMethod ?? "GET")
            urls.append(url)
            queries.append(url.query ?? "")
            contentTypes.append(request.value(forHTTPHeaderField: "Content-Type") ?? "")

            if request.httpMethod?.uppercased() == "GET" {
                return Self.makeResponse(url: url, body: "null", statusCode: 200, contentType: "application/json")
            }

            let body = #"{"status":500,"unhandled":true,"message":"HTTPError"}"#
            return Self.makeResponse(url: url, body: body, statusCode: 500, contentType: "application/json")
        }

        do {
            _ = try await OpenCodeUsageFetcher.fetchUsage(
                cookieHeader: "auth=test",
                timeout: 2,
                workspaceIDOverride: "wrk_TEST123",
                session: self.makeSession())
            Issue.record("Expected OpenCodeUsageError.parseFailed")
        } catch let error as OpenCodeUsageError {
            switch error {
            case let .parseFailed(message):
                #expect(message.contains("Missing usage fields"))
            default:
                Issue.record("Expected parseFailed, got: \(error)")
            }
        }

        #expect(methods == ["GET", "GET", "GET"])
        #expect(queries[0].contains("id="))
        #expect(queries[0].contains("wrk_TEST123"))
        #expect(urls[0].path == "/_server")
        #expect(contentTypes[0].isEmpty)
        #expect(urls[1].path == "/workspace/wrk_TEST123/go")
        #expect(contentTypes[1].isEmpty)
        #expect(urls[2].path == "/workspace/wrk_TEST123/billing")
        #expect(contentTypes[2].isEmpty)
    }

    @Test
    func invalidCredentialsDoesNotFallbackToBilling() async throws {
        let registered = URLProtocol.registerClass(OpenCodeStubURLProtocol.self)
        defer {
            if registered {
                URLProtocol.unregisterClass(OpenCodeStubURLProtocol.self)
            }
            OpenCodeStubURLProtocol.handler = nil
        }

        var methodsByPath: [String] = []
        OpenCodeStubURLProtocol.handler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            methodsByPath.append("\(request.httpMethod ?? "GET") \(url.path)")
            return Self.makeResponse(
                url: url,
                body: #"{"status":401,"message":"unauthorized"}"#,
                statusCode: 401,
                contentType: "application/json")
        }

        do {
            _ = try await OpenCodeUsageFetcher.fetchUsage(
                cookieHeader: "auth=test",
                timeout: 2,
                workspaceIDOverride: "wrk_TEST123")
            Issue.record("Expected OpenCodeUsageError.invalidCredentials")
        } catch let error as OpenCodeUsageError {
            switch error {
            case .invalidCredentials:
                break
            default:
                Issue.record("Expected invalidCredentials, got: \(error)")
            }
        }

        #expect(methodsByPath == ["GET /_server"])
    }

    @Test
    func subscriptionNullFallsBackToBillingParser() async throws {
        let registered = URLProtocol.registerClass(OpenCodeStubURLProtocol.self)
        defer {
            if registered {
                URLProtocol.unregisterClass(OpenCodeStubURLProtocol.self)
            }
            OpenCodeStubURLProtocol.handler = nil
        }

        var methodsByPath: [String] = []
        OpenCodeStubURLProtocol.handler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            methodsByPath.append("\(request.httpMethod ?? "GET") \(url.path)")

            if url.path == "/_server" {
                let query = url.query ?? ""
                if query.contains("id=7abeebee372f304e050aaaf92be863f4a86490e382f8c79db68fd94040d691b4") {
                    return Self.makeResponse(
                        url: url,
                        body: "null",
                        statusCode: 200,
                        contentType: "text/javascript")
                }
                return Self.makeResponse(
                    url: url,
                    body: #"{"status":500,"message":"unexpected id"}"#,
                    statusCode: 500,
                    contentType: "application/json")
            }

            if url.path == "/workspace/wrk_TEST123/go" {
                return Self.makeResponse(
                    url: url,
                    body: #"{"status":404,"message":"not found"}"#,
                    statusCode: 404,
                    contentType: "application/json")
            }

            if url.path == "/workspace/wrk_TEST123/billing" {
                let body = """
                <h2>Go Subscription</h2>
                <p>You are subscribed to OpenCode Go.</p>
                <script>
                rollingUsage:$R[47]={status:"ok",resetInSec:111,usagePercent:9},
                weeklyUsage:$R[48]={status:"ok",resetInSec:222,usagePercent:4}
                </script>
                """
                return Self.makeResponse(
                    url: url,
                    body: body,
                    statusCode: 200,
                    contentType: "text/html")
            }

            return Self.makeResponse(
                url: url,
                body: #"{"status":404,"message":"not found"}"#,
                statusCode: 404,
                contentType: "application/json")
        }

        let snapshot = try await OpenCodeUsageFetcher.fetchUsage(
            cookieHeader: "auth=test",
            timeout: 2,
            workspaceIDOverride: "wrk_TEST123")

        #expect(snapshot.rollingUsagePercent == 9)
        #expect(snapshot.weeklyUsagePercent == 4)
        #expect(snapshot.rollingResetInSec == 111)
        #expect(snapshot.weeklyResetInSec == 222)
        #expect(snapshot.planName == "OpenCode Go")
        #expect(methodsByPath == [
            "GET /_server",
            "GET /workspace/wrk_TEST123/go",
            "GET /workspace/wrk_TEST123/billing",
        ])
    }

    @Test
    func subscriptionNullFallsBackToGoParser() async throws {
        let registered = URLProtocol.registerClass(OpenCodeStubURLProtocol.self)
        defer {
            if registered {
                URLProtocol.unregisterClass(OpenCodeStubURLProtocol.self)
            }
            OpenCodeStubURLProtocol.handler = nil
        }

        var methodsByPath: [String] = []
        OpenCodeStubURLProtocol.handler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            methodsByPath.append("\(request.httpMethod ?? "GET") \(url.path)")

            if url.path == "/_server" {
                let query = url.query ?? ""
                if query.contains("id=7abeebee372f304e050aaaf92be863f4a86490e382f8c79db68fd94040d691b4") {
                    return Self.makeResponse(
                        url: url,
                        body: "null",
                        statusCode: 200,
                        contentType: "text/javascript")
                }
                return Self.makeResponse(
                    url: url,
                    body: #"{"status":500,"message":"unexpected id"}"#,
                    statusCode: 500,
                    contentType: "application/json")
            }

            if url.path == "/workspace/wrk_TEST123/go" {
                let body = """
                <p>You are subscribed to OpenCode Go.</p>
                <script>
                rollingUsage:$R[47]={status:"ok",resetInSec:333,usagePercent:12},
                weeklyUsage:$R[48]={status:"ok",resetInSec:444,usagePercent:7},
                monthlyUsage:$R[49]={status:"ok",resetInSec:555,usagePercent:3}
                </script>
                """
                return Self.makeResponse(
                    url: url,
                    body: body,
                    statusCode: 200,
                    contentType: "text/html")
            }

            return Self.makeResponse(
                url: url,
                body: #"{"status":404,"message":"not found"}"#,
                statusCode: 404,
                contentType: "application/json")
        }

        let snapshot = try await OpenCodeUsageFetcher.fetchUsage(
            cookieHeader: "auth=test",
            timeout: 2,
            workspaceIDOverride: "wrk_TEST123")

        #expect(snapshot.rollingUsagePercent == 12)
        #expect(snapshot.weeklyUsagePercent == 7)
        #expect(snapshot.rollingResetInSec == 333)
        #expect(snapshot.weeklyResetInSec == 444)
        #expect(snapshot.planName == "OpenCode Go")
        #expect(methodsByPath == ["GET /_server", "GET /workspace/wrk_TEST123/go"])
    }

    @Test
    func `subscription get payload does not fallback to post`() async throws {
        defer {
            OpenCodeStubURLProtocol.handler = nil
        }

        var methods: [String] = []
        OpenCodeStubURLProtocol.handler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            methods.append(request.httpMethod ?? "GET")

            let body = """
            {
              "rollingUsage": { "usagePercent": 17, "resetInSec": 600 },
              "weeklyUsage": { "usagePercent": 75, "resetInSec": 7200 }
            }
            """
            return Self.makeResponse(url: url, body: body, statusCode: 200, contentType: "application/json")
        }

        let snapshot = try await OpenCodeUsageFetcher.fetchUsage(
            cookieHeader: "auth=test",
            timeout: 2,
            workspaceIDOverride: "wrk_TEST123",
            session: self.makeSession())

        #expect(snapshot.rollingUsagePercent == 17)
        #expect(snapshot.weeklyUsagePercent == 75)
        #expect(methods == ["GET"])
    }

    @Test
    func `workspace get public actor error is treated as invalid credentials without post retry`() async throws {
        defer {
            OpenCodeStubURLProtocol.handler = nil
        }

        var methods: [String] = []
        OpenCodeStubURLProtocol.handler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            methods.append(request.httpMethod ?? "GET")
            let body = [
                #";0x00000263;((self.$R=self.$R||{})["server-fn:test"]=[],"#,
                #"($R=>$R[0]=Object.assign(new Error("actor of type \"public\" is not associated with an account"),"#,
                #"{stack:"Error: actor of type \"public\" is not associated with an account"}))"#,
                #"($R["server-fn:test"]))"#,
            ].joined()
            return Self.makeResponse(
                url: url,
                body: body,
                statusCode: 200,
                contentType: "text/javascript")
        }

        do {
            _ = try await OpenCodeUsageFetcher.fetchUsage(
                cookieHeader: "auth=test",
                timeout: 2,
                session: self.makeSession())
            Issue.record("Expected OpenCodeUsageError.invalidCredentials")
        } catch let error as OpenCodeUsageError {
            switch error {
            case .invalidCredentials:
                break
            default:
                Issue.record("Expected invalidCredentials, got: \(error)")
            }
        }

        #expect(methods == ["GET"])
    }

    @Test
    func `subscription get missing fields falls back to post`() async throws {
        defer {
            OpenCodeStubURLProtocol.handler = nil
        }

        var methods: [String] = []
        OpenCodeStubURLProtocol.handler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            methods.append(request.httpMethod ?? "GET")

            if request.httpMethod?.uppercased() == "GET" {
                return Self.makeResponse(
                    url: url,
                    body: #"{"ok":true}"#,
                    statusCode: 200,
                    contentType: "application/json")
            }

            let body = """
            {
              "rollingUsage": { "usagePercent": 22, "resetInSec": 300 },
              "weeklyUsage": { "usagePercent": 44, "resetInSec": 3600 }
            }
            """
            return Self.makeResponse(
                url: url,
                body: body,
                statusCode: 200,
                contentType: "application/json")
        }

        let snapshot = try await OpenCodeUsageFetcher.fetchUsage(
            cookieHeader: "auth=test",
            timeout: 2,
            workspaceIDOverride: "wrk_TEST123",
            session: self.makeSession())

        #expect(snapshot.rollingUsagePercent == 22)
        #expect(snapshot.weeklyUsagePercent == 44)
        #expect(methods == ["GET", "POST"])
    }

    @Test
    func `fetcher sends only auth cookie to opencode host`() async throws {
        defer {
            OpenCodeStubURLProtocol.handler = nil
        }

        var observedCookie: String?
        OpenCodeStubURLProtocol.handler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            observedCookie = request.value(forHTTPHeaderField: "Cookie")

            let body = """
            {
              "rollingUsage": { "usagePercent": 17, "resetInSec": 600 },
              "weeklyUsage": { "usagePercent": 75, "resetInSec": 7200 }
            }
            """
            return Self.makeResponse(url: url, body: body, statusCode: 200, contentType: "application/json")
        }

        _ = try await OpenCodeUsageFetcher.fetchUsage(
            cookieHeader: "provider=google; auth=test",
            timeout: 2,
            workspaceIDOverride: "wrk_TEST123",
            session: self.makeSession())

        #expect(observedCookie == "auth=test")
    }

    private static func makeResponse(
        url: URL,
        body: String,
        statusCode: Int,
        contentType: String) -> (HTTPURLResponse, Data)
    {
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": contentType])!
        return (response, Data(body.utf8))
    }
}

final class OpenCodeStubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override static func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "opencode.ai"
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            self.client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(self.request)
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: data)
            self.client?.urlProtocolDidFinishLoading(self)
        } catch {
            self.client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
