//
//  DispatchWorkItemKeeper.swift
//  MisoDispatchWorkItemKeeper
//
//  Created by Michel Donais on 2020-02-26.
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
    /// - note: This value is mostly for testing the cleaning operations and profiling, as this value has no reflection to reality.
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
    /// This cancellation is there by default, as if your caller actually disappears, it is thought you do not wish for the operation to
    /// complete. That might lead to leaks, freezes or other unforeseen consequences if you were actually expecting a result.
    /// In this case, it's recommended you ask for the system to finalize its operations first, instead of cancelling them.
    ///
    /// - warning: The `stop()` operation will wait for the current tasks to be done. It will never "kill" a task. Thus, if you have a
    /// very lengthy operation in progress, you might stall here, and potentially break system-mandated contracts to terminate in
    /// a short delay.
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
    /// Submits a work item for asynchronous execution on a dispatch queue and safeguards it
    /// in case our calling object gets deleted.
    /// - Parameters:
    ///   - queue: The queue that will execute the block
    ///   - block: The work item to be invoked on the queue
    /// - Returns: The  generated `workItem`, in case you need it. Might be `nil` if our object is cancellable and to be destroyed.
    ///
    @discardableResult
    func async(in queue: DispatchQueue,
                      block: @escaping ()->Void) -> DispatchWorkItem?

    ///
    /// Submits a work item for asynchronous execution on a dispatch queue and safeguards it
    /// in case our calling object gets deleted. Will be executed after a specified delay.
    /// - Parameters:
    ///   - queue: The queue that will execute the block
    ///   - block: The work item to be invoked on the queue
    ///   - deadline: The time after which the work item should be executed, given as a `DispatchTime`
    /// - Returns: The  generated `workItem`, in case you need it. Might be `nil` if our object is cancellable and to be destroyed.
    ///
    @discardableResult
    func asyncAfter(in queue: DispatchQueue,
                           deadline: DispatchTime,
                           block: @escaping ()->Void) -> DispatchWorkItem?

    ///
    /// Submits a work item for asynchronous execution on a dispatch queue and safeguards it
    /// in case our calling object gets deleted.
    /// - Parameters:
    ///   - queue: The queue that will execute the block
    ///   - block: The work item to be invoked on the queue
    ///   - wallDeadline: The time after which the work item should be executed, given as a `DispatchWallTime`
    /// - Returns: The  generated `workItem`, in case you need it. Might be `nil` if our object is cancellable and to be destroyed.
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


///
/// The `DispatchWorkItemKeeper` allows you to keep track of your asynchronous work
/// items in a centralized part of the system.
///
/// It is meant for lightweight work, as a class that would remain active for a long time might
/// use a lot of resources that might not be fully cleaned, leading to memory being allocated for a
/// long time.
///
/// Usage:
///
///     import MisoDispatchWorkItemKeeper
///
///     struct MyClass {
///         private let dispatchWorkItemKeeper = DispatchWorkItemKeeper()
///
///         func someFunction() {
///             // Replace this (or any DispatchQueue async operation):
///             DispatchQueue.main.async {
///                 myOperation()
///             }
///             // With:
///             DispatchQueue.main.async(execute: self.dispatchWorkItemKeeper.keep(DispatchWorkItem {
///                 myOperation()
///             }))
///             // Or:
///             self.dispatchWorkItemKeeper.async(in: DispatchQueue.main) {
///                 myOperation()
///             }))
///         }
///     }
///
public struct DispatchWorkItemKeeper {
    /// The `_DispatchWorkItemKeeper` class can have multiple references, including from its own dispatch queue,
    /// meaning its queue can destroy its own object. We cannot have that. So `InnerClass` servers as an
    /// intermediate whose only goal is to deinit when our real owner is done.
    private class InnerClass {
        fileprivate var keeper: _DispatchWorkItemKeeper
        
        init(_ autoCleanCount: Int,
             _ cancelAtStop: Bool,
             _ queueLabel: String) {
            self.keeper = _DispatchWorkItemKeeper(autoCleanCount, cancelAtStop, queueLabel)
        }
        
        deinit {
            self.keeper.finalStop()
        }
    }
    
    /// Everything in our object is defined here
    private let innerClass: InnerClass
}

public extension DispatchWorkItemKeeper {
    enum RunMode {
        case automatic
        case manual
    }
    
    ///
    /// Creates a keeper to keep track of asynchronous objects being used, so they can be properly handled before class deletion
    /// - Parameters:
    ///   - runMode: Whether to start the keeper automatically at instantiation
    ///   - autoCleanCount: Cleaning up objects is a complex task. it is not done automatically. If there are more than this
    ///   number of objects (by default 10), it will schedule a cleanup.
    ///   - cancelAtStop: Whether you wish to cancel pending operations when deinitializing / stopping the class, or wait for them
    ///   to be deinitialized.
    ///   - queueLabel: Name of the queue that handles the keeper operations
    ///
    init(_ runMode: RunMode = .automatic,
                autoCleanCount: Int = 10,
                cancelAtStop: Bool = true,
                queueLabel: String = "com.misoservices.dispatchworkitemkeeper.queue.\(UUID().uuidString)")
    {
        self.innerClass = InnerClass(autoCleanCount, cancelAtStop, queueLabel)

        if runMode == .automatic {
            self.start()
        }
    }
}

extension DispatchWorkItemKeeper : DispatchWorkItemKeeperProtocol {
    public var isRunning: Bool {
        self.innerClass.keeper.isRunning
    }
    
    public var workItemsCount: Int {
        self.innerClass.keeper.workItemsCount
    }
    
    public func start() {
        self.innerClass.keeper.start()
    }
    
    public func stop(cancel: Bool?) {
        self.innerClass.keeper.stop(cancel: cancel)
    }
    
    @discardableResult
    public func keep(_ workItem: DispatchWorkItem) -> DispatchWorkItem {
        self.innerClass.keeper.keep(workItem)
    }
    
    @discardableResult
    public func async(in queue: DispatchQueue,
                      block: @escaping ()->Void) -> DispatchWorkItem? {
        self.innerClass.keeper.async(in: queue, block: block)
    }

    @discardableResult
    public func asyncAfter(in queue: DispatchQueue,
                           deadline: DispatchTime,
                           block: @escaping ()->Void) -> DispatchWorkItem? {
        self.innerClass.keeper.asyncAfter(in: queue, deadline: deadline, block: block)
    }

    @discardableResult
    public func asyncAfter(in queue: DispatchQueue,
                           wallDeadline: DispatchWallTime,
                           block: @escaping ()->Void) -> DispatchWorkItem? {
        self.innerClass.keeper.asyncAfter(in: queue, wallDeadline: wallDeadline, block: block)
    }
    
    public func cancelPending() {
        self.innerClass.keeper.cancelPending()
    }
    
    public func clean() {
        self.innerClass.keeper.clean()
    }
}


fileprivate class _DispatchWorkItemKeeper {
    let autoCleanCount: Int         ///< How many `workItems` in the Array before we try to clean up
    let cancelAtStop: Bool          ///< Cancel the pending items on stopping / deletion
    let queue: DispatchQueue        ///< Execution queue for `workItems` handling
    let group = DispatchGroup()     ///< Checking whether we have operations pending

    private var runSemaphore: Int = 0
    private var workItems: [DispatchWorkItem]? = nil
    private var cleanRequested: Bool = false
    private var stopRequested: Bool = false
    
    fileprivate init(_ autoCleanCount: Int,
                _ cancelAtStop: Bool,
                _ queueLabel: String) {
        self.autoCleanCount = autoCleanCount
        self.cancelAtStop = cancelAtStop
        self.queue = DispatchQueue(
            label: queueLabel,
            qos: .utility
        )
    }
    
    private func waitForNoAction() {
        while self.group.wait(timeout: .now()) != .success {
            self.group.wait()
        }
    }

    fileprivate func finalStop() {
        self.waitForNoAction()
        
        self.runSemaphore = -1
        self.stopRequested = true

        var keptWorkItems: [DispatchWorkItem]? = nil

        if self.cancelAtStop {
            self.queueAsync {
                if self.runSemaphore <= 0,
                    let workItems = self.workItems {
                    workItems.forEach { $0.cancel() }
                    keptWorkItems = self.workItems
                    self.workItems = nil
                }
            }
        }
        
        var workItem: DispatchWorkItem?
        repeat {
            workItem = nil

            // We cannot keep the queue locked while executing the work item, or else, we might deadlock
            // if that work item tries to keep a new one.
            self.queueSync {
                if self.workItems != nil {
                    if !self.workItems!.isEmpty {
                        workItem = self.workItems!.removeFirst()
                    }
                } else if keptWorkItems != nil {
                    if !keptWorkItems!.isEmpty {
                        workItem = keptWorkItems!.removeFirst()
                    }
                }
            }
            if let workItem = workItem {
                workItem.wait()
                self.waitForNoAction()
            }
        } while workItem != nil
    }
}

extension _DispatchWorkItemKeeper: DispatchWorkItemKeeperProtocol {
    var isRunning: Bool {
        self.workItems != nil
    }
    
    var workItemsCount: Int {
        var result: Int = 0
        self.queueSync {
            if let workItems = self.workItems {
                result = workItems.count
            }
        }
        return result
    }
    
    func start() {
        self.queueSync {
            guard self.runSemaphore >= 0 else { return }
            
            self.runSemaphore += 1
            
            guard self.runSemaphore == 1 else { return }

            self.workItems = [DispatchWorkItem]()
        }
    }
    
    func stop(cancel cancelAtStopOverride: Bool?) {
        let cancelAtStop = cancelAtStopOverride ?? self.cancelAtStop
        
        var doStop = false
        self.queueSync {
            if self.runSemaphore > 0 {
                self.runSemaphore -= 1
            }
            
            doStop = self.runSemaphore <= 0
        }
        
        guard doStop else { return }
        guard !self.stopRequested else { return }
        
        self.stopRequested = true
        var keptWorkItems: [DispatchWorkItem]? = nil

        var cancel = false
        if cancelAtStop {
            self.queueAsync {
                if self.runSemaphore <= 0,
                    let workItems = self.workItems {
                    workItems.forEach { $0.cancel() }
                    keptWorkItems = self.workItems
                    self.workItems = nil
                } else {
                    cancel = true
                }
            }
        }
        
        var workItem: DispatchWorkItem?
        repeat {
            workItem = nil

            // We cannot keep the queue locked while executing the work item, or else, we might deadlock
            // if that work item tries to keep a new one.
            self.queueSync {
                if self.runSemaphore > 0 {
                    cancel = true
                }
                guard !cancel else {
                    self.stopRequested = false
                    return
                }
                if self.workItems != nil {
                    if !self.workItems!.isEmpty {
                        workItem = self.workItems!.removeFirst()
                    }
                } else if keptWorkItems != nil {
                    if !keptWorkItems!.isEmpty {
                        workItem = keptWorkItems!.removeFirst()
                    }
                } else {
                    cancel = true
                }
            }
            guard !cancel else {
                self.stopRequested = false
                return
            }
            if let workItem = workItem {
                workItem.wait()
                self.waitForNoAction()
            }
        } while workItem != nil && !cancel
        
        self.queueSync {
            if self.runSemaphore <= 0 && !cancel {
                self.workItems = nil
            }
            self.stopRequested = false
        }
    }
    
    @discardableResult
    func keep(_ workItem: DispatchWorkItem) -> DispatchWorkItem {
        guard self.workItems != nil else {
            workItem.cancel()
            return workItem
        }
        self.queueAsync {
            guard self.workItems != nil else {
                workItem.cancel()
                return
            }

            self.workItems!.append(workItem)
            
            if self.workItems!.count > self.autoCleanCount {
                self.clean()
            }
        }
        return workItem
    }
    
    @discardableResult
    func async(in queue: DispatchQueue,
                      block: @escaping ()->Void) -> DispatchWorkItem? {
        guard self.workItems != nil else { return nil }
        let workItem = self.keep(DispatchWorkItem(block: block))
        queue.async(execute: workItem)
        return workItem
    }

    @discardableResult
    func asyncAfter(in queue: DispatchQueue,
                           deadline: DispatchTime,
                           block: @escaping ()->Void) -> DispatchWorkItem? {
        guard self.workItems != nil else { return nil }
        let workItem = self.keep(DispatchWorkItem(block: block))
        queue.asyncAfter(deadline: deadline, execute: workItem)
        return workItem
    }

    @discardableResult
    func asyncAfter(in queue: DispatchQueue,
                           wallDeadline: DispatchWallTime,
                           block: @escaping ()->Void) -> DispatchWorkItem? {
        guard self.workItems != nil else { return nil }
        let workItem = self.keep(DispatchWorkItem(block: block))
        queue.asyncAfter(wallDeadline: wallDeadline, execute: workItem)
        return workItem
    }
    
    func cancelPending() {
        self.queue.sync {
            guard let workItems = self.workItems else { return }

            workItems.forEach { $0.cancel() }
            clean()
        }
    }
    
    func clean() {
        guard self.workItems != nil else { return }
        guard !self.cleanRequested else { return }
        
        self.cleanRequested = true

        self.queueAsync {
            guard self.workItems != nil else { return }
            
            self.workItems!.removeAll {
                if $0.wait(timeout: .now()) == .success {
                    return true
                }
                return false
            }

            self.cleanRequested = false
        }
    }
}

/// Every operation we do as part of the keeper internal tasks is bound to a `DispatchGroup` so we can tell
/// whether we have a pending operation or not when we stop our processing.
private extension _DispatchWorkItemKeeper {
    func queueSync(block: @escaping ()->Void) {
        self.group.enter()
        self.queue.sync {
            block()
            self.group.leave()
        }
    }

    func queueAsync(block: @escaping ()->Void) {
        self.queue.async(group: self.group, execute: block)
    }
}

