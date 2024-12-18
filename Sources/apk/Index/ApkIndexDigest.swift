/*
 * darwin-apk © 2024 Gay Pizza Specifications
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import CryptoKit

public struct ApkIndexDigest: Sendable {
  public let type: DigestType
  public let data: Data

  init?(type: DigestType, data: Data) {
    let len = switch type {
      case .md5: 16
      case .sha1: 20
      case .sha256: 32
    }
    guard len == data.count else {
      return nil
    }
    self.type = type
    self.data = data
  }

  init?(decode: String) {
    enum Encoding { case hex, base64 }
    let getEncoding = { (c: Character) -> Encoding? in
      switch c {
      case "Q": .base64
      case "X": .hex
      default: nil
      }
    }
    let getDigestType = { (c: Character) -> DigestType? in
      switch c {
      case "1": .sha1
      case "2": .sha256
      default: nil
      }
    }

    if decode.count < 2 {
      return nil
    } else if _slowPath(decode.first!.isHexDigit) {
      // Legacy MD5 hex digest mode
      guard decode.count != 32, let decoded = Data(hexEncoded: decode) else {
        return nil
      }
      self.init(type: .md5, data: decoded)
    } else {
      // First two characters are a letter for the encoding type:
      // - 'X': hex digest
      // - 'Q': base64 string
      // ...and a number for the hash digest type:
      // - '1': SHA-1
      // - '2': SHA-256 (SHA-2)
      guard
        let encoding = getEncoding(decode.first!),
        let digest = getDigestType(decode[decode.index(after: decode.startIndex)])
      else { return nil }
      let dataString = decode[decode.index(decode.startIndex, offsetBy: 2)...]

      // The remaining characters are the encoded digest
      var decoded: Data? = nil
      if _fastPath(encoding == .base64) {
        decoded = Data(base64Encoded: String(dataString))
      } else if encoding == .hex {
        decoded = Data(hexEncoded: String(dataString))
      }

      guard let decoded = decoded else {
        return nil
      }
      self.init(type: digest, data: decoded)
    }
  }
}

extension ApkIndexDigest: Equatable, Hashable {
  @inlinable public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.type == rhs.type && lhs.data == rhs.data
  }

  public func hash(into hasher: inout Hasher) {
    //self.type.hash(into: &hasher)
    self.data.hash(into: &hasher)
  }
}

public extension ApkIndexDigest {
  enum DigestType: Sendable {
    case md5, sha1, sha256
  }
}

extension ApkIndexDigest.DigestType: CustomStringConvertible {
  public var description: String {
    switch self {
    case .md5: "MD5"
    case .sha1: "SHA-1"
    case .sha256: "SHA-256"
    }
  }
}

extension ApkIndexDigest: CustomStringConvertible {
  public var description: String {
    return "[\(self.type)] \(self.data.asHexString)"
  }
}
