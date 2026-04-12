import Foundation

enum StoreExportFormat: String, CaseIterable, Identifiable {
    case json
    case csv

    var id: String { rawValue }

    var title: String {
        switch self {
        case .json: "JSON"
        case .csv: "CSV"
        }
    }
}

enum StoreExportService {
    static let backupPackageExtension = "yingqibackup"
    static let backupManifestFileName = "workspace.json"
    static let backupAttachmentsDirectoryName = "Attachments"

    static func writeJSON(snapshot: StudioStoreSnapshot, to directory: URL) throws -> URL {
        let url = directory.appending(path: "影期备份-\(timestamp()).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        return url
    }

    static func writeBackupPackage(snapshot: StudioStoreSnapshot, attachmentsDirectory: URL?, to directory: URL) throws -> URL {
        let packageURL = directory.appending(path: "影期备份-\(timestamp()).\(backupPackageExtension)", directoryHint: .isDirectory)
        let fileManager = FileManager.default
        let manifestURL = packageURL.appending(path: backupManifestFileName)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        if fileManager.fileExists(atPath: packageURL.path) {
            try fileManager.removeItem(at: packageURL)
        }
        try fileManager.createDirectory(at: packageURL, withIntermediateDirectories: true)
        try encoder.encode(snapshot).write(to: manifestURL, options: .atomic)

        if let attachmentsDirectory,
           fileManager.fileExists(atPath: attachmentsDirectory.path) {
            let packagedAttachmentsURL = packageURL.appending(path: backupAttachmentsDirectoryName, directoryHint: .isDirectory)
            try copyDirectoryContents(from: attachmentsDirectory, to: packagedAttachmentsURL, fileManager: fileManager)
        }

        let readme = packageURL.appending(path: "README.txt")
        let readmeText = "影期完整备份。包含 workspace.json 与 Attachments 目录。"
        try readmeText.data(using: .utf8)?.write(to: readme, options: .atomic)
        return packageURL
    }

    static func writeCSV(
        clients: [ClientRecord],
        bookings: [BookingRecord],
        touchpoints: [TouchpointRecord],
        payments: [PaymentRecord],
        to directory: URL
    ) throws -> URL {
        let url = directory.appending(path: "影期导出-\(timestamp()).csv")
        let rows = makeRows(clients: clients, bookings: bookings, touchpoints: touchpoints, payments: payments)
        let csv = rows.map { $0.map(escaped).joined(separator: ",") }.joined(separator: "\n")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try csv.data(using: .utf8)?.write(to: url, options: .atomic)
        return url
    }

    private static func copyDirectoryContents(from source: URL, to destination: URL, fileManager: FileManager) throws {
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        let items = try fileManager.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
        for item in items {
            let target = destination.appending(path: item.lastPathComponent, directoryHint: .notDirectory)
            if fileManager.fileExists(atPath: target.path) {
                try fileManager.removeItem(at: target)
            }
            try fileManager.copyItem(at: item, to: target)
        }
    }

    private static func makeRows(
        clients: [ClientRecord],
        bookings: [BookingRecord],
        touchpoints: [TouchpointRecord],
        payments: [PaymentRecord]
    ) -> [[String]] {
        var rows: [[String]] = [
            ["类型", "ID", "标题/姓名", "状态", "日期", "金额", "补充"]
        ]

        rows += clients.map {
            [
                "客户",
                $0.id.uuidString,
                $0.name,
                $0.stage.title,
                AppFormatters.shortDate($0.createdAt),
                "",
                [$0.city, $0.phoneNumber, $0.tags.joined(separator: "、")].filter { $0.isEmpty == false }.joined(separator: " · ")
            ]
        }

        rows += bookings.map {
            [
                "档期",
                $0.id.uuidString,
                $0.title,
                $0.status.title,
                AppFormatters.shortDate($0.startAt),
                String(Int($0.fee)),
                [$0.city, $0.venue].filter { $0.isEmpty == false }.joined(separator: " · ")
            ]
        }

        rows += touchpoints.map {
            [
                "跟进",
                $0.id.uuidString,
                $0.title,
                $0.isComplete ? "已完成" : "待处理",
                AppFormatters.shortDate($0.dueAt),
                "",
                $0.detailsText
            ]
        }

        rows += payments.map {
            [
                "付款",
                $0.id.uuidString,
                $0.paymentType.title,
                "",
                AppFormatters.shortDate($0.date),
                String(Int($0.amount)),
                $0.note
            ]
        }

        return rows
    }

    private static func escaped(_ value: String) -> String {
        let escapedQuotes = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escapedQuotes)\""
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: .now)
    }
}
