/*
 * darwin-apk © 2024 Gay Pizza Specifications
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

extension Data {
  init?(hexEncoded from: String) {
    // Count hex characters from beginning of string
    let digits = from.count(where: \.isHexDigit)

    // Ensure even number of digets
    guard digits & 0x1 == 0 else {
      return nil
    }

    let elements = digits >> 1
    self.init(capacity: elements)

    // Convert digits
    var idx = from.startIndex
    for _ in 0..<elements {
      let hi = from[idx].hexDigitValue!
      idx = from.index(after: idx)
      let lo = from[idx].hexDigitValue!
      idx = from.index(after: idx)
      let byte = UInt8(truncatingIfNeeded: lo + hi << 4)
      self.append(byte)
    }
  }
}