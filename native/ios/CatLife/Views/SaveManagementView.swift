import SwiftUI
import CatGameCore

@MainActor
struct SaveManagementView: View {
    @Bindable var store: GameStore
    var recoveryOnly = false
    var onRecovered: (() -> Void)?
    @State private var isWorking = false
    @State private var isImportingFile = false
    @State private var isExportingFile = false
    @State private var exportDocument: SaveArchiveDocument?
    @State private var exportURL: URL?
    @State private var exportDate: Date?
    @State private var recovery: NativeSaveArchive?
    @State private var recoveryUnavailable = true
    @State private var preview: ImportPreview?
    @State private var statusKey: String?
    @State private var isError = false

    private struct ImportPreview: Identifiable {
        let id = UUID()
        let archive: NativeSaveArchive
        let isRecovery: Bool
    }

    private var busy: Bool { isWorking || store.saveTransferInProgress || store.isBusy }
    private var titleKey: String { recoveryOnly ? "saveTransfer.failureEntry" : "saveTransfer.title" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GamePageHeading(title: GameStrings.text(titleKey),
                                subtitle: GameStrings.text("saveTransfer.subtitle"),
                                symbol: "externaldrive.fill", tint: RoomTheme.mint,
                                background: RoomTheme.chipBg)
                if !recoveryOnly, let snapshot = store.snapshot {
                    summary(snapshot, title: "saveTransfer.current", time: snapshot.meta.lastSyncAt,
                            timeTitle: "saveTransfer.progressTime")
                        .accessibilityIdentifier("saveCurrentSummary")
                }
                transferActions
                if !recoveryOnly { recoveryCard }
                if let statusKey {
                    Label(GameStrings.text(statusKey),
                          systemImage: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(isError ? RoomTheme.coral : RoomTheme.darkMint)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("saveTransferStatus")
                }
                if isWorking {
                    ProgressView(GameStrings.text("saveTransfer.working"))
                        .font(.system(size: 13, weight: .bold))
                        .accessibilityIdentifier("saveTransferProgress")
                }
                Text(GameStrings.text(recoveryOnly ? "saveTransfer.failureScope" : "saveTransfer.scope"))
                    .font(.system(size: 12)).foregroundStyle(RoomTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(RoomTheme.cream.ignoresSafeArea())
        .toolbarBackground(RoomTheme.cream, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationTitle(GameStrings.text(titleKey))
        .accessibilityIdentifier("saveManagementScroll")
        .task { if !recoveryOnly { await refreshRecovery() } }
        .fileImporter(isPresented: $isImportingFile, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url): readImport(url)
            case .failure(let error): report(error)
            }
        }
        .fileExporter(isPresented: $isExportingFile, document: exportDocument,
                      contentType: .json, defaultFilename: "CatLife-Backup") { result in
            switch result {
            case .success: setStatus("saveTransfer.exported")
            case .failure(let error):
                if (error as? CocoaError)?.code != .userCancelled { report(SaveTransferError.writeFailed) }
            }
        }
        .sheet(item: $preview) { candidate in importConfirmation(candidate) }
    }

    private var transferActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            if recoveryOnly {
                Text(GameStrings.text(store.needsNewerVersion ? "saveTransfer.failureNewerIntro" : "saveTransfer.failureIntro"))
                    .font(.system(size: 14)).foregroundStyle(RoomTheme.secondary)
            } else {
                Text(GameStrings.text("saveTransfer.backupTitle"))
                    .font(.system(size: 17, weight: .heavy))
                Text(GameStrings.text("saveTransfer.backupHint"))
                    .font(.system(size: 13)).foregroundStyle(RoomTheme.secondary)
                Button { prepareExport() } label: {
                    Label(GameStrings.text("saveTransfer.prepareExport"), systemImage: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .bold)).frame(maxWidth: .infinity)
                }
                .buttonStyle(MintButtonStyle()).disabled(busy)
                .accessibilityIdentifier("saveExportButton")
                if let exportURL, let exportDate {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(GameStrings.format("saveTransfer.preparedAt", dateText(exportDate)))
                            .font(.system(size: 12, weight: .bold)).foregroundStyle(RoomTheme.secondary)
                            .accessibilityIdentifier("saveExportPrepared")
                        Button { isExportingFile = true } label: {
                            Label(GameStrings.text("saveTransfer.saveToFiles"), systemImage: "folder")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .buttonStyle(SoftButtonStyle()).disabled(busy)
                        .accessibilityIdentifier("saveExportFilesButton")
                        ShareLink(item: exportURL) {
                            Label(GameStrings.text("saveTransfer.share"), systemImage: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .buttonStyle(SoftButtonStyle()).disabled(busy)
                        .accessibilityIdentifier("saveExportShareButton")
                    }
                    .padding(12).background(RoomTheme.chipBg, in: RoundedRectangle(cornerRadius: 16))
                }
                Divider().padding(.vertical, 4)
            }
            Button { isImportingFile = true } label: {
                Label(GameStrings.text("saveTransfer.chooseFile"), systemImage: "square.and.arrow.down")
                    .font(.system(size: 15, weight: .bold))
            }
            .buttonStyle(SoftButtonStyle()).disabled(busy)
            .accessibilityIdentifier("saveImportButton")
            Text(GameStrings.text("saveTransfer.importHint"))
                .font(.system(size: 12)).foregroundStyle(RoomTheme.secondary)
        }
        .padding(16).gameCard()
    }

    private var recoveryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(GameStrings.text("saveTransfer.recoveryTitle"), systemImage: "arrow.uturn.backward.circle.fill")
                .font(.system(size: 17, weight: .heavy))
                .accessibilityIdentifier("saveRecoveryCard")
            Text(GameStrings.text(recoveryUnavailable ? "saveTransfer.unknownRecovery"
                                  : (recovery == nil ? "saveTransfer.noRecovery" : "saveTransfer.recoveryHint")))
                .font(.system(size: 13)).foregroundStyle(RoomTheme.secondary)
            if let recovery {
                Text(GameStrings.format("saveTransfer.recoverySummary",
                                        recovery.snapshot.player.level, recovery.snapshot.cats.count))
                    .font(.system(size: 13, weight: .bold))
                Text(dateText(recovery.snapshot.meta.lastSyncAt))
                    .font(.system(size: 12)).foregroundStyle(RoomTheme.secondary)
                Button { previewRecovery() } label: {
                    Text(GameStrings.text("saveTransfer.previewRecovery"))
                        .font(.system(size: 14, weight: .bold))
                }
                .buttonStyle(SoftButtonStyle()).disabled(busy)
                .accessibilityIdentifier("saveRecoveryButton")
            }
        }
        .padding(16).gameCard()
    }

    private func summary(_ snapshot: GameSnapshot, title: String, time: Date, timeTitle: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(GameStrings.text(title)).font(.system(size: 13, weight: .heavy))
                .foregroundStyle(RoomTheme.secondary)
            Text(verbatim: snapshot.player.profile.name ?? GameStrings.text("player.name.default"))
                .font(.system(size: 23, weight: .heavy))
                .fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) { summaryValues(snapshot) }
                VStack(alignment: .leading, spacing: 8) { summaryValues(snapshot) }
            }
            .font(.system(size: 14, weight: .bold))
            Text(GameStrings.format("saveTransfer.timestamp", GameStrings.text(timeTitle), dateText(time)))
                .font(.system(size: 12)).foregroundStyle(RoomTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).gameCard()
    }

    @ViewBuilder private func summaryValues(_ snapshot: GameSnapshot) -> some View {
        Text(GameStrings.format("career.level", snapshot.player.level))
        Label("\(snapshot.player.gold)", systemImage: "dollarsign.circle.fill")
            .foregroundStyle(RoomTheme.gold)
            .accessibilityLabel(GameStrings.format("saveTransfer.gold", snapshot.player.gold))
        Label(GameStrings.format("saveTransfer.catCount", snapshot.cats.count), systemImage: "pawprint.fill")
            .foregroundStyle(RoomTheme.darkMint)
    }

    private func importConfirmation(_ candidate: ImportPreview) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    summary(candidate.archive.snapshot,
                            title: candidate.isRecovery ? "saveTransfer.recoveryTitle" : "saveTransfer.filePreview",
                            time: candidate.isRecovery ? candidate.archive.snapshot.meta.lastSyncAt : candidate.archive.exportedAt,
                            timeTitle: candidate.isRecovery ? "saveTransfer.progressTime" : "saveTransfer.exportTime")
                        .accessibilityIdentifier("saveImportPreview")
                    Text(GameStrings.text("saveTransfer.importHint"))
                        .font(.system(size: 13)).foregroundStyle(RoomTheme.secondary)
                    Label(GameStrings.text("saveTransfer.replaceWarning"), systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 14, weight: .bold)).foregroundStyle(RoomTheme.coral)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(GameStrings.text(recoveryOnly ? "saveTransfer.failurePromise" : "saveTransfer.recoveryPromise"))
                        .font(.system(size: 13)).foregroundStyle(RoomTheme.secondary)
                        .accessibilityIdentifier(recoveryOnly ? "saveFailureRawPreservationNotice" : "saveRecoveryPromise")
                    if !recoveryOnly {
                        recoveryReplacementWarning(includeSummary: !candidate.isRecovery
                            || recovery?.snapshot != candidate.archive.snapshot)
                    }
                    Button { confirm(candidate) } label: {
                        Text(GameStrings.text(recoveryOnly ? "saveTransfer.failureConfirm"
                                              : (candidate.isRecovery ? "saveTransfer.confirmRecovery" : "saveTransfer.confirmImport")))
                            .font(.system(size: 16, weight: .heavy)).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(MintButtonStyle()).disabled(busy)
                    .accessibilityIdentifier("saveConfirmImportButton")
                    Button { preview = nil } label: {
                        Text(GameStrings.text("common.cancel")).font(.system(size: 15, weight: .bold))
                    }
                    .buttonStyle(SoftButtonStyle()).disabled(isWorking)
                    .accessibilityIdentifier("saveCancelImportButton")
                    if isWorking { ProgressView(GameStrings.text("saveTransfer.working")) }
                    if isError, let statusKey {
                        Text(GameStrings.text(statusKey)).font(.system(size: 13, weight: .bold))
                            .foregroundStyle(RoomTheme.coral)
                            .accessibilityIdentifier("saveImportError")
                    }
                }
                .padding(20).frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .background(RoomTheme.cream.ignoresSafeArea())
            .navigationTitle(GameStrings.text(candidate.isRecovery ? "saveTransfer.previewRecovery" : "saveTransfer.filePreview"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .fontDesign(.rounded).foregroundStyle(RoomTheme.ink)
        .environment(\.locale, Locale(identifier: store.language.rawValue))
        .interactiveDismissDisabled(isWorking)
    }

    @ViewBuilder private func recoveryReplacementWarning(includeSummary: Bool) -> some View {
        if let recovery {
            VStack(alignment: .leading, spacing: 10) {
                Label(GameStrings.text("saveTransfer.replaceRecovery"), systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(RoomTheme.coral)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("saveRecoveryReplacementWarning")
                if includeSummary {
                    Text(GameStrings.format("saveTransfer.recoverySummary",
                                            recovery.snapshot.player.level, recovery.snapshot.cats.count))
                        .font(.system(size: 14, weight: .bold))
                        .accessibilityIdentifier("saveExistingRecoverySummary")
                    Text(GameStrings.format("saveTransfer.timestamp", GameStrings.text("saveTransfer.progressTime"),
                                            dateText(recovery.snapshot.meta.lastSyncAt)))
                        .font(.system(size: 12)).foregroundStyle(RoomTheme.secondary)
                        .accessibilityIdentifier("saveExistingRecoveryTime")
                }
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading).gameCard()
        } else if recoveryUnavailable {
            Label(GameStrings.text("saveTransfer.unknownRecovery"), systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .bold)).foregroundStyle(RoomTheme.coral)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("saveRecoveryReplacementWarning")
        }
    }

    private func prepareExport() {
        guard !busy else { return }
        isWorking = true
        statusKey = nil
        Task {
            defer { isWorking = false }
            do {
                let data = try await store.exportSaveArchive()
                let prepared = try await Task.detached {
                    (try SaveArchiveFiles.prepareShareFile(data), try NativeSaveTransfer.decode(data).exportedAt)
                }.value
                exportDocument = SaveArchiveDocument(data: data)
                exportURL = prepared.0
                exportDate = prepared.1
            } catch { report(error) }
        }
    }

    private func readImport(_ url: URL) {
        isWorking = true
        statusKey = nil
        Task {
            defer { isWorking = false }
            do {
                let archive = try await Task.detached { try SaveArchiveFiles.read(url) }.value
                if !recoveryOnly { await refreshRecovery() }
                preview = ImportPreview(archive: archive, isRecovery: false)
            } catch { report(error) }
        }
    }

    private func confirm(_ candidate: ImportPreview) {
        guard !busy else { return }
        isWorking = true
        statusKey = nil
        Task {
            defer { isWorking = false }
            do {
                if recoveryOnly {
                    try await store.restoreSaveArchiveAfterLoadFailure(candidate.archive)
                } else {
                    try await store.importSaveArchive(candidate.archive, isRecovery: candidate.isRecovery)
                }
                preview = nil
                exportDocument = nil
                exportURL = nil
                exportDate = nil
                if recoveryOnly {
                    setStatus("saveTransfer.failureRestored")
                    onRecovered?()
                } else {
                    setStatus(candidate.isRecovery ? "saveTransfer.restored" : "saveTransfer.imported")
                    await refreshRecovery()
                }
            } catch {
                // The undo point can be replaced before the final primary write fails.
                if !recoveryOnly { await refreshRecovery() }
                report(error)
            }
        }
    }

    private func refreshRecovery() async {
        recoveryUnavailable = true
        recovery = nil
        do {
            recovery = try await store.importRecoveryPreview()
            recoveryUnavailable = false
        } catch { report(error) }
    }

    private func previewRecovery() {
        guard !busy else { return }
        isWorking = true
        statusKey = nil
        Task {
            defer { isWorking = false }
            await refreshRecovery()
            if let recovery { preview = ImportPreview(archive: recovery, isRecovery: true) }
        }
    }

    private func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: store.language.rawValue)
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func setStatus(_ key: String) {
        statusKey = key
        isError = false
    }

    private func report(_ error: Error) {
        if (error as? CocoaError)?.code == .userCancelled { return }
        statusKey = recoveryOnly && (error as? SaveTransferError) == .writeFailed
            ? "saveTransfer.failureWriteFailed" : SaveTransferError.messageKey(for: error)
        isError = true
    }
}
