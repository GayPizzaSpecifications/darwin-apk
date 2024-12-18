/*
 * darwin-apk © 2024 Gay Pizza Specifications
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import System

public class MemoryInputStream: InputStream {
  private let _str: Storage
  private let _ptr: UnsafeBufferPointer<UInt8>
  private let _len: Int
  private var _idx = 0

  public init(buffer: Data) {
    self._len = buffer.count
    self._str = .buffer(.allocate(capacity: self._len))
    if case .buffer(let buf) = self._str {
      _ = buffer.copyBytes(to: buf)
      self._ptr = .init(start: buf.baseAddress, count: self._len)
    } else { fatalError() }
  }

  public init(view: ArraySlice<UInt8>) {
    self._len = view.count
    self._str = .slice(view)
    if case .slice(let sli) = self._str {
      self._ptr = sli.withUnsafeBufferPointer(\.self)
    } else { fatalError() }
  }

  deinit {
    if case .buffer(let buf) = self._str {
      buf.deallocate()
    }
  }

  public override func seek(_ whence: Whence) throws(StreamError) {
    let (position, overflow) = switch whence {
    case .set(let position):   (position, false)
    case .current(let offset): self._idx.addingReportingOverflow(offset)
    case .end(let offset):     self._len.addingReportingOverflow(offset)
    }
    if overflow {
      throw .overflow
    } else if position < 0 {
      throw .seekRange
    } else {
      self._idx = position
    }
  }

  public override var tell: Int {
    get throws(StreamError) {
      self._idx
    }
  }

  public override func read(_ count: Int) throws(StreamError) -> Data {
    let beg = min(self._idx, self._len)
    let end = min(self._idx + count, self._len)
    let bytes = Data(self._ptr[beg..<end])
    self._idx += beg.distance(to: end)
    return bytes
  }

  public override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength count: Int) throws(StreamError) -> Int {
    let beg = min(self._idx, self._len)
    let end = min(self._idx + count, self._len)
    let len = beg.distance(to: end)
    let buf = UnsafeMutableRawBufferPointer(start: buffer, count: len)
    self._idx += len
    return self._ptr.copyBytes(to: buf, from: beg..<end)
  }

  public override func next() -> UInt8? {
    if _fastPath(self._idx < self._len) {
      defer { self._idx += 1 }
      return self._ptr[self._idx]
    } else {
      return nil
    }
  }
}

fileprivate extension MemoryInputStream {
  enum Storage {
    case buffer(_: UnsafeMutableBufferPointer<UInt8>)
    case slice(_: ArraySlice<UInt8>)
  }
}
