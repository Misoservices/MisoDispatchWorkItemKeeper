import XCTest

import MisoDispatchWorkItemKeeperTests

var tests = [XCTestCaseEntry]()
tests += BasicTests.allTests()
tests += ManualTests.allTests()
tests += StressTests.allTests()
XCTMain(tests)
