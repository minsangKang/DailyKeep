import Foundation

/// YAML front matter + 본문. 값은 JSON 표기로 씁니다(JSON은 YAML의 부분집합이라 다른 MD 도구에서도 읽힙니다).
struct MarkdownFile {
    var fields: [(key: String, value: Any)] = []
    var body = ""

    subscript(key: String) -> Any? {
        fields.first { $0.key == key }?.value
    }

    mutating func set(_ key: String, _ value: Any?) {
        fields.append((key, value ?? NSNull()))
    }

    func string(_ key: String) -> String { self[key] as? String ?? "" }
    func bool(_ key: String) -> Bool { self[key] as? Bool ?? false }
    func int(_ key: String) -> Int { self[key] as? Int ?? 0 }
    func strings(_ key: String) -> [String] { self[key] as? [String] ?? [] }
    func date(_ key: String) -> Date? { (self[key] as? String).flatMap { try? Date($0, strategy: .iso8601) } }
    func uuid(_ key: String) -> UUID? { UUID(uuidString: string(key)) }

    func encoded() -> String {
        var lines = ["---"]
        for (key, value) in fields {
            let data = (try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed, .withoutEscapingSlashes])) ?? Data("null".utf8)
            lines.append("\(key): \(String(decoding: data, as: UTF8.self))")
        }
        lines.append("---")
        return lines.joined(separator: "\n") + "\n\n" + body
    }

    static func decode(_ text: String) -> MarkdownFile {
        var file = MarkdownFile()
        let lines = text.components(separatedBy: "\n")
        guard lines.first == "---", let end = lines.dropFirst().firstIndex(of: "---") else {
            file.body = text
            return file
        }
        for line in lines[1..<end] {
            guard let colon = line.range(of: ": ") else { continue }
            let key = String(line[..<colon.lowerBound])
            let raw = Data(line[colon.upperBound...].utf8)
            let value = (try? JSONSerialization.jsonObject(with: raw, options: .fragmentsAllowed)) ?? String(line[colon.upperBound...])
            file.fields.append((key, value))
        }
        var rest = Array(lines[(end + 1)...])
        if rest.first == "" { rest.removeFirst() }
        file.body = rest.joined(separator: "\n")
        return file
    }
}

extension Date {
    var iso: String { formatted(.iso8601) }
}
