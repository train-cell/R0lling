import Foundation
import SwiftUI

/// Λεπτό host entry για XcodeGen / iOS App target.
/// Το SPM library ήδη έχει `@main R0llingApp` — αυτό το αρχείο είναι placeholder
/// όταν το App target **δεν** κάνει re-export του package `@main`.
///
/// Χρήση: αν το Xcode project χρειάζεται τοπικό `@main`, μετονόμασε/ενεργοποίησε
/// και αφαίρεσε το `@main` από `Sources/R0lling/App/R0llingApp.swift` μόνο στο
/// iOS app scheme (ή κράτα package `@main` για macOS SPM και αυτό για iOS).
///
/// Default: **μη** compile — το package `@main` αρκεί μέχρι να ανοίξει Mac owner
/// το Xcode app target (βλ. README.md).
enum R0llingAppHostScaffold {
    /// Documentation-only marker για P0-05 verify harness.
    static let scaffoldMarker = "R0llingAppHostScaffold-P0-05"
}
