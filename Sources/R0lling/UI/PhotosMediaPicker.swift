import SwiftUI
import UniformTypeIdentifiers

#if canImport(PhotosUI)
import PhotosUI
#endif

/// Κουμπί εισαγωγής media από Photos (PHPicker via PhotosUI) + Files για ήχο/άλλα.
/// A03: πραγματική ανάγνωση Data — χωρίς fake success αν αποτύχει το load.
public struct PhotosMediaPickerButton: View {
    public var isDisabled: Bool
    public var onImport: (Data, String, MediaType) async -> Void
    public var onError: (String) -> Void

#if canImport(PhotosUI)
    @State private var photoSelection: [PhotosPickerItem] = []
#endif
    @State private var deikseFileImporter: Bool = false

    public init(
        isDisabled: Bool = false,
        onImport: @escaping (Data, String, MediaType) async -> Void,
        onError: @escaping (String) -> Void
    ) {
        self.isDisabled = isDisabled
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
            }
            .disabled(isDisabled)
            .onChange(of: photoSelection) { _, neoSelection in
                Task { await epeksergasiaPhotosPicker(neoSelection) }
            }
            .accessibilityLabel("Εισαγωγή από Photos")
#endif
            Button(action: {
                R0llingTheme.triggerHapticFeedback()
                deikseFileImporter = true
            }) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(isDisabled ? R0llingTheme.textMuted : R0llingTheme.stravaOrange)
                    .frame(width: 44, height: 44)
                    .background(R0llingTheme.bgElevated)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(R0llingTheme.borderSubtle, lineWidth: 1)
                    )
            }
            .disabled(isDisabled)
            .accessibilityLabel("Εισαγωγή αρχείου media")
        }
        .fileImporter(
            isPresented: $deikseFileImporter,
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
                guard let data = try await item.loadTransferable(type: Data.self), !data.isEmpty else {
                    onError("Αποτυχία φόρτωσης από Photos (κενά δεδομένα).")
                    continue
                }
                let mediaType = try epilysiMediaType(apo: item)
                let filename = syntheshOnomatos(apo: item, mediaType: mediaType)
                await onImport(data, filename, mediaType)
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

    private func syntheshOnomatos(apo item: PhotosPickerItem, mediaType: MediaType) -> String {
        "\(UUID().uuidString).\(proepiloghmeniEpektasi(mediaType))"
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
                    let data = try Data(contentsOf: url)
                    guard !data.isEmpty else {
                        onError("Κενό αρχείο: \(url.lastPathComponent)")
                        continue
                    }
                    let mediaType = try JournalMediaImporter.mediaType(
                        giaOnomaArxeiou: url.lastPathComponent,
                        utTypeIdentifier: UTType(filenameExtension: url.pathExtension)?.identifier
                    )
                    await onImport(data, url.lastPathComponent, mediaType)
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
