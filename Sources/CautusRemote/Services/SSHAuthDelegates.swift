import Foundation
import NIOCore
import NIOSSH
import Crypto

/// Authentication delegate that supports password and public key auth.
///
/// Implements SwiftNIO SSH's `NIOSSHClientUserAuthenticationDelegate` protocol.
/// Presents the appropriate credential based on what the server accepts.
final class CautusAuthDelegate: NIOSSHClientUserAuthenticationDelegate {
    private let username: String
    private let credential: Credential
    private var hasAttempted = false

    init(username: String, credential: Credential) {
        self.username = username
        self.credential = credential
    }

    func nextAuthenticationType(
        availableMethods: NIOSSHAvailableUserAuthenticationMethods,
        nextChallengePromise: EventLoopPromise<NIOSSHUserAuthenticationOffer?>
    ) {
        // Only try once — if the server rejects, fail
        guard !hasAttempted else {
            nextChallengePromise.succeed(nil)
            return
        }
        hasAttempted = true

        switch credential {
        case .password(let password):
            guard availableMethods.contains(.password) else {
                nextChallengePromise.succeed(nil)
                return
            }
            nextChallengePromise.succeed(NIOSSHUserAuthenticationOffer(
                username: username,
                serviceName: "",
                offer: .password(.init(password: password))
            ))

        case .privateKey(let path, let passphrase):
            guard availableMethods.contains(.publicKey) else {
                nextChallengePromise.succeed(nil)
                return
            }

            do {
                let privateKey = try Self.loadPrivateKey(from: path, passphrase: passphrase)
                nextChallengePromise.succeed(NIOSSHUserAuthenticationOffer(
                    username: username,
                    serviceName: "",
                    offer: .privateKey(.init(privateKey: privateKey))
                ))
            } catch {
                nextChallengePromise.fail(error)
            }
        }
    }

    // MARK: - Key Loading

    /// Load an SSH private key from a file path.
    private static func loadPrivateKey(from path: String, passphrase: String?) throws -> NIOSSHPrivateKey {
        let expandedPath = NSString(string: path).expandingTildeInPath
        let keyData = try Data(contentsOf: URL(fileURLWithPath: expandedPath))
        guard let keyString = String(data: keyData, encoding: .utf8) else {
            throw SSHAuthError.invalidKeyFormat
        }

        // Try to parse as different key types
        // NIOSSHPrivateKey supports P256, P384, P521, and Ed25519
        if keyString.contains("BEGIN OPENSSH PRIVATE KEY") {
            // Modern OpenSSH format — try Ed25519 first, then ECDSA
            // Note: NIOSSH doesn't parse OpenSSH key files directly;
            // for v1 we support Curve25519 keys via Crypto framework
            if let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: keyData) {
                return NIOSSHPrivateKey(ed25519Key: key)
            }
        }

        // Fallback: try P256
        if let key = try? P256.Signing.PrivateKey(pemRepresentation: keyString) {
            return NIOSSHPrivateKey(p256Key: key)
        }

        // P384
        if let key = try? P384.Signing.PrivateKey(pemRepresentation: keyString) {
            return NIOSSHPrivateKey(p384Key: key)
        }

        // P521
        if let key = try? P521.Signing.PrivateKey(pemRepresentation: keyString) {
            return NIOSSHPrivateKey(p521Key: key)
        }

        throw SSHAuthError.unsupportedKeyType
    }
}

// MARK: - Host Key Verification

/// Accepts all host keys (TOFU — Trust On First Use).
///
/// TODO: Phase 5 — implement known_hosts verification and
/// user prompt for unknown hosts.
final class AcceptAllHostKeysDelegate: NIOSSHClientServerAuthenticationDelegate {
    func validateHostKey(
        hostKey: NIOSSHPublicKey,
        validationCompletePromise: EventLoopPromise<Void>
    ) {
        // Accept all host keys for now
        validationCompletePromise.succeed(())
    }
}

// MARK: - Auth Errors

enum SSHAuthError: Error, LocalizedError {
    case invalidKeyFormat
    case unsupportedKeyType
    case passphraseRequired

    var errorDescription: String? {
        switch self {
        case .invalidKeyFormat:
            return "SSH key file has an invalid format"
        case .unsupportedKeyType:
            return "SSH key type is not supported (supported: Ed25519, P256, P384, P521)"
        case .passphraseRequired:
            return "A passphrase is required for this encrypted key"
        }
    }
}
