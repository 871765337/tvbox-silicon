import Foundation
import Testing
@testable import TVCore

/// Converted plugin classes are cached under `BytecodeCompatibility.VERSION`. A change to the converter
/// that keeps the version leaves every device on classes from the old converter, and the failures look
/// like broken plugins. This records what the converter's sources were for the current version.
@Test func javaHostVersionChangesWithTheConverter() throws {
    let root = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let java = root.appending(path: "Runtime/JavaHost/src/main/java")
    let manager = FileManager.default
    var inputs = ["tvbox/runtime/BytecodeCompatibility.java", "tvbox/runtime/ConstructorRepair.java", "tvbox/runtime/LazyDexArchive.java"]
    let vendored = try #require(manager.enumerator(atPath: java.appending(path: "com/googlecode").path))
    inputs += vendored.compactMap { $0 as? String }.filter { $0.hasSuffix(".java") }.map { "com/googlecode/" + $0 }
    var text = ""
    for path in inputs.sorted() {
        // Comments and the version itself don't change what the converter produces.
        let lines = try String(contentsOf: java.appending(path: path), encoding: .utf8).split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("//") && !$0.hasPrefix("/*") && !$0.hasPrefix("*") && !$0.contains("String VERSION = ") }
        text += path + "\n" + lines.joined(separator: "\n") + "\n"
    }
    let pom = try String(contentsOf: root.appending(path: "Runtime/JavaHost/pom.xml"), encoding: .utf8)
    text += pom.split(separator: "\n").filter { $0.contains("dex2jar") }.joined(separator: "\n")
    let hash = PluginChecksum.sha256(Data(text.utf8))
    let source = try String(contentsOf: java.appending(path: "tvbox/runtime/BytecodeCompatibility.java"), encoding: .utf8)
    let version = try #require(source.firstMatch(of: /String VERSION = "([^"]+)"/)?.1).description
    let file = root.appending(path: "Runtime/JavaHost/conversion-inputs.txt")
    let recorded = try String(contentsOf: file, encoding: .utf8).split(whereSeparator: \.isWhitespace).map(String.init)
    let expected = "\(version) \(hash)"
    if recorded.first == version {
        #expect(recorded.last == hash, "The DEX converter changed but BytecodeCompatibility.VERSION is still \(version). Bump VERSION so devices convert plugins again, then set Runtime/JavaHost/conversion-inputs.txt to: <new version> <hash this test prints>. If the change can't alter converted classes, keep the version and record: \(expected)")
    } else {
        Issue.record("Runtime/JavaHost/conversion-inputs.txt is for \(recorded.first ?? "nothing"). Set it to: \(expected)")
    }
}
