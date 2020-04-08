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
        XCTAssertFalse(DispatchWorkItemKeeper(.manual).isRunning, "If requesting manual operation, should not start the keeper on instantiation")
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
                                 queueLabel: "not cancelAtStop"), 1, "Should wait for execution before quitting destructor")
    }
    
    func testManual() {
        let queue = DispatchQueue(
            label: "testManual exec",
            qos: .background
        )
        
        func simpleRun(count: Int, startBefore: Int, stopAfter: Int, queueLabel: String) -> Int {
            var value = 0
            func exec() {
                let keeper = DispatchWorkItemKeeper(.manual, cancelAtStop: false, queueLabel: queueLabel)
                for i in 0..<count {
                    if i == startBefore {
                        keeper.start()
                    }
                    keeper.asyncAfter(in: queue, deadline: .now() + 0.1) {
                        value += 1
                    }
                    if i == stopAfter {
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
                for i in 0..<count {
                    if i == startBefore {
                        keeper.start()
                    }
                    keeper.asyncAfter(in: queue, deadline: .now() + 0.1) {
                        value += 1
                    }
                    if i == restartAfter {
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
                for i in 0..<count {
                    if i == startBefore {
                        keeper.start()
                    }
                    keeper.asyncAfter(in: queue, deadline: .now() + 0.1) {
                        value += 1
                    }
                    if i == ignoredRestartAfter {
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
                                 queueLabel: "testManualCount StopAfterOne"), 2, "Should ignore the cancelling restart")
        XCTAssertEqual(simpleRun(count: 3, startBefore: 1, ignoredRestartAfter: 1,
                                 queueLabel: "testManualCount OnlyMiddle"), 2, "Should ignore the cancelling restart")
        XCTAssertEqual(simpleRun(count: 12, startBefore: 1, ignoredRestartAfter: 10,
                                 queueLabel: "testManualCount TenMiddle"), 11, "Should ignore the cancelling restart")
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
                for i in 0..<count {
                    keeper.asyncAfter(in: queue, deadline: .now() + 0.1) {
                        value += 1
                    }
                    if i == cancelAfter {
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
                keeper.async(in: queue) {}
                queue.sync {}
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
            for i in 0..<25 {
                keeper.async(in: queue) {}
                queue.sync {}
                _ = keeper.workItemsCount
                if i+1 == cleanCount {
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
        ("Manual Mode", testManual),
        ("Manual Restart", testManualRestart),
        ("Manual Count", testManualCount),
        (".cancelPending()", testCancelPending),
        ("AutoClean", testAutoClean),
        ("Clean", testClean),
    ]
}
