//
//  DispatchWorkItemKeeperProtocol.swift
//  MisoDispatchWorkItemKeeper
//
//  Created by Michel Donais on 2020-04-08.
//  Copyright © 2020 Misoservices Inc. All rights reserved.
//  [BSL-1.0] This package is Licensed under the Boost Software License - Version 1.0
//

import Foundation
import Dispatch

public protocol DispatchWorkItemKeeperProtocol {
    ///
    /// Determine whether we are currently running or not
    ///
    var isRunning: Bool { get }
    
    ///
    /// Returns the size of the current `DispatchWorkItem` array.
    ///
    /// - note: This value is mostly for testing the cleaning operations and profiling, as this value has no
    /// reflection to reality.
    /// - warning: This operation is blocking for better accuracy
    ///
    var workItemsCount: Int { get }
    
    ///
    /// Starts the keeper. This is done automatically when the `RunMode` is set to `.automatic`.
    ///
    /// - note: This operation is counted, you must do the same quantity of `stop()` than `start()` to stop the keeper.
    ///
    func start()
    
    ///
    /// Stops the keeper. This is done automatically when the `DispatchWorkItemKeeper` gets deleted.
    ///
    /// Depending on the `cancelAtStop` preference, the pending operations might get cancelled, and never get executed.
    /// This cancellation is there by default, as if your caller actually disappears, it is thought you do not wish
    /// for the operation to complete. That might lead to leaks, freezes or other unforeseen consequences if you were
    /// actually expecting a result.
    ///
    /// In this case, it's recommended you ask for the system to finalize its operations first, instead of
    /// cancelling them.
    ///
    /// - warning: The `stop()` operation will wait for the current tasks to be done. It will never "kill" a task.
    /// Thus, if you have acvery lengthy operation in progress, you might stall here, and potentially break
    /// system-mandated contracts to terminate in a short delay.
    ///
    /// - note: This operation is counted, you must do the same quantity of `stop()` than `start()` to stop the keeper.
    ///
    /// - Parameters:
    ///  - cancel: Override for cancellation
    ///
    func stop(cancel: Bool?)
    
    ///
    /// Safeguards a new `DispatchWorkItem` in case our calling object gets deleted.
    /// - Parameters:
    ///  - workItem: The `DispatchWorkItem` to track
    /// - Returns: The same `workItem` to make dispatching easier
    ///
    @discardableResult
    func keep(_ workItem: DispatchWorkItem) -> DispatchWorkItem
    
    ///
    /// Submits a work item for asynchronous execution on a dispatch queue and safeguards it in case our calling
    /// object gets deleted. Will be executed after a specified delay.
    /// - Parameters:
    ///   - queue: The queue that will execute the block
    ///   - block: The work item to be invoked on the queue
    /// - Returns: The generated `workItem`, in case you need it. Might be `nil` if the keeper is stopped.
    ///
    @discardableResult
    func async(in queue: DispatchQueue,
               block: @escaping ()->Void) -> DispatchWorkItem?
    
    ///
    /// Submits a work item for asynchronous execution on a dispatch queue and safeguards it in case our calling
    /// object gets deleted. Will be executed after a specified delay.
    /// - Parameters:
    ///   - queue: The queue that will execute the block
    ///   - block: The work item to be invoked on the queue
    ///   - deadline: The time after which the work item should be executed, given as a `DispatchTime`
    /// - Returns: The generated `workItem`, in case you need it. Might be `nil` if the keeper is stopped.
    ///
    @discardableResult
    func asyncAfter(in queue: DispatchQueue,
                    deadline: DispatchTime,
                    block: @escaping ()->Void) -> DispatchWorkItem?
    
    ///
    /// Submits a work item for asynchronous execution on a dispatch queue and safeguards it in case our calling
    /// object gets deleted. Will be executed after a specified delay.
    /// - Parameters:
    ///   - queue: The queue that will execute the block
    ///   - block: The work item to be invoked on the queue
    ///   - wallDeadline: The time after which the work item should be executed, given as a `DispatchWallTime`
    /// - Returns: The generated `workItem`, in case you need it. Might be `nil` if the keeper is stopped.
    ///
    @discardableResult
    func asyncAfter(in queue: DispatchQueue,
                    wallDeadline: DispatchWallTime,
                    block: @escaping ()->Void) -> DispatchWorkItem?
    
    ///
    /// Immediately cancels all the pending operations. An operation that is currently being run will not be affected.
    ///
    func cancelPending()
    
    ///
    /// Schedule a clean-up of the processed and cancelled operations
    ///
    func clean()
}

public extension DispatchWorkItemKeeperProtocol {
    func stop() {
        self.stop(cancel: nil)
    }
}
