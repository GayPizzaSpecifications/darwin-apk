/*
 * darwin-apk © 2024 Gay Pizza Specifications
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public struct TarReader {
  private static let tarBlockSize  = 512
  private static let tarTypeOffset = 156
  private static let tarNameOffset =   0
  private static let tarNameSize   = 100
  private static let tarSizeOffset = 124
  private static let tarSizeSize   =  12

  public enum Entry {
    case file(name: String, data: Data)
    case directory(name: String)
  }

  public static func read(_ stream: InputStream) throws -> [Entry] {
    var entries = [Entry]()

    while true {
      let tarBlock = try stream.read(Self.tarBlockSize)
      if tarBlock.isEmpty { break }
      guard tarBlock.count == Self.tarBlockSize else {
        throw TarError.unexpectedEndOfStream
      }

      let type = UnicodeScalar(tarBlock[Self.tarTypeOffset])
      switch type {
      case "0":  // Regular file
        // Read metadata
        let name = try Self.readName(tarBlock)
        let size = try Self.readSize(tarBlock)

        // Read file data
        var data = Data()
        if size > 0 {
          data = try stream.read(size)
          guard size == data.count else {
            throw TarError.unexpectedEndOfStream
          }

          // Seek to next block boundry
          let blockN1 = Self.tarBlockSize - 1
          let seekAmount = blockN1 - ((size + blockN1) % Self.tarBlockSize)  // 511 − ((size − 1) & 0x1FF)
          if seekAmount > 0 {
            try stream.seek(.current(seekAmount))
          }
        }

        entries.append(.file(name: name, data: data))
      case "5":
        // Directory
        let name = try Self.readName(tarBlock)
        entries.append(.directory(name: name))
      case "\0":
        // Null block, might also be a legacy regular file
        break
      case "x":
        // Extended header block
        try stream.seek(.current(Self.tarBlockSize))
      // Symlink, Reserved, Character, Block, FIFO, Reserved, Global, ignore all these
      case "1", "2", "3", "4", "6", "7", "g":
        let size = try self.readSize(tarBlock)
        let blockCount = (size - 1) / Self.tarBlockSize + 1  // Compute blocks to skip
        try stream.seek(.current(Self.tarBlockSize * blockCount))
      default: throw TarError.invalidType(type: type)  // Not a TAR type
      }
    }
    return entries
  }

  private static func readName(_ tar: Data, offset: Int = Self.tarNameOffset) throws (TarError) -> String {
    var nameSize = Self.tarNameSize
    for i in 0...Self.tarNameSize {
      if tar[offset + i] == 0 {
        nameSize = i
        break
      }
    }
    let data = tar.subdata(in: offset..<offset + nameSize)
    guard let name = String(data: data, encoding: .utf8) else { throw TarError.badNameField }
    return name
  }

  private static func readSize(_ tar: Data, offset: Int = Self.tarSizeOffset) throws (TarError) -> Int {
    let sizeData = tar.subdata(in: offset..<offset + Self.tarSizeSize)
    let sizeEnd = sizeData.firstIndex(of: 0) ?? sizeData.endIndex  // Find the null terminator
    guard
      let sizeString = String(data: sizeData[..<sizeEnd], encoding: .ascii),
      let result = Int(sizeString, radix: 0o10) else { throw TarError.badSizeField }
    return result
  }
}

public enum TarError: Error, LocalizedError {
  case unexpectedEndOfStream
  case invalidType(type: UnicodeScalar)
  case badNameField, badSizeField

  public var errorDescription: String? {
    switch self {
    case .unexpectedEndOfStream: "Stream unexpectedly ended early"
    case .invalidType(let type): "Invalid block type \(type) found"
    case .badNameField: "Bad name field"
    case .badSizeField: "Bad size field"
    }
  }
}

public extension Array<TarReader.Entry> {
  func firstFile(name firstNameMatch: String) -> Data? {
    for entry in self {
      if case .file(let name, let data) = entry {
        if name == firstNameMatch {
          return data
        }
      }
    }
    return nil
  }
}
