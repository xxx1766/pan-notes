import Foundation
import PanNotesCore

enum NotionAPIError: Error, LocalizedError {
    case authenticationFailed(String)
    case missingAccess(String)
    case rateLimited(String)
    case validationFailed(String)
    case httpStatus(Int, String)
    case malformedResponse

    var errorDescription: String? {
        switch self {
        case .authenticationFailed(let message):
            "Notion authentication failed: \(message)"
        case .missingAccess(let message):
            "Notion page access failed: \(message)"
        case .rateLimited(let message):
            "Notion rate limit reached: \(message)"
        case .validationFailed(let message):
            "Notion validation failed: \(message)"
        case .httpStatus(let status, let message):
            "Notion API returned \(status): \(message)"
        case .malformedResponse:
            "Notion API returned an unexpected response."
        }
    }
}

final class NotionAPIClient: NotionClient {
    private let token: String
    private let session: URLSession
    private let baseURL: URL
    private let notionVersion = "2026-03-11"

    init(
        token: String,
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://api.notion.com/v1")!
    ) {
        self.token = token
        self.session = session
        self.baseURL = baseURL
    }

    func ensureDotPage(parentPageID: String, dot: Dot, existingPageID: String?) async throws -> String {
        if let existingPageID, !existingPageID.isEmpty {
            return existingPageID
        }

        let body: [String: Any] = [
            "parent": [
                "type": "page_id",
                "page_id": parentPageID
            ],
            "properties": titleProperties(dot.title),
            "children": NotionMarkdownConverter.blocks(from: "", dotID: dot.id).map(blockPayload)
        ]
        let response = try await requestJSON(path: "/pages", method: "POST", body: body)
        guard let page = response as? [String: Any], let id = page["id"] as? String else {
            throw NotionAPIError.malformedResponse
        }
        return id
    }

    func fetchBlocks(pageID: String) async throws -> [NotionBlock] {
        var blocks: [NotionBlock] = []
        var cursor: String?

        repeat {
            var queryItems = [URLQueryItem(name: "page_size", value: "100")]
            if let cursor {
                queryItems.append(URLQueryItem(name: "start_cursor", value: cursor))
            }
            let response = try await requestJSON(
                path: "/blocks/\(pageID)/children",
                method: "GET",
                queryItems: queryItems
            )
            guard let page = response as? [String: Any], let results = page["results"] as? [[String: Any]] else {
                throw NotionAPIError.malformedResponse
            }
            blocks.append(contentsOf: results.map(parseBlock))
            cursor = page["next_cursor"] as? String
        } while cursor != nil

        return blocks
    }

    func appendBlocks(pageID: String, blocks: [NotionBlock]) async throws {
        guard !blocks.isEmpty else {
            return
        }
        _ = try await requestJSON(
            path: "/blocks/\(pageID)/children",
            method: "PATCH",
            body: ["children": blocks.map(blockPayload)]
        )
    }

    func deleteBlock(blockID: String) async throws {
        _ = try await requestJSON(path: "/blocks/\(blockID)", method: "DELETE")
    }

    func updatePageTitle(pageID: String, title: String) async throws {
        _ = try await requestJSON(
            path: "/pages/\(pageID)",
            method: "PATCH",
            body: ["properties": titleProperties(title)]
        )
    }

    private func requestJSON(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: [String: Any]? = nil
    ) async throws -> Any {
        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)
        components?.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components?.url else {
            throw NotionAPIError.malformedResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(notionVersion, forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NotionAPIError.malformedResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw error(for: http.statusCode, data: data)
        }
        guard !data.isEmpty else {
            return [:]
        }
        return try JSONSerialization.jsonObject(with: data)
    }

    private func error(for statusCode: Int, data: Data) -> NotionAPIError {
        let message = responseMessage(from: data)
        switch statusCode {
        case 401:
            return .authenticationFailed(message)
        case 403, 404:
            return .missingAccess(accessMessage(message))
        case 429:
            return .rateLimited(message)
        case 400:
            return .validationFailed(message)
        default:
            return .httpStatus(statusCode, message)
        }
    }

    private func accessMessage(_ message: String) -> String {
        "\(message) In Notion, open the parent page, choose ... > Connections, add this integration, and confirm the integration has Read, Update, and Insert content capabilities."
    }

    private func responseMessage(from data: Data) -> String {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let message = object["message"] as? String
        else {
            return String(data: data, encoding: .utf8) ?? "No response body"
        }
        return message
    }

    private func parseBlock(_ object: [String: Any]) -> NotionBlock {
        let id = object["id"] as? String
        guard let type = object["type"] as? String else {
            return .unsupported("Unsupported Notion block", id: id)
        }

        switch type {
        case "paragraph":
            return .paragraph(richText(in: object, key: "paragraph"), id: id)
        case "heading_1":
            return .heading(level: 1, richText(in: object, key: "heading_1"), id: id)
        case "heading_2":
            return .heading(level: 2, richText(in: object, key: "heading_2"), id: id)
        case "heading_3":
            return .heading(level: 3, richText(in: object, key: "heading_3"), id: id)
        case "bulleted_list_item":
            return .bulletedListItem(richText(in: object, key: "bulleted_list_item"), id: id)
        case "numbered_list_item":
            return .numberedListItem(richText(in: object, key: "numbered_list_item"), id: id)
        case "to_do":
            let payload = object["to_do"] as? [String: Any]
            return .toDo(
                text: richText(in: object, key: "to_do"),
                isComplete: payload?["checked"] as? Bool ?? false,
                id: id
            )
        case "quote":
            return .quote(richText(in: object, key: "quote"), id: id)
        case "divider":
            return NotionBlock(id: id, kind: .divider)
        case "code":
            let payload = object["code"] as? [String: Any]
            return .code(
                language: payload?["language"] as? String,
                richText(in: object, key: "code"),
                id: id
            )
        default:
            return .unsupported("[Unsupported Notion block: \(type)]", id: id)
        }
    }

    private func richText(in object: [String: Any], key: String) -> String {
        guard
            let payload = object[key] as? [String: Any],
            let richText = payload["rich_text"] as? [[String: Any]]
        else {
            return ""
        }
        return richText.compactMap { $0["plain_text"] as? String }.joined()
    }

    private func titleProperties(_ title: String) -> [String: Any] {
        [
            "title": [
                "title": richTextPayload(title)
            ]
        ]
    }

    private func blockPayload(_ block: NotionBlock) -> [String: Any] {
        switch block.kind {
        case .paragraph(let text):
            return [
                "object": "block",
                "type": "paragraph",
                "paragraph": ["rich_text": richTextPayload(text)]
            ]
        case .heading(let level, let text):
            let type = "heading_\(min(max(level, 1), 3))"
            return [
                "object": "block",
                "type": type,
                type: ["rich_text": richTextPayload(text)]
            ]
        case .bulletedListItem(let text):
            return [
                "object": "block",
                "type": "bulleted_list_item",
                "bulleted_list_item": ["rich_text": richTextPayload(text)]
            ]
        case .numberedListItem(let text):
            return [
                "object": "block",
                "type": "numbered_list_item",
                "numbered_list_item": ["rich_text": richTextPayload(text)]
            ]
        case .toDo(let text, let isComplete):
            return [
                "object": "block",
                "type": "to_do",
                "to_do": [
                    "rich_text": richTextPayload(text),
                    "checked": isComplete
                ]
            ]
        case .quote(let text):
            return [
                "object": "block",
                "type": "quote",
                "quote": ["rich_text": richTextPayload(text)]
            ]
        case .divider:
            return [
                "object": "block",
                "type": "divider",
                "divider": [:]
            ]
        case .code(let language, let text):
            return [
                "object": "block",
                "type": "code",
                "code": [
                    "rich_text": richTextPayload(text),
                    "language": language ?? "plain text"
                ]
            ]
        case .unsupported(let text):
            return [
                "object": "block",
                "type": "paragraph",
                "paragraph": ["rich_text": richTextPayload(text)]
            ]
        }
    }

    private func richTextPayload(_ text: String) -> [[String: Any]] {
        guard !text.isEmpty else {
            return []
        }
        return [
            [
                "type": "text",
                "text": ["content": text]
            ]
        ]
    }
}
