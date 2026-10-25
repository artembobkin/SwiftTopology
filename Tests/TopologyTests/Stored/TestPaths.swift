import Foundation

/// Where the parity tests find their data: the JTS 1.20.0 XML test suites
/// (in git, `Tests/JTS/testxml`), the stored GEOS answers (in git, `.oracle`)
/// and the recorded calls of real data (outside git, `TOPOLOGY_RECORDINGS`).
enum TestPaths {
    /// The package folder, from this file's place in it.
    static let package = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()

    /// The folder of the JTS XML suites: the `testxml` folder of a JTS 1.20.0
    /// clone named by `JTS_ROOT`, else the copy in git (`Tests/JTS/testxml`).
    static let testxml: URL? = {
        let dir: URL
        if let root = ProcessInfo.processInfo.environment["JTS_ROOT"] {
            dir = URL(fileURLWithPath: root).appendingPathComponent("modules/tests/src/test/resources/testxml")
        } else {
            dir = package.appendingPathComponent("Tests/JTS/testxml")
        }
        return FileManager.default.fileExists(atPath: dir.path) ? dir : nil
    }()

    /// The JTS XML suites the parity covers, in this order.
    static let suites = ["general", "validate", "robust", "misc"]

    /// The XML files of a suite, with its subfolders, sorted by path.
    static func xmlFiles(_ suite: String) -> [URL] {
        guard let testxml else { return [] }
        let dir = testxml.appendingPathComponent(suite)
        let files = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil)?.compactMap { $0 as? URL } ?? []
        return files.filter { $0.pathExtension == "xml" }.sorted { $0.path < $1.path }
    }

    /// A file's name relative to the testxml folder (`general/TestBoundary.xml`).
    static func name(_ url: URL) -> String {
        let parts = url.standardizedFileURL.pathComponents
        guard let i = parts.lastIndex(of: "testxml") else { return url.lastPathComponent }
        return parts[(i + 1)...].joined(separator: "/")
    }

    /// The recorded calls of real data (Docs/PortingTopologyProgress.md,
    /// "Recordings"): the folder named by `TOPOLOGY_RECORDINGS`, else none,
    /// and the replays skip.
    static let recording: URL? = ProcessInfo.processInfo.environment["TOPOLOGY_RECORDINGS"].map { URL(fileURLWithPath: $0) }
}

extension TestPaths {
    /// The stored GEOS answers in git (`StoredOracle`): `.oracle` beside these
    /// sources, a hidden folder, which SwiftPM leaves out of the target.
    static let fixtures = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent(".oracle")

    /// The stored GEOS answers of the recorded calls, outside git beside the
    /// recordings: `expected/<recording>/` under the folder of recordings.
    static var expected: URL? { recording?.appendingPathComponent("expected") }
}
