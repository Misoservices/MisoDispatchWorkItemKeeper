import XCTest
@testable import MisoDispatchWorkItemKeeper

final class BasicTests: XCTestCase {
    func testKeep() {
        var value = 0
        func exec() {
            let queue = DispatchQueue(
                label: "testKeep exec",
                qos: .background
            )
            let keeper = DispatchWorkItemKeeper(cancelAtStop: false, queueLabel: "testKeep")
            queue.async(execute: keeper.keep(DispatchWorkItem {
                value += 1
            }))

            // Coverage: should not execute
            keeper.stop()
            queue.async(execute: keeper.keep(DispatchWorkItem {
                value += 1
            }))
        }
        exec()
        XCTAssertEqual(value, 1, "Work Item should be executed")
    }

    func testAsync() {
        var value = 0
        func exec() {
            let queue = DispatchQueue(
                label: "testAsync exec",
                qos: .background
            )
            let keeper = DispatchWorkItemKeeper(cancelAtStop: false, queueLabel: "testAsync")
            keeper.async(in: queue) {
                value += 1
            }

            // Coverage: should not execute
            keeper.stop()
            keeper.async(in: queue) {
                value += 1
            }
        }
        exec()
        XCTAssertEqual(value, 1, "Work Item should be executed")
    }

    func testAsyncAfter() {
        var value = 0
        func exec() {
            let queue = DispatchQueue(
                label: "testAsyncAfter exec",
                qos: .background
            )
            let keeper = DispatchWorkItemKeeper(cancelAtStop: false, queueLabel: "testAsyncAfter")
            keeper.asyncAfter(in: queue, deadline: .now() + 0.01) {
                value += 1
            }
            keeper.asyncAfter(in: queue, wallDeadline: .now() + 0.01) {
                value += 1
            }

            // Coverage: should not execute
            keeper.stop()
            keeper.asyncAfter(in: queue, deadline: .now() + 0.01) {
                value += 1
            }
            keeper.asyncAfter(in: queue, wallDeadline: .now() + 0.01) {
                value += 1
            }
        }
        exec()
        XCTAssertEqual(value, 2, "Work Items should be executed")
    }

    func testRunModes() {
        XCTAssertTrue(DispatchWorkItemKeeper().isRunning, "Should start the keeper by default")
        XCTAssertFalse(DispatchWorkItemKeeper(.manual).isRunning,
                       "If requesting manual operation, should not start the keeper on instantiation")
    }

    func testCancelAtStop() {
        let queue = DispatchQueue(
            label: "testCancelAtStop exec",
            qos: .background
        )

        func simpleRun(cancelAtStop: Bool, queueLabel: String) -> Int {
            var value = 0
            func exec() {
                let keeper = DispatchWorkItemKeeper(cancelAtStop: cancelAtStop, queueLabel: queueLabel)
                keeper.asyncAfter(in: queue, deadline: .now() + 0.1) {
                    value += 1
                }
            }
            exec()
            return value
        }
        XCTAssertEqual(simpleRun(cancelAtStop: true,
                                 queueLabel: "cancelAtStop"), 0, "Should cancel before quitting destructor")
        XCTAssertEqual(simpleRun(cancelAtStop: false,
                                 queueLabel: "not cancelAtStop"),
                       1, "Should wait for execution before quitting destructor")
    }

    func testCancelPending() {
        let queue = DispatchQueue(
            label: "testCancelPending exec",
            qos: .background
        )

        func simpleRun(count: Int, cancelAfter: Int, queueLabel: String) -> Int {
            var value = 0
            func exec() {
                let keeper = DispatchWorkItemKeeper(cancelAtStop: false, queueLabel: queueLabel)
                for cur in 0..<count {
                    keeper.asyncAfter(in: queue, deadline: .now() + 0.1) {
                        value += 1
                    }
                    if cur == cancelAfter {
                        keeper.cancelPending()
                    }
                }
            }
            exec()
            return value
        }
        XCTAssertEqual(simpleRun(count: 1, cancelAfter: 0,
                                 queueLabel: "testCancelPending Unique"), 0, "Should cancel everything")
        XCTAssertEqual(simpleRun(count: 2, cancelAfter: 0,
                                 queueLabel: "testCancelPending StopAfterOne"), 1, "Should cancel after the first one")
        XCTAssertEqual(simpleRun(count: 3, cancelAfter: 1,
                                 queueLabel: "testCancelPending OnlyMiddle"), 1, "Should cancel after the second one")
        XCTAssertEqual(simpleRun(count: 12, cancelAfter: 10,
                                 queueLabel: "testCancelPending TenMiddle"), 1, "Should cancel after the first 11")
    }

    func testAutoClean() {
        let queue = DispatchQueue(
            label: "testAutoClean exec",
            qos: .background
        )

        func simpleRun(autoCleanCount: Int, queueLabel: String) -> Int {
            let keeper = DispatchWorkItemKeeper(autoCleanCount: autoCleanCount, queueLabel: queueLabel)
            for _ in 0..<25 {
                keeper.async(in: queue) {
                    // nop. Only wait to be in a state where keeper has processed its addition
                }
                queue.sync {
                    // nop. Only wait for the execution queue to be empty
                }
                _ = keeper.workItemsCount
            }
            return keeper.workItemsCount
        }
        XCTAssertLessThanOrEqual(simpleRun(autoCleanCount: 1,
                                           queueLabel: "testAutoClean 1"), 1, "Should only have one item at all times")
        XCTAssertLessThanOrEqual(simpleRun(autoCleanCount: 9,
                                           queueLabel: "testAutoClean 9"), 6, "Should have cleaned up 2x10, leaving 5")
        XCTAssertLessThanOrEqual(simpleRun(autoCleanCount: 19,
                                           queueLabel: "testAutoClean 19"), 6, "Should have cleaned up 2x10, leaving 5")
        XCTAssertEqual(simpleRun(autoCleanCount: 30,
                                 queueLabel: "testAutoClean 30"), 25, "Should have never cleaned up")
    }

    func testClean() {
        let queue = DispatchQueue(
            label: "testClean exec",
            qos: .background
        )

        func simpleRun(cleanCount: Int, queueLabel: String) -> Int {
            let keeper = DispatchWorkItemKeeper(autoCleanCount: 9999, queueLabel: queueLabel)
            for cur in 0..<25 {
                keeper.async(in: queue) {
                    // nop. Only wait to be in a state where keeper has processed its addition
                }
                queue.sync {
                    // nop. Only wait for the execution queue to be empty
                }
                _ = keeper.workItemsCount
                if cur+1 == cleanCount {
                    keeper.clean()
                }
            }
            return keeper.workItemsCount
        }
        XCTAssertLessThanOrEqual(simpleRun(cleanCount: 1,
                                           queueLabel: "testClean 1"),
                                 24, "Should have cleaned after 1 item, leaving 24")
        XCTAssertLessThanOrEqual(simpleRun(cleanCount: 10,
                                           queueLabel: "testClean 10"),
                                 15, "Should have cleaned after 10 items, leaving 15")
        XCTAssertLessThanOrEqual(simpleRun(cleanCount: 20,
                                           queueLabel: "testClean 20"),
                                 5, "Should have cleaned after 20 items, leaving 5")
        XCTAssertEqual(simpleRun(cleanCount: 30,
                                 queueLabel: "testClean 30"), 25, "Should have never cleaned up")
    }

    static var allTests = [
        (".keep()", testKeep),
        (".async()", testAsync),
        (".asyncAfter()", testAsyncAfter),
        ("Run Modes", testRunModes),
        (".cancelPending()", testCancelPending),
        ("AutoClean", testAutoClean),
        ("Clean", testClean)
    ]
}
