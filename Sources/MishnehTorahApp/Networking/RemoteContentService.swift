import Foundation

protocol RemoteContentFetching {
    func fetchContentMeta() async throws -> RemoteContentMetaDTO
    func fetchChanges(localVersion: Int, updatedAfter: String?) async throws -> RemoteContentChanges
}

struct RemoteContentService: RemoteContentFetching {
    enum RemoteError: Error {
        case badResponse(Int)
        case emptyMeta
    }

    private let config: SupabaseConfig
    private let session: URLSession
    private let pageSize: Int

    init(config: SupabaseConfig, session: URLSession = .shared, pageSize: Int = 1_000) {
        self.config = config
        self.session = session
        self.pageSize = pageSize
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
        let filters = changeFilters(localVersion: localVersion, updatedAfter: updatedAfter)

        let books: [RemoteBookDTO] = try await fetchRows(
            table: "books",
            select: "*",
            filters: filters,
            order: "sort_order.asc",
            pageSize: pageSize
        )
        let sections: [RemoteSectionDTO] = try await fetchRows(
            table: "sections",
            select: "*",
            filters: filters,
            order: "sort_order.asc",
            pageSize: pageSize
        )
        let chapters: [RemoteChapterDTO] = try await fetchRows(
            table: "chapters",
            select: "*",
            filters: filters,
            order: "updated_at.asc,content_id.asc",
            pageSize: pageSize
        )
        let halakhot: [RemoteHalakhahDTO] = try await fetchRows(
            table: "halakhot",
            select: "*",
            filters: filters,
            order: "updated_at.asc,content_id.asc",
            pageSize: pageSize
        )

        return RemoteContentChanges(books: books, sections: sections, chapters: chapters, halakhot: halakhot)
    }

    private func changeFilters(localVersion: Int, updatedAfter: String?) -> [String: String] {
        var filters = [
            "is_published": "eq.true",
            "deleted_at": "is.null"
        ]
        if let updatedAfter, !updatedAfter.isEmpty {
            filters["updated_at"] = "gt.\(updatedAfter)"
        } else {
            filters["content_version"] = "gt.\(localVersion)"
        }
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

        while true {
            let end = start + pageSize - 1
            let page: [T] = try await requestRows(
                table: table,
                select: select,
                filters: filters,
                order: order,
                range: "\(start)-\(end)"
            )
            rows.append(contentsOf: page)
            if page.count < pageSize {
                break
            }
            start += pageSize
        }

        return rows
    }

    private func requestRows<T: Decodable>(
        table: String,
        select: String,
        filters: [String: String],
        order: String?,
        range: String
    ) async throws -> [T] {
        var components = URLComponents(url: config.projectURL.appending(path: "/rest/v1/\(table)"), resolvingAgainstBaseURL: false)
        var queryItems = [URLQueryItem(name: "select", value: select)]
        queryItems.append(contentsOf: filters.map { URLQueryItem(name: $0.key, value: $0.value) })
        if let order {
            queryItems.append(URLQueryItem(name: "order", value: order))
        }
        components?.queryItems = queryItems

        guard let url = components?.url else { return [] }
        var request = URLRequest(url: url)
        request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(config.publishableKey)", forHTTPHeaderField: "Authorization")
        request.setValue("items", forHTTPHeaderField: "Range-Unit")
        request.setValue(range, forHTTPHeaderField: "Range")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RemoteError.badResponse(-1)
        }
        guard (200...299).contains(http.statusCode) else {
            throw RemoteError.badResponse(http.statusCode)
        }
        return try JSONDecoder().decode([T].self, from: data)
    }
}
