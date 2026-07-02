import Foundation

public struct NotionBlock: Equatable, Sendable {
    public var id: String?
    public var kind: NotionBlockKind

    public init(id: String? = nil, kind: NotionBlockKind) {
        self.id = id
        self.kind = kind
    }
}

public enum NotionBlockKind: Equatable, Sendable {
    case paragraph(String)
    case heading(level: Int, text: String)
    case bulletedListItem(String)
    case numberedListItem(String)
    case toDo(text: String, isComplete: Bool)
    case quote(String)
    case divider
    case code(language: String?, text: String)
    case unsupported(String)
}

public extension NotionBlock {
    static func paragraph(_ text: String, id: String? = nil) -> NotionBlock {
        NotionBlock(id: id, kind: .paragraph(text))
    }

    static func heading(level: Int, _ text: String, id: String? = nil) -> NotionBlock {
        NotionBlock(id: id, kind: .heading(level: level, text: text))
    }

    static func bulletedListItem(_ text: String, id: String? = nil) -> NotionBlock {
        NotionBlock(id: id, kind: .bulletedListItem(text))
    }

    static func numberedListItem(_ text: String, id: String? = nil) -> NotionBlock {
        NotionBlock(id: id, kind: .numberedListItem(text))
    }

    static func toDo(text: String, isComplete: Bool, id: String? = nil) -> NotionBlock {
        NotionBlock(id: id, kind: .toDo(text: text, isComplete: isComplete))
    }

    static func quote(_ text: String, id: String? = nil) -> NotionBlock {
        NotionBlock(id: id, kind: .quote(text))
    }

    static var divider: NotionBlock {
        NotionBlock(kind: .divider)
    }

    static func code(language: String?, _ text: String, id: String? = nil) -> NotionBlock {
        NotionBlock(id: id, kind: .code(language: language, text: text))
    }

    static func unsupported(_ text: String, id: String? = nil) -> NotionBlock {
        NotionBlock(id: id, kind: .unsupported(text))
    }
}
