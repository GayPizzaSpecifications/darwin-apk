/*
 * darwin-apk © 2024 Gay Pizza Specifications
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public struct ApkIndexDependency: Hashable {
  let requirement: ApkRequirement

  init(requirement: ApkRequirement) {
    self.requirement = requirement
  }
}
