import Foundation
import SwiftUI
import R0lling

/// Host entry point για το iOS application target (XcodeGen).
@main
struct R0llingAppHost: App {
    /// Documentation-only marker για P0-05 verify harness.
    static let scaffoldMarker = "R0llingAppHostScaffold-P0-05"

    var body: some Scene {
        R0llingApp().body
    }
}
