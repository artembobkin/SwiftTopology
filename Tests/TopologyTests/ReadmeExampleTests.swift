import Testing
import Topology

/// The usage example of README.md, kept compiling and true.
@Suite struct ReadmeExampleTests {
    @Test func theExampleRuns() throws {
        // README.md, "Usage", from here.
        let reader = WKTReader()
        let a = try reader.read("POLYGON ((0 0, 10 0, 10 10, 0 10, 0 0))")
        let b = try reader.read("POLYGON ((5 5, 15 5, 15 15, 5 15, 5 5))")

        let overlap = try a.intersection(b)
        let area = overlap.getArea()                  // 25.0
        let touching = try a.intersects(b)            // true
        let merged = try a.union(b)
        let text = WKTWriter().write(merged)          // POLYGON ((10 0, 0 0, 0 10, 5 10, ...))
        let rounded = try a.buffer(1, quadSegs: 8)    // round caps and joins
        let valid = try rounded.isValid()             // true
        // To here.

        #expect(area == 25)
        #expect(touching)
        #expect(text == "POLYGON ((10 0, 0 0, 0 10, 5 10, 5 15, 15 15, 15 5, 10 5, 10 0))")
        #expect(merged.getArea() == 175)
        #expect(valid)
        #expect(rounded.getArea() > 100 + 40)
    }
}
