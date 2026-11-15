import Foundation
#if os(macOS)
import Security
#endif

/// Config/Env.xcconfig → Info.plist(DK* 키) → 여기. 환경변수는 이 파일에서만 읽습니다.
enum AppConfig {
    static let geminiEndpoint = "https://generativelanguage.googleapis.com/v1beta/models"

    static var geminiAPIKey: String { value("DKGeminiAPIKey") }
    static var geminiModel: String { value("DKGeminiModel").nonEmpty ?? "gemini-3.8-flash" }
    static var defaultAIProvider: AIProvider { AIProvider(rawValue: value("DKDefaultAIProvider")) ?? .onDevice }
    static var iCloudContainer: String { value("DKICloudContainer") }
    static var teamID: String { value("DKTeamID") }
    /// iCloud는 Env에서 켜져 있고, Team ID로 서명됐고, 실제로 iCloud 엔타이틀먼트가 있을 때만 씁니다.
    /// (엔타이틀먼트 없이 CloudKit을 열면 앱이 즉시 종료됩니다.)
    static var iCloudEnabled: Bool {
        value("DKICloudEnabled").uppercased() == "YES" && !iCloudContainer.isEmpty && !teamID.isEmpty
            && !isRunningTests && hasCloudKitEntitlement
    }

    static var isRunningTests: Bool { ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil }

    private static var hasCloudKitEntitlement: Bool {
        #if os(macOS)
        guard let task = SecTaskCreateFromSelf(nil),
              let value = SecTaskCopyValueForEntitlement(task, "com.apple.developer.icloud-services" as CFString, nil)
        else { return false }
        return (value as? [String])?.contains("CloudKit") == true
        #else
        return true
        #endif
    }

    private static func value(_ key: String) -> String {
        let raw = (Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.hasPrefix("$(") ? "" : raw
    }
}

enum AIProvider: String, CaseIterable, Identifiable, Codable {
    case onDevice = "ondevice"
    case gemini

    var id: String { rawValue }
    var label: String {
        switch self {
        case .onDevice: "Apple 온디바이스"
        case .gemini: "Gemini"
        }
    }
}

extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
