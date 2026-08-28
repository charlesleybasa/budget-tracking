import Foundation
import Testing
@testable import Pesolita

struct PersistenceTests {
    @Test func repositoryRoundTripsAtomically() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let repository = WalletRepository(directory: root)
        var snapshot = WalletSnapshot()
        snapshot.haptics = false
        snapshot.sfx = false
        snapshot.userName = "Rli"
        snapshot.onboarded = true
        try await repository.save(snapshot)
        let restored = try await repository.load()
        #expect(restored == snapshot)
        try? FileManager.default.removeItem(at: root)
    }

    @Test func feedbackPreferencesRoundTripAndDefaultForOlderWallets() throws {
        var snapshot = WalletSnapshot()
        snapshot.haptics = false
        snapshot.sfx = false
        let restored = try JSONDecoder().decode(WalletSnapshot.self, from: JSONEncoder().encode(snapshot))
        #expect(restored.haptics == false)
        #expect(restored.sfx == false)

        let legacy = Data(#"{"schemaVersion":1,"cards":[],"tx":[]}"#.utf8)
        let migrated = try JSONDecoder().decode(WalletSnapshot.self, from: legacy)
        #expect(migrated.haptics)
        #expect(migrated.sfx)
    }

    @Test func webBackupRoundTripsTemplateCards() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let media = MediaStore(directory: root)
        var snapshot = WalletSnapshot()
        snapshot.cards = [Card(
            id: "card",
            kind: .debit,
            nick: "Main Account",
            last4: "",
            exp: "—",
            bal: 1000,
            limit: 0,
            art: CardTemplates.byID["banks/deep-blue-wave"]!.art,
            frozen: false
        )]
        snapshot.activeId = "card"
        snapshot.userName = "Rli"
        snapshot.onboarded = true
        snapshot.haptics = false
        snapshot.sfx = false

        let data = try await BackupCodec.export(snapshot, media: media)
        let web = try JSONDecoder().decode(WebBackup.self, from: data)
        #expect(web.format == "pesolita.backup")
        #expect(web.version == 1)

        let restored = try await BackupCodec.restore(data, media: media)
        #expect(restored.cards.first?.nick == "Main Account")
        #expect(restored.cards.first?.art.photo?.src == "template:banks/deep-blue-wave.webp")
        #expect(restored.haptics == false)
        #expect(restored.sfx == false)
        try? FileManager.default.removeItem(at: root)
    }

    @Test func restoreAcceptsOlderWebBackupWithoutOptionalPreferences() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let media = MediaStore(directory: root)
        let data = Data(#"{"format":"pesolita.backup","version":1,"cards":[],"tx":[]}"#.utf8)

        let restored = try await BackupCodec.restore(data, media: media)
        #expect(restored.cards.isEmpty)
        #expect(restored.homeLayout == .deck)
        #expect(restored.nudgeLowBalance)
        #expect(restored.nudgeDailyLog)
        #expect(restored.haptics)
        #expect(restored.sfx)
        try? FileManager.default.removeItem(at: root)
    }
}
