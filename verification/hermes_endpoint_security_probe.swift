import Foundation

@main
struct HermesEndpointSecurityProbe {
    static func main() throws {
        let ambiguousHosts = [
            "010.0.0.1",       // Octal 8.0.0.1 on legacy resolvers
            "0172.16.0.1",     // Octal 122.16.0.1 on legacy resolvers
            "192.168.001.001", // Non-canonical octets
            "2130706433",      // One-part integer IPv4
            "127.1",           // Short IPv4 form
            "0x7f000001"       // Hexadecimal IPv4
        ]

        for host in ambiguousHosts {
            precondition(
                !HermesEndpointAsfaleia.isAllowlistedCleartextHost(host),
                "Ambiguous host passed the HTTP allowlist: \(host)"
            )
            do {
                _ = try HermesEndpointAsfaleia.epikyroseHermesBaseURL("http://\(host):8080")
                fatalError("Ambiguous Hermes HTTP URL was accepted: \(host)")
            } catch {
                // Expected: URL validation rejects the ambiguous numeric host.
            }
        }

        for allowedHost in ["10.0.0.1", "192.168.1.50", "127.0.0.1", "100.100.0.1"] {
            precondition(
                HermesEndpointAsfaleia.isAllowlistedCleartextHost(allowedHost),
                "Canonical allowlisted host was rejected: \(allowedHost)"
            )
        }

        for raw in [
            "https://user:secret@proxy.example/v1",
            "https://proxy.example/v1?api_key=secret",
            "http://user:secret@192.168.1.50:8080/v1"
        ] {
            do {
                _ = try HermesEndpointAsfaleia.epikyroseDirectBaseURL(raw)
                fatalError("Direct endpoint accepted userinfo or query data: \(raw)")
            } catch {
                // Expected: provider base URLs must not carry credentials in URLs.
            }
            do {
                _ = try HermesEndpointAsfaleia.epikyroseHermesBaseURL(raw)
                fatalError("Hermes endpoint accepted userinfo or query data: \(raw)")
            } catch {
                // Expected: provider base URLs must not carry credentials in URLs.
            }
        }

        print("PASS: numeric-host allowlist enforced; provider base URLs reject userinfo and query parameters")
    }
}
