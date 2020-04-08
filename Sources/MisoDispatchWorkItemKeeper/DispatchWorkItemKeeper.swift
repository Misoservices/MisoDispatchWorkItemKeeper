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
    /// Everything in our object is defined here
    private let inner: InnerClass
}

public extension DispatchWorkItemKeeper {
    enum RunMode {
        case automatic
        case manual
    }
    
    ///
    /// Creates a keeper to keep track of asynchronous objects being used, so they can be properly handled
    /// before class deletion
    /// - Parameters:
    ///   - runMode: Whether to start the keeper automatically at instantiation
    ///   - autoCleanCount: Cleaning up objects is a complex task. it is not done automatically. If there
    ///   are more than this number of objects (by default 10), it will schedule a cleanup.
    ///   - cancelAtStop: Whether you wish to cancel pending operations when deinitializing / stopping
    ///   the class, or wait for them to be deinitialized.
    ///   - queueLabel: Name of the queue that handles the keeper operations
    ///
    init(_ runMode: RunMode = .automatic,
         autoCleanCount: Int = 10,
         cancelAtStop: Bool = true,
         queueLabel: String = "com.misoservices.dispatchworkitemkeeper.queue.\(UUID().uuidString)")
    {
        self.inner = InnerClass(autoCleanCount, cancelAtStop, queueLabel)
        
        if runMode == .automatic {
            self.start()
        }
    }
}

extension DispatchWorkItemKeeper : DispatchWorkItemKeeperProtocol {
    public var isRunning: Bool {
        self.inner.impl.isRunning
    }
    
    public var workItemsCount: Int {
        self.inner.impl.workItemsCount
    }
    
    public func start() {
        self.inner.impl.start()
    }
    
    public func stop(cancel: Bool?) {
        self.inner.impl.stop(cancel: cancel)
    }
    
    @discardableResult
    public func keep(_ workItem: DispatchWorkItem) -> DispatchWorkItem {
        self.inner.impl.keep(workItem)
    }
    
    @discardableResult
    public func async(in queue: DispatchQueue,
                      block: @escaping () -> Void) -> DispatchWorkItem? {
        self.inner.impl.async(in: queue, block: block)
    }
    
    @discardableResult
    public func asyncAfter(in queue: DispatchQueue,
                           deadline: DispatchTime,
                           block: @escaping () -> Void) -> DispatchWorkItem? {
        self.inner.impl.asyncAfter(in: queue, deadline: deadline, block: block)
    }
    
    @discardableResult
    public func asyncAfter(in queue: DispatchQueue,
                           wallDeadline: DispatchWallTime,
                           block: @escaping () -> Void) -> DispatchWorkItem? {
        self.inner.impl.asyncAfter(in: queue, wallDeadline: wallDeadline, block: block)
    }
    
    public func cancelPending() {
        self.inner.impl.cancelPending()
    }
    
    public func clean() {
        self.inner.impl.clean()
    }
}
