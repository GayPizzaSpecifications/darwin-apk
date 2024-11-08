// SPDX-License-Identifier: Apache-2.0

import Foundation

struct ApkIndexPackage {
  let indexChecksum: String  //TODO: Decode cus why not
  let name: String
  let version: String
  let architecture: String?
  let packageSize: UInt64
  let installedSize: UInt64
  let packageDescription: String
  let url: String
  let license: String
  let origin: String?
  let maintainer: String?
  let buildTime: Date?
  let commit: String?
  let providerPriority: UInt16?
  let dependencies: [String]  //TODO: stuff
  let provides: [String]  //TODO: stuff
  let installIf: [String]  //TODO: stuff

  var downloadFilename: String { "\(self.name)-\(version).apk" }

  //TODO: Implementation
  //lazy var semanticVersion: (Int, Int, Int) = (0, 0, 0)
}

extension ApkIndexPackage {
  init(raw rawEntry: ApkRawIndexEntry) throws(Self.ParseError) {
    // Required fields
    var indexChecksum: String? = nil
    var name: String? = nil
    var version: String? = nil
    var description: String? = nil
    var url: String? = nil
    var license: String? = nil
    var packageSize: UInt64? = nil
    var installedSize: UInt64? = nil

    var dependencies = [String]()
    var provides = [String]()
    var installIf = [String]()

    // Optional fields
    var architecture: String? = nil
    var origin: String? = nil
    var maintainer: String? = nil
    var buildTime: Date? = nil
    var commit: String? = nil
    var providerPriority: UInt16? = nil

    // Read all the raw records for this entry
    for record in rawEntry.fields {
      switch record.key {
      case "P":
        name = record.value
      case "V":
        version = record.value
      case "T":
        description = record.value
      case "U":
        url = record.value
      case "L":
        license = record.value
      case "A":
        architecture = record.value
      case "D":
        dependencies = record.value.components(separatedBy: " ")
      case "C":
        indexChecksum = record.value  // base64-encoded SHA1 hash prefixed with "Q1"
      case "S":
        guard let value = UInt64(record.value, radix: 10) else {
          throw .badValue(key: record.key)
        }
        packageSize = value
      case "I":
        guard let value = UInt64(record.value, radix: 10) else {
          throw .badValue(key: record.key)
        }
        installedSize = value
      case "p":
        provides = record.value.components(separatedBy: " ")
      case "i":
        installIf = record.value.components(separatedBy: " ")
      case "o":
        origin = record.value
      case "m":
        maintainer = record.value
      case "t":
        guard let timet = UInt64(record.value, radix: 10),
            let timetInterval = TimeInterval(exactly: timet) else {
          throw .badValue(key: record.key)
        }
        buildTime = Date(timeIntervalSince1970: timetInterval)
      case "c":
        commit = record.value
      case "k":
        guard let value = UInt64(record.value, radix: 10),
            (0..<UInt64(UInt16.max)).contains(value) else {
          throw .badValue(key: record.key)
        }
        providerPriority = UInt16(truncatingIfNeeded: value)
      case "F", "M", "R", "Z", "r", "q", "a", "s", "f":
        break // installed db entries
      default:
        // Safe to ignore
        guard record.key.isLowercase else {
          throw .badValue(key: record.key)
        }
      }
    }

    self.indexChecksum = try indexChecksum.unwrap(or: Self.ParseError.required(key: "C"))
    self.name = try name.unwrap(or: Self.ParseError.required(key: "P"))
    self.version = try version.unwrap(or: Self.ParseError.required(key: "V"))
    self.packageDescription = try description.unwrap(or: Self.ParseError.required(key: "T"))
    self.url = try url.unwrap(or: Self.ParseError.required(key: "U"))
    self.license = try license.unwrap(or: Self.ParseError.required(key: "L"))
    self.packageSize = try packageSize.unwrap(or: Self.ParseError.required(key: "S"))
    self.installedSize = try installedSize.unwrap(or: Self.ParseError.required(key: "I"))

    self.architecture = architecture
    self.origin = origin
    self.maintainer = maintainer
    self.buildTime = buildTime
    self.commit = commit
    self.providerPriority = providerPriority

    self.dependencies = dependencies
    self.provides = provides
    self.installIf = installIf
  }

  public enum ParseError: Error, LocalizedError {
    case badValue(key: Character)
    case unexpectedKey(key: Character)
    case required(key: Character)

    public var errorDescription: String? {
      switch self {
      case .badValue(let key):      "Bad value for key \"\(key)\""
      case .unexpectedKey(let key): "Unexpected key \"\(key)\""
      case .required(let key):      "Missing required key \"\(key)\""
      }
    }
  }
}

extension ApkIndexPackage: CustomStringConvertible {
  var description: String { "pkg(\(self.name))" }
}

fileprivate extension Optional {
  func unwrap<E: Error>(or error: @autoclosure () -> E) throws(E) -> Wrapped {
    switch self {
    case .some(let v):
      return v
    case .none:
      throw error()
    }
  }
}
