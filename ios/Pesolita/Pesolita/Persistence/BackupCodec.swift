import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct WebBackup: Codable, Sendable {
    var format: String
    var version: Int
    var exportedAt: String
    var cards: [Card]
    var tx: [Transaction]
    var dismissedNotices: [String]
    var userName: String
    var privacy: Bool
    var homeLayout: HomeLayout
    var nudgeLowBalance: Bool
    var nudgeDailyLog: Bool
    var haptics: Bool
    var sfx: Bool

    enum CodingKeys: String, CodingKey {
        case format, version, exportedAt, cards, tx, dismissedNotices, userName, privacy
        case homeLayout, nudgeLowBalance, nudgeDailyLog, haptics, sfx
    }

    init(
        format: String,
        version: Int,
        exportedAt: String,
        cards: [Card],
        tx: [Transaction],
        dismissedNotices: [String],
        userName: String,
        privacy: Bool,
        homeLayout: HomeLayout,
        nudgeLowBalance: Bool,
        nudgeDailyLog: Bool,
        haptics: Bool,
        sfx: Bool
    ) {
        self.format = format
        self.version = version
        self.exportedAt = exportedAt
        self.cards = cards
        self.tx = tx
        self.dismissedNotices = dismissedNotices
        self.userName = userName
        self.privacy = privacy
        self.homeLayout = homeLayout
        self.nudgeLowBalance = nudgeLowBalance
        self.nudgeDailyLog = nudgeDailyLog
        self.haptics = haptics
        self.sfx = sfx
    }

    /// Version 1 web backups predate some preferences. Match the web migrator by
    /// defaulting absent optional fields instead of rejecting the whole wallet.
    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        format = try box.decode(String.self, forKey: .format)
        version = try box.decode(Int.self, forKey: .version)
        exportedAt = (try? box.decode(String.self, forKey: .exportedAt)) ?? ""
        cards = try box.decodeIfPresent([Card].self, forKey: .cards) ?? []
        tx = try box.decodeIfPresent([Transaction].self, forKey: .tx) ?? []
        dismissedNotices = (try? box.decode([String].self, forKey: .dismissedNotices)) ?? []
        userName = (try? box.decode(String.self, forKey: .userName)) ?? ""
        privacy = (try? box.decode(Bool.self, forKey: .privacy)) ?? false
        homeLayout = (try? box.decode(HomeLayout.self, forKey: .homeLayout)) ?? .deck
        nudgeLowBalance = (try? box.decode(Bool.self, forKey: .nudgeLowBalance)) ?? true
        nudgeDailyLog = (try? box.decode(Bool.self, forKey: .nudgeDailyLog)) ?? true
        haptics = (try? box.decode(Bool.self, forKey: .haptics)) ?? true
        sfx = (try? box.decode(Bool.self, forKey: .sfx)) ?? true
    }
}

enum BackupCodecError: LocalizedError {
    case notPesolita
    case newerVersion
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .notPesolita: "That file is not a Pesolita backup."
        case .newerVersion: "That backup came from a newer version of Pesolita."
        case .invalidImage: "One of the images in that backup could not be read."
        }
    }
}

enum BackupCodec {
    static func export(_ snapshot: WalletSnapshot, media: MediaStore) async throws -> Data {
        var cards = snapshot.cards
        var transactions = snapshot.tx

        for index in cards.indices {
            if let source = cards[index].art.photo?.src,
               let inline = try await inlineReference(source, media: media) {
                cards[index].art.photo?.src = inline
            }
            if let qr = cards[index].qr,
               let inline = try await inlineReference(qr, media: media) {
                cards[index].qr = inline
            }
        }
        for index in transactions.indices {
            if let receipt = transactions[index].receipt,
               let inline = try await inlineReference(receipt, media: media) {
                transactions[index].receipt = inline
            }
        }

        let backup = WebBackup(
            format: "pesolita.backup",
            version: 1,
            exportedAt: ISO8601DateFormatter().string(from: Date()),
            cards: cards,
            tx: transactions,
            dismissedNotices: snapshot.dismissedNotices,
            userName: snapshot.userName,
            privacy: snapshot.privacy,
            homeLayout: snapshot.homeLayout,
            nudgeLowBalance: snapshot.nudgeLowBalance,
            nudgeDailyLog: snapshot.nudgeDailyLog,
            haptics: snapshot.haptics,
            sfx: snapshot.sfx
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    static func restore(_ data: Data, media: MediaStore) async throws -> WalletSnapshot {
        let backup: WebBackup
        do {
            backup = try JSONDecoder().decode(WebBackup.self, from: data)
        } catch {
            throw BackupCodecError.notPesolita
        }
        guard backup.format == "pesolita.backup" else { throw BackupCodecError.notPesolita }
        guard backup.version <= 1 else { throw BackupCodecError.newerVersion }

        var cards = backup.cards
        var transactions = backup.tx
        for index in cards.indices {
            if let source = cards[index].art.photo?.src {
                cards[index].art.photo?.src = try await persistInlineReference(source, media: media)
            }
            if let qr = cards[index].qr {
                cards[index].qr = try await persistInlineReference(qr, media: media)
            }
        }
        for index in transactions.indices {
            if let receipt = transactions[index].receipt {
                transactions[index].receipt = try await persistInlineReference(receipt, media: media)
            }
        }

        let validCardIDs = Set(cards.map(\.id))
        transactions.removeAll { !validCardIDs.contains($0.cardId) }
        var snapshot = WalletSnapshot()
        snapshot.cards = cards
        snapshot.tx = transactions
        snapshot.dismissedNotices = backup.dismissedNotices
        snapshot.activeId = cards.first?.id ?? ""
        snapshot.userName = backup.userName
        snapshot.privacy = backup.privacy
        snapshot.homeLayout = backup.homeLayout
        snapshot.onboarded = !cards.isEmpty
        snapshot.nudgeLowBalance = backup.nudgeLowBalance
        snapshot.nudgeDailyLog = backup.nudgeDailyLog
        snapshot.haptics = backup.haptics
        snapshot.sfx = backup.sfx
        return snapshot
    }

    private static func inlineReference(_ reference: String, media: MediaStore) async throws -> String? {
        guard let data = try await media.data(for: reference) else { return nil }
        return "data:image/jpeg;base64,\(data.base64EncodedString())"
    }

    private static func persistInlineReference(_ reference: String, media: MediaStore) async throws -> String {
        guard reference.hasPrefix("data:") else { return reference }
        guard let comma = reference.firstIndex(of: ","),
              reference[..<comma].contains(";base64"),
              let data = Data(base64Encoded: String(reference[reference.index(after: comma)...])) else {
            throw BackupCodecError.invalidImage
        }
        let header = reference[..<comma]
        let ext = header.contains("png") ? "png" : header.contains("webp") ? "webp" : "jpg"
        return try await media.write(data, extension: ext)
    }
}

struct PesolitaBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data = Data()) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw BackupCodecError.notPesolita }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// Settings exports both JSON backups and CSV from one presentation modifier.
/// Keeping one exporter avoids SwiftUI allowing the second modifier to shadow the first.
struct PesolitaExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText] }
    var data: Data

    init(data: Data = Data()) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
