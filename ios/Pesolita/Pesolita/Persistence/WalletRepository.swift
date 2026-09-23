import Foundation
import UIKit

actor WalletRepository {
    enum RepositoryError: LocalizedError {
        case unreadable

        var errorDescription: String? {
            switch self {
            case .unreadable: "Pesolita could not read the wallet saved on this device."
            }
        }
    }

    private let directory: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(directory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.directory = directory ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Pesolita", isDirectory: true)
        encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        decoder = JSONDecoder()
    }

    func load() throws -> WalletSnapshot? {
        let url = directory.appendingPathComponent("wallet-v1.json")
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        do {
            return try decoder.decode(WalletSnapshot.self, from: Data(contentsOf: url))
        } catch {
            let recovery = directory.appendingPathComponent("wallet-v1-unreadable-\(Int(Date().timeIntervalSince1970)).json")
            try? fileManager.moveItem(at: url, to: recovery)
            throw RepositoryError.unreadable
        }
    }

    func save(_ snapshot: WalletSnapshot) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(snapshot)
        try data.write(to: directory.appendingPathComponent("wallet-v1.json"), options: [.atomic])
    }

    func erase() throws {
        guard fileManager.fileExists(atPath: directory.path) else { return }
        try fileManager.removeItem(at: directory)
    }
}

actor MediaStore {
    private let directory: URL
    private let fileManager: FileManager

    init(directory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let base = directory ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Pesolita", isDirectory: true)
        self.directory = base.appendingPathComponent("Media", isDirectory: true)
    }

    func write(_ data: Data, existingReference: String? = nil, extension fileExtension: String = "jpg") throws -> String {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        
        var optimizedData = data
        if let image = UIImage(data: data) {
            let maxDimension: CGFloat = 1080
            var size = image.size
            if size.width > maxDimension || size.height > maxDimension {
                let ratio = min(maxDimension / size.width, maxDimension / size.height)
                size = CGSize(width: size.width * ratio, height: size.height * ratio)
                
                UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
                image.draw(in: CGRect(origin: .zero, size: size))
                let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                
                if let resizedData = resizedImage?.jpegData(compressionQuality: 0.7) {
                    optimizedData = resizedData
                }
            } else {
                if let compressedData = image.jpegData(compressionQuality: 0.7) {
                    optimizedData = compressedData
                }
            }
        }
        
        let name: String
        if let existing = existingReference, existing.hasPrefix("file:") {
            let parsedName = String(existing.dropFirst(5))
            if !parsedName.contains("/") && !parsedName.contains("..") {
                name = parsedName
            } else {
                name = "\(UUID().uuidString.lowercased()).\(fileExtension)"
            }
        } else {
            name = "\(UUID().uuidString.lowercased()).\(fileExtension)"
        }
        
        try optimizedData.write(to: directory.appendingPathComponent(name), options: [.atomic])
        return "file:\(name)"
    }

    func data(for reference: String) throws -> Data? {
        guard reference.hasPrefix("file:") else { return nil }
        let name = String(reference.dropFirst(5))
        guard !name.contains("/"), !name.contains("..") else { return nil }
        return try Data(contentsOf: directory.appendingPathComponent(name))
    }

    func url(for reference: String) -> URL? {
        guard reference.hasPrefix("file:") else { return nil }
        let name = String(reference.dropFirst(5))
        guard !name.contains("/"), !name.contains("..") else { return nil }
        return directory.appendingPathComponent(name)
    }
}

