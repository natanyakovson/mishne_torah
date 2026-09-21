import Foundation
import XCTest
@testable import MishnehTorahApp

final class RemoteContentServiceTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.handler = nil
        URLProtocolStub.requests = []
        super.tearDown()
    }

    func testFetchChangesPaginatesLargeTables() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: configuration)
        let config = SupabaseConfig(projectURL: URL(string: "https://example.supabase.co")!, publishableKey: "publishable")
        let service = RemoteContentService(config: config, session: session, pageSize: 2)

        URLProtocolStub.handler = { request in
            let path = request.url?.path ?? ""
            if path.contains("/content_meta") {
                return try Self.response([["content_version": 1, "schema_version": 2, "updated_at": "2026-09-04T10:00:00Z"]])
            }
            if path.contains("/halakhot") {
                switch request.value(forHTTPHeaderField: "Range") {
                case "0-1":
                    return try Self.response([
                        Self.halakhahJSON(id: "h1", contentID: "halakha:13:1:0"),
                        Self.halakhahJSON(id: "h2", contentID: "halakha:13:2:0")
                    ], start: 0, total: 3)
                case "2-3":
                    return try Self.response([
                        Self.halakhahJSON(id: "h3", contentID: "halakha:13:3:0")
                    ], start: 2, total: 3)
                default:
                    return try Self.response([])
                }
            }
            return try Self.response([])
        }

        let changes = try await service.fetchChanges(localVersion: 0, updatedAfter: nil)

        XCTAssertEqual(changes.halakhot.map(\.contentID), ["halakha:13:1:0", "halakha:13:2:0", "halakha:13:3:0"])
        let halakhahRanges = URLProtocolStub.requests
            .filter { $0.url?.path.contains("/halakhot") == true }
            .compactMap { $0.value(forHTTPHeaderField: "Range") }
        XCTAssertEqual(halakhahRanges, ["0-1", "2-3"])
    }

    func testServerLimitSmallerThanRequestedPageStillFetchesAllRows() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let service = RemoteContentService(config: SupabaseConfig(projectURL: URL(string: "https://example.supabase.co")!, publishableKey: "sb_publishable_test"), session: URLSession(configuration: configuration), pageSize: 1000)
        URLProtocolStub.handler = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            if request.url!.path.contains("/content_meta") {
                return try Self.response([["content_version": 2, "schema_version": 2, "updated_at": "2026-09-04T10:00:00Z"]])
            }
            if request.url!.path.contains("/halakhot") {
                let start = Int(request.value(forHTTPHeaderField: "Range")!.split(separator: "-")[0])!
                XCTAssertTrue(request.url!.absoluteString.contains("content_version"))
                return try Self.response([Self.halakhahJSON(id: "h\(start)", contentID: "halakha:13:\(start):0")], start: start, total: 3)
            }
            return try Self.response([])
        }
        let changes = try await service.fetchChanges(localVersion: 1, updatedAfter: "2026-09-04T10:00:00Z")
        XCTAssertEqual(changes.halakhot.count, 3)
    }

    func testTruncatedEmptyPageFailsInsteadOfReturningPartialCorpus() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let service = RemoteContentService(config: SupabaseConfig(projectURL: URL(string: "https://example.supabase.co")!, publishableKey: "sb_publishable_test"), session: URLSession(configuration: configuration))
        URLProtocolStub.handler = { _ in try Self.response([], total: 1) }
        do {
            _ = try await service.fetchContentMeta()
            XCTFail("Incomplete response must throw")
        } catch {}
    }

    fileprivate static func response(_ rows: [[String: Any]], start: Int = 0, total: Int? = nil) throws -> (HTTPURLResponse, Data) {
        let data = try JSONSerialization.data(withJSONObject: rows)
        let response = HTTPURLResponse(
            url: URL(string: "https://example.supabase.co")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Range": rows.isEmpty ? "*/\(total ?? 0)" : "\(start)-\(start + rows.count - 1)/\(total ?? rows.count)"]
        )!
        return (response, data)
    }

    private static func halakhahJSON(id: String, contentID: String) -> [String: Any] {
        [
            "id": id,
            "content_id": contentID,
            "chapter_id": "chapter-uuid",
            "law_number": 1,
            "part_index": 0,
            "text_ru": "Текст",
            "text_he": "טקסט",
            "notes": [],
            "sort_order": 1,
            "content_version": 1,
            "is_published": true,
            "deleted_at": NSNull(),
            "updated_at": "2026-09-04T10:00:00Z"
        ]
    }
}

private final class URLProtocolStub: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    static var requests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            Self.requests.append(request)
            let (response, data) = try Self.handler?(request) ?? RemoteContentServiceTests.response([])
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
