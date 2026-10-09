import UniformTypeIdentifiers

public extension UTType {
    /// Directory package used by R0lling's export/import flow.
    static let r0llingBackupBundle = UTType(
        exportedAs: "com.personal.r0lling.backup-bundle",
        conformingTo: .package
    )
}
