/*
 * darwin-apk © 2024 Gay Pizza Specifications
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import ArgumentParser
import darwin_apk

struct DpkGraphCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(commandName: "graph")

  func run() async throws(ExitCode) {
    let graph: ApkPackageGraph
    do {
      let localRepositories = try await ApkRepositoriesConfig()
      graph = ApkPackageGraph(index: try await ApkIndexReader.resolve(localRepositories.repositories, fetch: .lazy))
      graph.buildGraphNode()

      try graph.pkgIndex.description.write(to: URL(filePath: "packages.txt"), atomically: false, encoding: .utf8)
    } catch {
      fatalError(error.localizedDescription)
    }

#if false
    if var out = TextFileWriter(URL(filePath: "shallowIsolates.txt")) {
      for node in graph.shallowIsolates { print(node, to: &out) }
    }
    if var out = TextFileWriter(URL(filePath: "deepIsolates.txt")) {
      for node in graph.deepIsolates { print(node, to: &out) }
    }
#else
    do {
      let sorted = try graph.parallelOrderSort()
      print(sorted)
    } catch {
      fatalError(error.localizedDescription)
    }
#endif
  }
}
