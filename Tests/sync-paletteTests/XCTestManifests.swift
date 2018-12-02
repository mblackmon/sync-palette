import XCTest

#if !os(macOS)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(sync_paletteTests.allTests),
    ]
}
#endif