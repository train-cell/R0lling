import Foundation

/// Midenistis Mnimis gia Krypto-Apomadrynsi Euaisthetwn Dedomena (Idea 2).
/// Ylopoiei afstiro zeroization (midenismo mnimi) me apotelesmatiko byte-by-byte overwriting,
/// apotrepontas tin paramoni kryptografikwn kleidiwn i plaintext shmeiwsewn sti mnimi RAM.
public struct MidenistisMnimis: Sendable {

    public init() {}

    /// Midenizei to periexomeno enos Data buffer stin idia thesi mnimis (in-place).
    public static func midenismosDedomena(_ dedomena: inout Data) {
        guard !dedomena.isEmpty else { return }
        dedomena.withUnsafeMutableBytes { pointer in
            if let baseAddress = pointer.baseAddress {
                #if canImport(Darwin)
                memset_s(baseAddress, pointer.count, 0, pointer.count)
                #else
                for i in 0..<pointer.count {
                    pointer.storeBytes(of: 0 as UInt8, toByteOffset: i, as: UInt8.self)
                }
                #endif
            }
        }
        dedomena = Data()
    }

    /// Midenizei ton pinaka bytes [UInt8] in-place.
    public static func midenismosBytes(_ bytes: inout [UInt8]) {
        guard !bytes.isEmpty else { return }
        for i in 0..<bytes.count {
            bytes[i] = 0
        }
        bytes.removeAll(keepingCapacity: false)
    }

    /// Midenizei apeutheias enan raw memory pointer.
    public static func midenismosPointer(_ pointer: UnsafeMutableRawPointer, megethos: Int) {
        guard megethos > 0 else { return }
        #if canImport(Darwin)
        memset_s(pointer, megethos, 0, megethos)
        #else
        let bytePointer = pointer.bindMemory(to: UInt8.self, capacity: megethos)
        for i in 0..<megethos {
            bytePointer[i] = 0
        }
        #endif
    }
}
