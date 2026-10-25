# SwiftTopology

A Swift port of the JTS Topology Suite 1.20.0 that behaves bit for bit as GEOS 3.13 (as Apple clang builds it, with fused multiply-add). One library product and target, `Topology`, no dependencies, and one test target, `TopologyTests`. It was written inside ImmersiveMapEditor (github.com/artembobkin/ImmersiveMapEditor), which depends on it, and extracted from there at its commit `1d27d0f`. `README.md` is the overview for users, `Docs/PortingParity.md` the record of every comparison with GEOS, `Docs/PortingTopologyProgress.md` the record of how the port was made and its decisions.

## Layout

`Sources/Topology/`, by JTS's packages:

- `Geom`: coordinates, envelopes, precision models, the geometry classes, the factory, `Prep` (prepared geometries), `Util` (transformers, editors, extracters).
- `Math`: double-double arithmetic (`DD`), `Fused` (the fused multiply-adds clang makes in GEOS), Java's maths and random, `NonFinite` (GEOS's exception on non-finite points).
- `Algorithm`: orientation, segment intersection, point location (`Locate`), area, length, centroid, interior points, hulls, rectangles.
- `IO`: WKT and WKB, read and written.
- `Index`: STR tree, KD-tree, monotone chains, interval trees, and the translations of libc++ (`CxxAlgorithms`, `CxxPriorityQueue`, `CxxUnorderedMap`, `CxxTree`, under `LICENSE-LLVM`).
- `Noding`: segment strings, noders, `Snap`, `SnapRound`.
- `EdgeGraph`, `GeomGraph`, `Planargraph`: the graphs of OverlayNG, the buffer, and polygonize and line merge.
- `Operation`: `OverlayNG`, `Overlay` (the old polygon builder the buffer uses), `Union`, `RelateNG`, `Predicate`, `Distance`, `Buffer`, `Valid` (validity and make valid), `Polygonize`, `Linemerge`.
- `Precision`, `Simplify`, `Triangulate`, `Linearref`, `Util`.

`Tests/TopologyTests/`:

- `Parity/`: the seeded random suites against GEOS's stored answers, a file per area, with the generators (`RandomGeometries`, `InvalidGeometries`) and `ParityTally`.
- `JTSXML/`: the runner of the JTS XML suites (`JTSTestFile`, `JTSTestRunner`, `TopologyEngine`), `GEOSBaseline` (the tests GEOS 3.13 does not pass), JTS's `DiscreteHausdorffDistance` translated for the buffer matcher.
- `JTSUnit/`: JTS's own unit cases (snap rounding, KD-tree).
- `Recording/`: replays of recorded real calls (outside git, `TOPOLOGY_RECORDINGS`), skipped when absent, and the speed test.
- `Stored/`: the stored oracle (`StoredOracle`, `FrozenOracle`, the tape format in `Tape.swift`, `StoredGeometry`, `Shape`), `TestPaths`.
- `.oracle/`: GEOS's stored answers, a hidden folder (SwiftPM leaves it out of the target, the tests read it with `#filePath`).

`Tests/JTS/testxml/`: the JTS 1.20.0 XML suites (general, validate, robust, misc), unchanged, outside the test target's folder so `Package.swift` declares no resources.

## Rules

- **Behaviour must match GEOS 3.13 bit for bit.** Every coordinate (the sign of zeros included), every number by its bits, every answer, order of parts and points, and every failure. A change that alters any result is a bug, however small, unless GEOS gives that result too.
- **Never loosen a tolerance or a comparison** to make a test pass. The parity tests have no tolerance, and must keep none. A test that fails shows a difference to find and fix in the port.
- **The stored answers cannot be regenerated.** GEOS left the project (phase 12): the tapes in `Tests/TopologyTests/.oracle/` were written by the tests asking GEOS itself, and are the only oracle. Never delete, rewrite or "update" a tape. A test that asks GEOS anything it did not ask then fails its alignment digest. New behaviour can be tested only against JTS's own expectations or the existing tapes.
- **The port is JTS's code, changed where GEOS differs.** Keep JTS's names, structure and order of operations, so the port reads side by side with JTS. Each place that follows GEOS instead is documented in `Docs/PortingParity.md` ("Where GEOS 3.13 differs from JTS 1.20"). GEOS's sources may be read to understand a difference, never translated (GEOS is LGPL). `MakeValid` and `BuildArea` were written from the algorithm, not from GEOS's code: keep it so.
- **Arithmetic is part of the behaviour.** Keep the fused multiply-adds (`Fused.swift`, `addingProduct`) where clang fuses GEOS's expressions, `sqrt(dx * dx + dy * dy)` where GEOS has it (not `hypot`), libc++'s sorts and container orders where GEOS's results depend on them.
- **Speed work changes no result.** Run the full suite before and after, in debug and release. The optimizations already made are listed in `Docs/PortingParity.md` ("Speed after the second optimization pass").

## How parity is tested

```sh
swift test                                          # debug
swift test -c release -Xswiftc -enable-testing      # optimized: arcs take other last bits, `.release` tapes
swift build && swift build -c release               # no warnings in either
```

Both must pass with no warnings. Each parity test asks its questions of a `StoredOracle` and compares the port's answers with GEOS's: a geometry is equal when it is GEOS's as it came, or GEOS's in normal form. The JTS XML suites check that the port passes exactly the tests GEOS passed (`GEOSBaseline`) and that every result is GEOS's. With recordings (`TOPOLOGY_RECORDINGS=<folder>`, `TOPOLOGY_LONG_REPLAY=1`, a release build), every recorded real call is replayed against GEOS's stored answers too. `PARITY_DUMP=<file>` writes every difference in full.

## Conventions

- English in every file: code, comments, test messages, documentation.
- No em dash (U+2014) and no semicolon joining two clauses in prose. Write two sentences or use a comma, a colon or parentheses.
- Swift naming in new code, JTS's names in ported code (`getEnvelopeInternal`, `getNumPoints`), so the port reads side by side with JTS.
- Doc comments say what a type or function is and, where it follows GEOS rather than JTS, how and why.
- No hard-coded user paths. Data outside git is named by environment variables (`JTS_ROOT`, `TOPOLOGY_RECORDINGS`).
