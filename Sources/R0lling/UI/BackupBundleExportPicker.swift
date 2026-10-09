import SwiftUI

#if canImport(UIKit)
import UIKit

/// Exports the backup directory as a copy through the system Files document picker.
@MainActor
public struct BackupBundleExportPicker: UIViewControllerRepresentable {
    public let bundleURL: URL
    public let onFinish: (Bool) -> Void

    public init(bundleURL: URL, onFinish: @escaping (Bool) -> Void) {
        self.bundleURL = bundleURL
        self.onFinish = onFinish
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    public func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: [bundleURL], asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }

    public func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}

    @MainActor
    public final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onFinish: (Bool) -> Void

        init(onFinish: @escaping (Bool) -> Void) {
            self.onFinish = onFinish
        }

        public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onFinish(!urls.isEmpty)
        }

        public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onFinish(false)
        }
    }
}
#endif
