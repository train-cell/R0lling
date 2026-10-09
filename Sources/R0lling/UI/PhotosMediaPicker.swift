import SwiftUI
import UniformTypeIdentifiers
import CoreTransferable

#if canImport(PhotosUI)
import PhotosUI
#endif

/// File-backed, size-limited import used by photo-to-vision paths. Photos providers may hand
/// over RAW or very large originals, so the byte bound is checked before reading them into RAM.
struct ImportedVisionPhoto: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            let sourceURL = received.file
            let values = try sourceURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values.isRegularFile == true,
                  let fileSize = values.fileSize,
                  fileSize > 0,
                  fileSize <= ImageMetadataSanitizer.maximumVisionInputBytes else {
                throw failure("Η εικόνα είναι κενή, μη κανονικό αρχείο ή υπερβαίνει το όριο των 40 MB.")
            }

            let suffix = sourceURL.pathExtension.isEmpty ? "image" : sourceURL.pathExtension
            let destinationURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("R0lling-VisionImport-\(UUID().uuidString).\(suffix)")
            do {
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            } catch {
                try? FileManager.default.removeItem(at: destinationURL)
                throw error
            }
            return ImportedVisionPhoto(url: destinationURL)
        }
    }

    func loadVisionData() throws -> Data {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true,
              let fileSize = values.fileSize,
              fileSize > 0,
              fileSize <= ImageMetadataSanitizer.maximumVisionInputBytes else {
            throw Self.failure("Η εικόνα είναι κενή ή υπερβαίνει το όριο των 40 MB.")
        }
        let sourceData = try Data(contentsOf: url, options: .mappedIfSafe)
        return try ImageMetadataSanitizer.encodeForVision(sourceData)
    }

    private static func failure(_ message: String) -> NSError {
        NSError(domain: "R0lling.VisionImport", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

/// Κουμπί εισαγωγής media από Photos (PHPicker via PhotosUI) + Files για ήχο/άλλα.
/// A03: file-backed import for large assets; failed loads never report success.
public struct PhotosMediaPickerButton: View {
    public var isDisabled: Bool
    @Binding public var isFileImporterPresented: Bool
    public var onImport: (URL, String, MediaType) async -> Void
    public var onError: (String) -> Void

#if canImport(PhotosUI)
    @State private var photoSelection: [PhotosPickerItem] = []
#endif
    public init(
        isDisabled: Bool = false,
        isFileImporterPresented: Binding<Bool>,
        onImport: @escaping (URL, String, MediaType) async -> Void,
        onError: @escaping (String) -> Void
    ) {
        self.isDisabled = isDisabled
        self._isFileImporterPresented = isFileImporterPresented
        self.onImport = onImport
        self.onError = onError
    }

    public var body: some View {
        HStack(spacing: 6) {
#if canImport(PhotosUI)
            PhotosPicker(
                selection: $photoSelection,
                maxSelectionCount: 5,
                matching: .any(of: [.images, .videos])
            ) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(isDisabled ? R0llingTheme.textMuted : R0llingTheme.bevelCyan)
                    .frame(width: 44, height: 44)
                    .background(R0llingTheme.bgElevated)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(R0llingTheme.borderSubtle, lineWidth: 1)
                    )
                    .r0llingBevelCapsule()
            }
            .disabled(isDisabled)
            .onChange(of: photoSelection) { _, neoSelection in
                Task { await epeksergasiaPhotosPicker(neoSelection) }
            }
            .accessibilityLabel("Εισαγωγή από Photos")
#endif
            Button(action: {
                R0llingTheme.triggerHapticFeedback()
                isFileImporterPresented = true
            }) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(isDisabled ? R0llingTheme.textMuted : R0llingTheme.accentPurple)
                    .frame(width: 44, height: 44)
                    .background(R0llingTheme.bgElevated)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(R0llingTheme.borderSubtle, lineWidth: 1)
                    )
                    .r0llingBevelCapsule()
            }
            .disabled(isDisabled)
            .accessibilityLabel("Εισαγωγή αρχείου media")
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.image, .movie, .video, .audio, .mpeg4Movie, .mpeg4Audio],
            allowsMultipleSelection: true
        ) { apotelesma in
            Task { await epeksergasiaFileImporter(apotelesma) }
        }
    }

#if canImport(PhotosUI)
    private func epeksergasiaPhotosPicker(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        defer { photoSelection = [] }

        for item in items {
            do {
                let mediaType = try epilysiMediaType(apo: item)
                guard let importedFile = try await item.loadTransferable(type: ImportedPhotosFile.self) else {
                    onError("Αποτυχία φόρτωσης αρχείου από Photos.")
                    continue
                }
                defer { try? FileManager.default.removeItem(at: importedFile.url) }
                let filename = syntheshOnomatos(apo: importedFile.url, mediaType: mediaType)
                await onImport(importedFile.url, filename, mediaType)
            } catch {
                onError("Photos import: \(error.localizedDescription)")
            }
        }
    }

    private func epilysiMediaType(apo item: PhotosPickerItem) throws -> MediaType {
        if let ut = item.supportedContentTypes.first {
            if ut.conforms(to: .image) { return .photo }
            if ut.conforms(to: .movie) || ut.conforms(to: .video) { return .video }
            if ut.conforms(to: .audio) { return .audio }
        }
        throw MediaApothikeusiError.agnostosTypos(onomaArxeiou: item.itemIdentifier ?? "photos_item")
    }

    private func syntheshOnomatos(apo fileURL: URL, mediaType: MediaType) -> String {
        let pathExtension = fileURL.pathExtension.lowercased()
        let extensionToUse = pathExtension.isEmpty ? proepiloghmeniEpektasi(mediaType) : pathExtension
        return "\(UUID().uuidString).\(extensionToUse)"
    }

    private struct ImportedPhotosFile: Transferable {
        let url: URL

        static var transferRepresentation: some TransferRepresentation {
            FileRepresentation(importedContentType: .image) { received in
                try copyReceivedFile(received.file)
            }
            FileRepresentation(importedContentType: .movie) { received in
                try copyReceivedFile(received.file)
            }
            FileRepresentation(importedContentType: .video) { received in
                try copyReceivedFile(received.file)
            }
        }

        private static func copyReceivedFile(_ sourceURL: URL) throws -> ImportedPhotosFile {
            let fileExtension = sourceURL.pathExtension.isEmpty ? "media" : sourceURL.pathExtension
            let destinationURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("R0lling-PhotosImport-\(UUID().uuidString).\(fileExtension)")
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return ImportedPhotosFile(url: destinationURL)
        }
    }
#endif

    private func epeksergasiaFileImporter(_ apotelesma: Result<[URL], Error>) async {
        switch apotelesma {
        case .failure(let error):
            onError("Files import: \(error.localizedDescription)")
        case .success(let urls):
            for url in urls {
                let accessed = url.startAccessingSecurityScopedResource()
                defer {
                    if accessed { url.stopAccessingSecurityScopedResource() }
                }
                do {
                    let mediaType = try JournalMediaImporter.mediaType(
                        giaOnomaArxeiou: url.lastPathComponent,
                        utTypeIdentifier: UTType(filenameExtension: url.pathExtension)?.identifier
                    )
                    await onImport(url, url.lastPathComponent, mediaType)
                } catch {
                    onError("Ανάγνωση \(url.lastPathComponent): \(error.localizedDescription)")
                }
            }
        }
    }

    private func proepiloghmeniEpektasi(_ typo: MediaType) -> String {
        switch typo {
        case .photo: return "jpg"
        case .video, .clip: return "mp4"
        case .audio: return "m4a"
        }
    }
}
