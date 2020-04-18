import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(BasicTests.allTests),
        testCase(ManualTests.allTests),
        testCase(StressTests.allTests)
    ]
}
#endif
