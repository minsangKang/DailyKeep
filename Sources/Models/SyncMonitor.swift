import CloudKit
import CoreData
import SwiftUI

/// iCloud 동기화가 실제로 돌고 있는지 설정 화면에 보여줍니다.
/// SwiftData의 CloudKit 연동은 내부적으로 NSPersistentCloudKitContainer가 맡아, 그 이벤트 알림을 그대로 받습니다.
@Observable
final class SyncMonitor {
    private(set) var accountStatus = "확인 중"
    private(set) var lastEvent: String?
    private(set) var lastError: String?
    private var observer: (any NSObjectProtocol)?

    init() {
        guard ModelContainerFactory.mode == .iCloud else {
            accountStatus = "사용 안 함"
            return
        }
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event,
                  let end = event.endDate else { return }
            let kind = switch event.type {
            case .setup: "준비"
            case .import: "받기"
            case .export: "보내기"
            @unknown default: "동기화"
            }
            let time = end.formatted(date: .omitted, time: .standard)
            let message = event.succeeded ? "\(kind) 완료 · \(time)" : "\(kind) 실패 · \(time)"
            let error = event.error?.localizedDescription
            MainActor.assumeIsolated {
                self?.lastEvent = message
                if let error { self?.lastError = error }
            }
        }
        Task { await refreshAccount() }
    }

    func refreshAccount() async {
        guard ModelContainerFactory.mode == .iCloud else { return }
        do {
            let status = try await CKContainer(identifier: AppConfig.iCloudContainer).accountStatus()
            accountStatus = switch status {
            case .available: "로그인됨"
            case .noAccount: "iCloud에 로그인되어 있지 않아요"
            case .restricted: "제한됨"
            case .temporarilyUnavailable: "잠시 사용할 수 없음"
            case .couldNotDetermine: "확인할 수 없음"
            @unknown default: "확인할 수 없음"
            }
        } catch {
            accountStatus = "확인 실패: \(error.localizedDescription)"
        }
    }
}
