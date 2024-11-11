/*
 * darwin-apk © 2024 Gay Pizza Specifications
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public class ApkPackageGraphNode {
  private weak var _graph: ApkPackageGraph?
  let packageID: Int

  //private var _parents = NSHashTable<ApkPackageGraphNode>.weakObjects()
  //private var _children = NSHashTable<ApkPackageGraphNode>.weakObjects()
  var parents = [ApkIndexRequirementRef]()
  var children: [ApkIndexRequirementRef]

  var package: ApkIndexPackage {
    self._graph!.pkgIndex.packages[self.packageID]
  }

  internal init(_ graph: ApkPackageGraph, id: Int, children: [ApkIndexRequirementRef]) {
    self._graph = graph
    self.packageID = id
    self.children = children
  }
}

extension ApkPackageGraphNode: Equatable, Hashable {
  public static func == (lhs: ApkPackageGraphNode, rhs: ApkPackageGraphNode) -> Bool {
    lhs.packageID == rhs.packageID
  }

  public func hash(into hasher: inout Hasher) {
    self.packageID.hash(into: &hasher)
  }
}

extension ApkPackageGraphNode: CustomStringConvertible {
  public var description: String {
    var result = "node[\(self.package.name)]"
    if !self.parents.isEmpty {
      result += ", parents[\(self.parents.lazy.map(\.description).joined(separator: ", "))]"
    }
    if !self.children.isEmpty {
      result += ", children[\(self.children.lazy.map(\.description).joined(separator: ", "))]"
      
    }
    return result
  }
}
