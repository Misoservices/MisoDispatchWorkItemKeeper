import XCTest
@testable import MisoDispatchWorkItemKeeper

final class ManualTests: XCTestCase {
    func testManual() {
        let queue = DispatchQueue(
            label: "testManual exec",
            qos: .background
        )

        func simpleRun(count: Int, startBefore: Int, stopAfter: Int, queueLabel: String) -> Int {
            var value = 0
            func exec() {
                let keeper = DispatchWorkItemKeeper(.manual, cancelAtStop: false, queueLabel: queueLabel)
                for cur in 0..<count {
                    if cur == startBefore {
                        keeper.start()
                    }
                    keeper.asyncAfter(in: queue, deadline: .now() + 0.1) {
                        value += 1
                    }
                    if cur == stopAfter {
                        keeper.stop()
                    }
                }
            }
            exec()
            return value
        }
        XCTAssertEqual(simpleRun(count: 1, startBefore: 0, stopAfter: -1,
                                 queueLabel: "testManual Unique"), 1, "Should start as usual")
        XCTAssertEqual(simpleRun(count: 2, startBefore: 0, stopAfter: 0,
                                 queueLabel: "testManual StopAfterOne"), 1, "Should not start the second one")
        XCTAssertEqual(simpleRun(count: 2, startBefore: 1, stopAfter: -1,
                                 queueLabel: "testManual RunAfterOne"), 1, "Should not start the first one")
        XCTAssertEqual(simpleRun(count: 3, startBefore: 1, stopAfter: 1,
                                 queueLabel: "testManual OnlyMiddle"), 1, "Should only start the middle one")
        XCTAssertEqual(simpleRun(count: 12, startBefore: 1, stopAfter: 10,
                                 queueLabel: "testManual TenMiddle"), 10, "Should skip the first and last one")
    }

    func testManualRestart() {
        let queue = DispatchQueue(
            label: "testManualRestart exec",
            qos: .background
        )

        func simpleRun(count: Int, startBefore: Int, restartAfter: Int, cancel: Bool, queueLabel: String) -> Int {
            var value = 0
            func exec() {
                let keeper = DispatchWorkItemKeeper(.manual, cancelAtStop: false, queueLabel: queueLabel)
                for cur in 0..<count {
                    if cur == startBefore {
                        keeper.start()
                    }
                    keeper.asyncAfter(in: queue, deadline: .now() + 0.1) {
                        value += 1
                    }
                    if cur == restartAfter {
                        keeper.stop(cancel: cancel)
                        keeper.start()
                    }
                }
            }
            exec()
            return value
        }
        XCTAssertEqual(simpleRun(count: 2, startBefore: 0, restartAfter: 0, cancel: true,
                                 queueLabel: "testManualRestart Cancel StopAfterOne"),
                       1, "Should cancel first and only start the second one")
        XCTAssertEqual(simpleRun(count: 3, startBefore: 1, restartAfter: 1, cancel: true,
                                 queueLabel: "testManualRestart Cancel OnlyMiddle"),
                       1, "Should cancel the middle one and only start the 3rd one")
        XCTAssertEqual(simpleRun(count: 12, startBefore: 1, restartAfter: 10, cancel: true,
                                 queueLabel: "testManualRestart Cancel TenMiddle"),
                       1, "Should skip the first, cancel the middle ones and only start and last one")

        XCTAssertEqual(simpleRun(count: 2, startBefore: 0, restartAfter: 0, cancel: false,
                                 queueLabel: "testManualRestart StopAfterOne"),
                       2, "Should not cancel the first and do the second one")
        XCTAssertEqual(simpleRun(count: 3, startBefore: 1, restartAfter: 1, cancel: false,
                                 queueLabel: "testManualRestart OnlyMiddle"),
                       2, "Should not cancel the middle one and do the 3rd one")
        XCTAssertEqual(simpleRun(count: 12, startBefore: 1, restartAfter: 10, cancel: false,
                                 queueLabel: "testManualRestart TenMiddle"),
                       11, "Should skip the first, not cancel the middle ones and do the last one")
    }

    func testManualCount() {
        let queue = DispatchQueue(
            label: "testManualCount exec",
            qos: .background
        )

        func simpleRun(count: Int, startBefore: Int, ignoredRestartAfter: Int, queueLabel: String) -> Int {
            var value = 0
            func exec() {
                let keeper = DispatchWorkItemKeeper(.manual, cancelAtStop: false, queueLabel: queueLabel)
                for cur in 0..<count {
                    if cur == startBefore {
                        keeper.start()
                    }
                    keeper.asyncAfter(in: queue, deadline: .now() + 0.1) {
                        value += 1
                    }
                    if cur == ignoredRestartAfter {
                        // Count should increment, then decrement, meaning it should do nothing
                        keeper.start()
                        keeper.stop(cancel: true)
                    }
                }
            }
            exec()
            return value
        }
        XCTAssertEqual(simpleRun(count: 2, startBefore: 0, ignoredRestartAfter: 0,
                                 queueLabel: "testManualCount StopAfterOne"),
                       2, "Should ignore the cancelling restart after first one")
        XCTAssertEqual(simpleRun(count: 3, startBefore: 1, ignoredRestartAfter: 1,
                                 queueLabel: "testManualCount OnlyMiddle"),
                       2, "Should ignore the cancelling restart after second one")
        XCTAssertEqual(simpleRun(count: 12, startBefore: 1, ignoredRestartAfter: 10,
                                 queueLabel: "testManualCount TenMiddle"),
                       11, "Should ignore the cancelling restart at the end")
    }

    static var allTests = [
        ("Manual Mode", testManual),
        ("Manual Restart", testManualRestart),
        ("Manual Count", testManualCount)
    ]
}
