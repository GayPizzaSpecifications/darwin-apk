/*
 * darwin-apk © 2024 Gay Pizza Specifications
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

internal struct ApkRequirement {
  static func extract(blob extract: String) throws(ParseError) -> (String, ApkVersionSpecification) {
    var comparer: ComparatorBits = []
    var dependStr = extract[...]
    let nameEnd: String.Index, versionStart: String.Index

    // Check for bang prefix to indicate a conflict
    if dependStr.first == "!" {
      comparer.insert(.conflict)
      dependStr = dependStr[dependStr.index(after: dependStr.startIndex)...]
    }

    // Match comparator
    if let range = dependStr.firstRange(where: { [ "<", "=", ">", "~" ].contains($0) }) {
      for c in dependStr[range] {
        switch c {
        case "<": comparer.insert(.less)
        case "=": comparer.insert(.equals)
        case ">": comparer.insert(.greater)
        case "~": comparer.formUnion([ .fuzzy, .equals ])
        default: break
        }
      }
      (nameEnd, versionStart) = (range.lowerBound, range.upperBound)
    } else {
      // 
      if !comparer.contains(.conflict) {
        comparer.formUnion(.any)
      }
      (nameEnd, versionStart) = (dependStr.endIndex, dependStr.endIndex)
    }

    // Parse version specification
    let spec = try ApkVersionSpecification(comparer, version: dependStr[versionStart...])
    let name = String(dependStr[..<nameEnd])
    return (name, spec)
  }
}

extension ApkRequirement {
  enum ParseError: Error, LocalizedError {
    case brokenSpec

    var errorDescription: String? {
      switch self {
      case .brokenSpec: "Invalid version specification"
      }
    }
  }
}

//MARK: - Private Implementation

fileprivate extension ApkRequirement {
  struct ComparatorBits: OptionSet {
    let rawValue: UInt8

    static let equals: Self   = Self(rawValue: 1 << 0)
    static let less: Self     = Self(rawValue: 1 << 1)
    static let greater: Self  = Self(rawValue: 1 << 2)
    static let fuzzy: Self    = Self(rawValue: 1 << 3)
    static let conflict: Self = Self(rawValue: 1 << 4)

    static let any: Self = [ .equals, .less, .greater ]
    static let checksum: Self = [ .less, .greater ]
  }
}

fileprivate extension ApkVersionSpecification {
  init(_ bits: ApkRequirement.ComparatorBits, version: Substring) throws(ApkRequirement.ParseError) {
    if bits == [ .conflict ] {
      self = .conflict
    } else {
      if bits.contains(.conflict) {
        throw .brokenSpec
      } else if bits == [ .any ] {
        self = .any
      } else {
        self = .constraint(op: try .init(bits), version: String(version))
      }
    }
  }
}

fileprivate extension ApkVersionSpecification.Operator {
  init(_ bits: ApkRequirement.ComparatorBits) throws(ApkRequirement.ParseError) {
    self = switch bits.subtracting(.conflict) {
    case .equals:   .equals
    case .less:     .less
    case .greater:  .greater
    //case .checksum: .checksum
    case [ .equals, .less ]:    .lessEqual
    case [ .equals, .greater ]: .greaterEqual
    case [ .fuzzy, .equals ], .fuzzy:  .fuzzyEquals
    case [ .fuzzy, .equals, .less]:    .lessFuzzy
    case [ .fuzzy, .equals, .greater]: .greaterFuzzy
    default: throw .brokenSpec
    }
  }
}

fileprivate extension Substring {
  func firstRange(where predicate: (Character) throws -> Bool) rethrows -> Range<Self.Index>? {
    guard let start = try self.firstIndex(where: predicate) else {
      return nil
    }
    var idx = start
    repeat {
      idx = self.index(after: idx)
    } while try idx != self.endIndex && predicate(self[idx])
    return start..<idx
  }
}