import Foundation
import CatGameCore

enum SaveTransferError: Error, Equatable, Sendable {
    case busy, invalidFile, fileTooLarge, unsupportedVersion, readFailed, writeFailed

    static func messageKey(for error: Error) -> String {
        let reason: SaveTransferError
        if let error = error as? SaveTransferError { reason = error }
        else if let error = error as? NativeSaveTransferError {
            switch error {
            case .invalidArchive: reason = .invalidFile
            case .unsupportedArchiveVersion: reason = .unsupportedVersion
            case .fileTooLarge: reason = .fileTooLarge
            }
        } else if let error = error as? SaveRepositoryError {
            switch error {
            case .unsupportedSchemaVersion: reason = .unsupportedVersion
            case .invalidSnapshot, .unreadableSave: reason = .invalidFile
            }
        } else { reason = .readFailed }
        switch reason {
        case .busy: return "saveTransfer.busy"
        case .invalidFile: return "saveTransfer.invalidFile"
        case .fileTooLarge: return "saveTransfer.fileTooLarge"
        case .unsupportedVersion: return "saveTransfer.unsupportedVersion"
        case .readFailed: return "saveTransfer.readFailed"
        case .writeFailed: return "saveTransfer.writeFailed"
        }
    }
}

/// Only repositories that can preserve a durable recovery point accept replacement.
protocol GameSaveTransferRepository: GameSaveRepository {
    func importSnapshot(_ state: GameSnapshot) async throws
    func loadImportRecovery() async throws -> GameSnapshot?
}

extension FileSaveRepository: GameSaveTransferRepository {}
