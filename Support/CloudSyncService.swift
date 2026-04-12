import Foundation

enum CloudSyncPushError: LocalizedError {
    case unavailable
    case snapshotTooLarge(currentBytes: Int, maximumBytes: Int)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "当前设备未检测到可用的 iCloud 账户。"
        case let .snapshotTooLarge(currentBytes, maximumBytes):
            return "当前工作区约 \(currentBytes / 1024) KB，已超过 iCloud 轻量同步建议上限 \(maximumBytes / 1024) KB。"
        }
    }
}

final class CloudSyncService {
    static let shared = CloudSyncService()
    static let maximumSnapshotBytes = 900_000

    private let snapshotKey = "studio-store-snapshot"
    private let modifiedAtKey = "studio-store-last-modified-at"
    private let store = NSUbiquitousKeyValueStore.default

    var isAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    func push(snapshotData: Data, lastModifiedAt: Date) throws {
        guard isAvailable else {
            throw CloudSyncPushError.unavailable
        }
        guard snapshotData.count <= Self.maximumSnapshotBytes else {
            throw CloudSyncPushError.snapshotTooLarge(currentBytes: snapshotData.count, maximumBytes: Self.maximumSnapshotBytes)
        }

        store.set(snapshotData, forKey: snapshotKey)
        store.set(lastModifiedAt.timeIntervalSince1970, forKey: modifiedAtKey)
        store.synchronize()
    }

    func clearRemoteSnapshot() {
        guard isAvailable else { return }
        store.removeObject(forKey: snapshotKey)
        store.removeObject(forKey: modifiedAtKey)
        store.synchronize()
    }

    func loadRemoteSnapshotData() -> (data: Data, lastModifiedAt: Date)? {
        guard isAvailable, let data = store.data(forKey: snapshotKey) else {
            return nil
        }

        let timestamp = store.double(forKey: modifiedAtKey)
        let date = timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : .distantPast
        return (data, date)
    }
}
