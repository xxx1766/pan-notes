public struct ThemeColorSet: Codable, Equatable, Sendable {
    public var dot: String
    public var text: String
    public var accent: String
    public var statusText: String
    public var statusBackground: String
    public var background: String
    public var link: String
}

public struct ThemeVariant: Codable, Equatable, Sendable {
    public var name: String
    public var light: ThemeColorSet
    public var dark: ThemeColorSet
}

public struct Theme: Codable, Equatable, Sendable {
    public var variants: [ThemeVariant]

    public static let defaultTheme = Theme(variants: [
        ThemeVariant(name: "default", light: .init(dot: "#242424", text: "#111111", accent: "#333333", statusText: "#333333", statusBackground: "#F2F2F2", background: "#FFFFFF", link: "#1D5FD1"), dark: .init(dot: "#F5F5F5", text: "#F5F5F5", accent: "#E5E5E5", statusText: "#E5E5E5", statusBackground: "#202020", background: "#111111", link: "#8AB4FF")),
        ThemeVariant(name: "yellow", light: .init(dot: "#D8A900", text: "#181818", accent: "#735A00", statusText: "#735A00", statusBackground: "#FFF3C4", background: "#FFFBEA", link: "#8A6500"), dark: .init(dot: "#F4C430", text: "#F7F7F7", accent: "#F0D26A", statusText: "#F0D26A", statusBackground: "#3A3218", background: "#18160D", link: "#F1CA45")),
        ThemeVariant(name: "orange", light: .init(dot: "#DD6B20", text: "#171717", accent: "#874213", statusText: "#874213", statusBackground: "#FBE4D0", background: "#FFF4EA", link: "#B45309"), dark: .init(dot: "#FB923C", text: "#FAFAFA", accent: "#FDBA74", statusText: "#FDBA74", statusBackground: "#3B281A", background: "#1B130D", link: "#FDBA74")),
        ThemeVariant(name: "red", light: .init(dot: "#D13447", text: "#161616", accent: "#8A2632", statusText: "#8A2632", statusBackground: "#F9D7DC", background: "#FFF0F2", link: "#B42335"), dark: .init(dot: "#F87171", text: "#FAFAFA", accent: "#FCA5A5", statusText: "#FCA5A5", statusBackground: "#3A2022", background: "#190F10", link: "#FCA5A5")),
        ThemeVariant(name: "purple", light: .init(dot: "#8B5CF6", text: "#161616", accent: "#5B3AA6", statusText: "#5B3AA6", statusBackground: "#E8DFFC", background: "#F8F4FF", link: "#6D49D8"), dark: .init(dot: "#A78BFA", text: "#FAFAFA", accent: "#C4B5FD", statusText: "#C4B5FD", statusBackground: "#30253F", background: "#17111F", link: "#C4B5FD")),
        ThemeVariant(name: "blue", light: .init(dot: "#2563EB", text: "#151515", accent: "#1E4BA8", statusText: "#1E4BA8", statusBackground: "#D8E4FF", background: "#F0F5FF", link: "#1D4ED8"), dark: .init(dot: "#60A5FA", text: "#FAFAFA", accent: "#93C5FD", statusText: "#93C5FD", statusBackground: "#1F2A3D", background: "#101722", link: "#93C5FD")),
        ThemeVariant(name: "teal", light: .init(dot: "#0F9F9C", text: "#151515", accent: "#0B6765", statusText: "#0B6765", statusBackground: "#D5F2EF", background: "#EEFFFD", link: "#0D7D79"), dark: .init(dot: "#2DD4BF", text: "#FAFAFA", accent: "#99F6E4", statusText: "#99F6E4", statusBackground: "#1A3432", background: "#0E1B1A", link: "#5EEAD4")),
        ThemeVariant(name: "green", light: .init(dot: "#4D9F0C", text: "#151515", accent: "#376E0A", statusText: "#376E0A", statusBackground: "#DFF0CE", background: "#F4FFE9", link: "#3F7F0A"), dark: .init(dot: "#86EFAC", text: "#FAFAFA", accent: "#BBF7D0", statusText: "#BBF7D0", statusBackground: "#203322", background: "#101A11", link: "#BBF7D0"))
    ])
}
