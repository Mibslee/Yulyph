import Foundation

struct CopyrightInfo: Identifiable {
    let id = UUID()
    let creator: String
    let year: Int
    let license: String
    let isPublic: Bool
    var imageName: String?
    var detectedAt: Date

    /// 从 JSON 字符串解析
    static func parse(from jsonString: String) -> CopyrightInfo? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        guard let c = json["c"] as? String,
              let y = json["y"] as? Int,
              let l = json["l"] as? String else { return nil }
        return CopyrightInfo(creator: c, year: y, license: l, isPublic: true, imageName: nil, detectedAt: Date())
    }

    /// 序列化为 JSON 字符串
    func toJSON() -> String {
        let dict: [String: Any] = ["c": creator, "y": year, "l": license]
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
