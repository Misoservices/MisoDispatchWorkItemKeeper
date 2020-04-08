import XCTest
@testable import MisoDispatchWorkItemKeeper

final class StressTests: XCTestCase {
    func testDelayed() {
        let requestCount = 2500
        let queue = DispatchQueue(
            label: "testDelayed exec",
            qos: .background
        )
        
        func stressRun(cancelAtStop: Bool, queueLabel: String) -> Int {
            var value = 0
            func exec() {
                let keeper = DispatchWorkItemKeeper(cancelAtStop: cancelAtStop, queueLabel: queueLabel)
                for _ in 0..<requestCount {
                    keeper.asyncAfter(in: queue, deadline: .now() + 0.1) {
                        value += 1
                    }
                }
            }
            exec()
            return value
        }
        XCTAssertEqual(stressRun(cancelAtStop: false,
                                 queueLabel: "testDelayed not cancelAtStop"),
                       requestCount, "Should run all \(requestCount) instances")
        XCTAssertLessThan(stressRun(cancelAtStop: true,
                                    queueLabel: "testDelayed cancelAtStop"),
                          requestCount, "Should not run all \(requestCount) instances")
    }
    
    func testImmediate() {
        let requestCount = 5000
        let queue = DispatchQueue(
            label: "testImmediate exec",
            qos: .background
        )
        
        func stressRun() -> Int {
            var value = 0
            func exec() {
                let keeper = DispatchWorkItemKeeper(cancelAtStop: false, queueLabel: "testImmediate")
                for _ in 0..<requestCount {
                    keeper.async(in: queue) {
                        value += 1
                    }
                }
            }
            exec()
            return value
        }
        XCTAssertEqual(stressRun(), requestCount, "Should run all \(requestCount) instances")
    }
    
    static var allTests = [
        ("Delayed async stress test", testDelayed),
        ("Immedate async stress test", testImmediate)
    ]
}
