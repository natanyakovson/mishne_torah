import Foundation

protocol RemoteContentFetching {
    func fetchContentMeta() async throws -> RemoteContentMetaDTO
    func fetchChanges(localVersion: Int, updatedAfter: String?) async throws -> RemoteContentChanges
}

struct RemoteContentService: RemoteContentFetching {
    enum RemoteError: Error {
        case badResponse(Int)
        case emptyMeta
        case incompletePage
        case invalidURL
    }

    private let config: SupabaseConfig
    private let session: URLSession
    private let pageSize: Int

    init(config: SupabaseConfig, session: URLSession = .shared, pageSize: Int = 1_000) {
        self.config = config
        self.session = session
        self.pageSize = max(1, min(pageSize, 1_000))
        _ = SupabaseClientProvider.makeClient(config: config)
    }

    func fetchContentMeta() async throws -> RemoteContentMetaDTO {
        let rows: [RemoteContentMetaDTO] = try await fetchRows(
            table: "content_meta",
            select: "content_version,schema_version,updated_at",
            filters: ["id": "eq.1"],
            order: nil,
            pageSize: 1
        )
        guard let meta = rows.first else {
            throw RemoteError.emptyMeta
        }
        return meta
    }

    func fetchChanges(localVersion: Int, updatedAfter: String?) async throws -> RemoteContentChanges {
        let meta = try await fetchContentMeta()
        var filters = changeFilters(localVersion: localVersion, updatedAfter: updatedAfter)
        // Ignore staged importer rows until their version has been published.
        filters["and"] = "(content_version.lte.\(meta.contentVersion))"

        let books: [RemoteBookDTO] = try await fetchRows(
            table: "books",
            select: "*",
            filters: filters,
            order: "content_id.asc",
            pageSize: pageSize
        )
        let sections: [RemoteSectionDTO] = try await fetchRows(
            table: "sections",
            select: "*",
            filters: filters,
            order: "content_id.asc",
            pageSize: pageSize
        )
        let chapters: [RemoteChapterDTO] = try await fetchRows(
            table: "chapters",
            select: "*",
            filters: filters,
            order: "content_id.asc",
            pageSize: pageSize
        )
        let halakhot: [RemoteHalakhahDTO] = try await fetchRows(
            table: "halakhot",
            select: "*",
            filters: filters,
            order: "content_id.asc",
            pageSize: pageSize
        )

        let tombstones: [RemoteContentTombstoneDTO] = try await fetchRows(
            table: "rpc/content_tombstones", select: "*",
            filters: ["content_version": "gt.\(localVersion)", "and": "(content_version.lte.\(meta.contentVersion))"],
            order: "table_name.asc,content_id.asc", pageSize: pageSize
        )
        return RemoteContentChanges(books: books, sections: sections, chapters: chapters, halakhot: halakhot, tombstones: tombstones)
    }

    private func changeFilters(localVersion: Int, updatedAfter: String?) -> [String: String] {
        let filters = [
            "is_published": "eq.true",
            "deleted_at": "is.null",
            "content_version": "gt.\(localVersion)"
        ]
        return filters
    }

    private func fetchRows<T: Decodable>(
        table: String,
        select: String,
        filters: [String: String],
        order: String?,
        pageSize: Int
    ) async throws -> [T] {
        var rows: [T] = []
        var start = 0
        var expectedTotal: Int?

        while true {
            let end = start + pageSize - 1
            let (page, total): ([T], Int) = try await requestRows(
                table: table,
                select: select,
                filters: filters,
                order: order,
                range: "\(start)-\(end)"
            )
            if let expectedTotal, total != expectedTotal { throw RemoteError.incompletePage }
            expectedTotal = total
            rows.append(contentsOf: page)
            if rows.count == total {
                break
            }
            guard !page.isEmpty, rows.count < total else { throw RemoteError.incompletePage }
            start += page.count
        }

        return rows
    }

    private func requestRows<T: Decodable>(
        table: String,
        select: String,
        filters: [String: String],
        order: String?,
        range: String
    ) async throws -> ([T], Int) {
        var components = URLComponents(url: config.projectURL.appending(path: "/rest/v1/\(table)"), resolvingAgainstBaseURL: false)
        var queryItems = [URLQueryItem(name: "select", value: select)]
        queryItems.append(contentsOf: filters.map { URLQueryItem(name: $0.key, value: $0.value) })
        if let order {
            queryItems.append(URLQueryItem(name: "order", value: order))
        }
        components?.queryItems = queryItems

        guard let url = components?.url else { throw RemoteError.invalidURL }
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
        if !config.publishableKey.hasPrefix("sb_publishable_") {
            request.setValue("Bearer \(config.publishableKey)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("count=exact", forHTTPHeaderField: "Prefer")
        request.setValue("items", forHTTPHeaderField: "Range-Unit")
        request.setValue(range, forHTTPHeaderField: "Range")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RemoteError.badResponse(-1)
        }
        guard (200...299).contains(http.statusCode) else {
            throw RemoteError.badResponse(http.statusCode)
        }
        guard let contentRange = http.value(forHTTPHeaderField: "Content-Range"),
              let totalString = contentRange.split(separator: "/").last,
              let total = Int(totalString), total >= 0 else { throw RemoteError.incompletePage }
        let rows = try JSONDecoder().decode([T].self, from: data)
        if !rows.isEmpty {
            let returnedRange = contentRange.split(separator: "/")[0].split(separator: "-")
            let requestedStart = range.split(separator: "-").first.flatMap { Int($0) }
            guard returnedRange.count == 2,
                  let first = Int(returnedRange[0]), let last = Int(returnedRange[1]),
                  first == requestedStart, last - first + 1 == rows.count else { throw RemoteError.incompletePage }
        }
        return (rows, total)
    }
}
