# SwiftTopology

A Swift port of the JTS Topology Suite 1.20.0 that behaves bit for bit as GEOS 3.13: planar geometry with robust predicates, overlay, buffer, validity, make valid and the rest, in pure Swift, with no dependencies.

The port keeps JTS's code and names, and changes them only where GEOS 3.13 (the C++ port of JTS) computes otherwise, so its results are GEOS's, every coordinate bit for bit. It was written to replace GEOS in [ImmersiveMapEditor](https://github.com/artembobkin/ImmersiveMapEditor), a tile pipeline that turns OpenStreetMap into 3D models, and was proven against GEOS there on more than two million real calls before GEOS was removed.

This project is not affiliated with or endorsed by LocationTech, the JTS project or the GEOS project.

## Installation

Swift Package Manager, Swift 6 toolchain:

```swift
dependencies: [
    .package(url: "https://github.com/artembobkin/SwiftTopology.git", from: "0.1.0"),
],
targets: [
    .target(name: "MyTarget", dependencies: [.product(name: "Topology", package: "SwiftTopology")]),
]
```

Platforms: macOS 15 and iOS 18 (the library imports only `Foundation` and `Darwin`). The tests run on macOS.

## Usage

```swift
import Topology

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
```

The example is a test (`Tests/TopologyTests/ReadmeExampleTests.swift`), so it keeps compiling.

How the API reads:

- **JTS's names**: `getArea()`, `getEnvelopeInternal()`, `getNumPoints()`, `GeometryFactory`, `PrecisionModel`, `STRtree`, `PreparedGeometryFactory`, so code and documentation of JTS carry over.
- **Two dimensions.** A `Coordinate` is x and y. The readers drop Z and M.
- **Geometries are classes**, as in JTS (`normalize()` changes one in place). Envelopes, segments and intersectors are values.
- **Errors are thrown** where GEOS's C API fails (a topology failure of an overlay, a non-finite coordinate in an orientation test, invalid WKT). Programming errors trap, as JTS's assertions do.

## What is ported

The parts of JTS 1.20.0 that the operations below need, by JTS's packages (`Sources/Topology/`):

- **Geometry model** (`Geom`): coordinates, envelopes, precision models (with GEOS's rounding), points, lines, rings, polygons and their collections, the factory, prepared geometries, the intersection matrix.
- **Algorithms** (`Algorithm`, `Math`): orientation with double-double arithmetic, robust segment intersection, point location (simple and indexed), area, length, centroid, interior point, convex hull, boundary, minimum area rectangle, minimum diameter.
- **Input and output** (`IO`): WKT reading and writing (with GEOS's rounding precision), WKB reading and writing.
- **Indexes** (`Index`): STR tree (query, nearest neighbour), KD-tree, monotone chains, interval trees, and libc++'s `std::sort`, heap, hash table and red-black tree orders, which GEOS's results depend on.
- **Noding** (`Noding`): MC index noder, iterated noder, scaled noder, snapping noder, snap rounding.
- **Overlay** (`Operation/OverlayNG`, `Operation/Union`): OverlayNG with GEOS's robust fallbacks, intersection, union, difference, symmetric difference, unary union, at floating or fixed precision.
- **Predicates** (`Operation/RelateNG`, `Operation/Predicate`): RelateNG for every named predicate and `relate`, as GEOS 3.13 dispatches them, with the fast paths of rectangles and prepared geometries.
- **Distance** (`Operation/Distance`): distance, nearest points, within a distance.
- **Buffer** (`Operation/Buffer`, `GeomGraph`): buffer with every cap and join style, offset curve.
- **Validity and repair** (`Operation/Valid`, `Precision`): `isValid` with GEOS's reasons and locations, `makeValid` (GEOS's default linework method), `setPrecision` (GEOS's `GEOSGeom_setPrecision`).
- **Simplify** (`Simplify`): topology preserving simplification.
- **Lines and areas** (`Operation/Polygonize`, `Operation/Linemerge`, `Planargraph`): polygonize, line merge.
- **Triangulation** (`Triangulate`): constrained Delaunay triangulation of polygons.
- **Linear referencing** (`Linearref`): interpolate (also normalized), project.

Not ported: single-sided buffers, the variable buffer, `MCIndexSnapRounder`, `IsSimpleOp`, `GeometryFixer`, `LineSequencer`, and the rest of JTS that none of the operations above reaches.

## Parity with GEOS

The bar was one to one, with no tolerance anywhere: geometries compared in GEOS's normal form and as they come (the order of parts, rings and points included), every coordinate bit for bit (the sign of zeros included), numbers by their bits, answers and text exactly, and where GEOS fails the port must fail.

The GEOS compared with is GEOS 3.13.0 built by Apple clang on Apple silicon, as the `GEOSwift/geos` 9.0.0 package builds it. Clang's default `-ffp-contract=on` fuses `a * b + c` inside one expression into one fused multiply-add, which JTS on the JVM never does. The port makes the same fusions explicitly (`Math/Fused.swift`), so it gives the same bits on every platform, and those are the bits of GEOS built that way.

| Compared | On | Result |
|---|---|---|
| Every ported operation and the machinery under it | seeded random and near-degenerate inputs (often invalid ones, NaN and infinite coordinates, grids), 2,000 to 200,000 per function | all equal |
| The JTS 1.20.0 XML suites (general, validate, robust, misc) | 10,398 tests | the port passes exactly the tests GEOS passes, its 10,297 results of the operations it has are GEOS's, and it reads all 7,359 inputs as GEOS |
| Every call of a real workload (ImmersiveMapEditor's tile pipeline: five map tiles of central Moscow and a road seeding) | 2,216,536 calls, 757,210 geometries | all equal |

Where GEOS 3.13 differs from JTS 1.20 the port follows GEOS, and each such change is listed with its reason in `Docs/PortingParity.md`: fused multiply-add, libc++'s orders of sorts, heaps and hash tables, RelateNG for every predicate, GEOS's precision rounding, retries and fast paths, GEOS's handling of non-finite coordinates. So on the JTS XML suites the port fails exactly the 74 tests GEOS fails.

Accepted differences:

- **The sign of a zero after snap rounding.** GEOS shuffles the vertices it snap-rounds with `std::random_device`, so at a fixed precision its own results change the sign of a zero from run to run. A result equal to GEOS's but for that sign is accepted where GEOS itself was seen to vary (27 random inputs, none of the real calls).
- **Inputs GEOS crashes on** are not compared: `GEOSNode` of a collection with an empty member, the triangulation of invalid polygons, the polygonizer and the minimum rectangle of non-finite input.
- **Last bits of arcs between builds.** The buffer's arcs take `sin` and `cos` from the system, and an optimized build gives other last bits than a debug build, for GEOS and the port alike. Both were equal in each build, and GEOS's answers are stored for both.

GEOS's answers are stored in `Tests/TopologyTests/.oracle/` (75 compressed tapes, 4.8 MB), so the tests prove parity without GEOS. They were written by the same tests asking GEOS itself, before GEOS was removed, and cannot be made again.

## Make valid

GEOS 3.13's default `GEOSMakeValid` (the "linework" method) is GEOS's own code, ported to GEOS from rttopo and PostGIS under the LGPL. JTS 1.20 has no equivalent. The port's `MakeValid` and `BuildArea` were written anew from the algorithm as GEOS documents and runs it, on the port's own JTS operations and in GEOS's order of operations. They are not a translation of GEOS's code. They give GEOS's results on every comparison: 12,000 random and often invalid inputs and 32,248 real calls.

## Speed

Every call of one whole tile of the real workload (545,244 calls), each timed alone, in optimized builds of both: the port takes 1.48 times GEOS's time (12.4 s against 8.4 s). Area and simplify are faster than GEOS, the unary union is the slowest (1.56 times). The tile pipeline built whole tiles in 1.06 to 1.29 times its time on GEOS. Details in `Docs/PortingParity.md`.

## Tests

```sh
swift test                                          # debug, about 2 minutes
swift test -c release -Xswiftc -enable-testing      # optimized, a few seconds
```

Both run 86 tests: the random parity suites against the stored GEOS answers, the JTS XML suites, JTS's unit cases of snap rounding and the KD-tree, and the example above. The tests that replay recorded real calls skip, as the recordings are not public (100 MB with their stored answers).

Environment variables:

- `JTS_ROOT`: a clone of JTS 1.20.0 to read the XML suites from, instead of the copy in `Tests/JTS/testxml/`.
- `TOPOLOGY_RECORDINGS`: a folder of recordings (`*.rec`, with GEOS's answers in its `expected/`), to run the replays of recorded calls. `TOPOLOGY_LONG_REPLAY=1` runs the long ones too (overlays, predicates, buffer: use a release build), `TOPOLOGY_SPEED=1` times a whole recording against GEOS's stored times.
- `PARITY_DUMP`: a file where the parity tests write every difference in full.

`Docs/PortingParity.md` is the full record of what was compared, and `Docs/PortingTopologyProgress.md` the record of how the port was made, phase by phase, with its decisions.

## Licence

- **The port and its tests** are under the Eclipse Distribution License 1.0 (BSD-3-Clause), as the JTS Topology Suite they are translated from: `LICENSE`.
- **The translations of libc++'s algorithms** (`Sources/Topology/Index/CxxAlgorithms.swift`, `CxxPriorityQueue.swift`, `CxxUnorderedMap.swift`, `CxxTree.swift`), which reproduce the orders GEOS 3.13 keeps, are under the Apache License 2.0 with LLVM Exceptions: `LICENSE-LLVM`.
- **The JTS XML test suites** in `Tests/JTS/testxml/` are JTS's own, unchanged, used under the EDL 1.0 (`Tests/JTS/LICENSE_EDLv1.txt`).

Make valid was written for this port, and no GEOS code (LGPL) was translated.
