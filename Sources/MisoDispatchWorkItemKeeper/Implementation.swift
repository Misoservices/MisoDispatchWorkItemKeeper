//
//  Implementation.swift
//  MisoDispatchWorkItemKeeper
//
//  Created by Michel Donais on 2020-04-08.
//  Copyright © 2020 Misoservices Inc. All rights reserved.
//  [BSL-1.0] This package is Licensed under the Boost Software License - Version 1.0
//

import Foundation
import Dispatch

class Implementation {
    let autoCleanCount: Int         ///< How many `workItems` in the Array before we try to clean up
    let cancelAtStop: Bool          ///< Cancel the pending items on stopping / deletion
    let queue: DispatchQueue        ///< Execution queue for `workItems` handling
    let group = DispatchGroup()     ///< Checking whether we have operations pending

    private var runSemaphore: Int = 0
    private var workItems: [DispatchWorkItem]? = nil
    private var cleanRequested: Bool = false
    private var stopRequested: Bool = false
    
    init(_ autoCleanCount: Int,
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

    func finalStop() {
        self.waitForNoAction()
        
        self.runSemaphore = -1
        self.stopRequested = true

        let keptWorkItems: [DispatchWorkItem]? = self.workItems

        if self.cancelAtStop {
            self.cancelAllOperations()
        }
        
        self.waitForDone(canAbort: false, keptWorkItems: keptWorkItems)
    }
}

extension Implementation: DispatchWorkItemKeeperProtocol {
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

        self.waitForNoAction()
        guard !self.stopRequested else { return }
        
        self.stopRequested = true
        let keptWorkItems: [DispatchWorkItem]? = self.workItems

        if cancelAtStop {
            self.cancelAllOperations()
        }
        
        let aborted = self.waitForDone(canAbort: true, keptWorkItems: keptWorkItems)
        
        self.queueSync {
            if self.runSemaphore <= 0 && !aborted {
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
private extension Implementation {
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
    
    func cancelAllOperations() {
        self.queueAsync {
            if self.runSemaphore <= 0,
                let workItems = self.workItems {
                workItems.forEach { $0.cancel() }
                self.workItems = nil
            }
        }
    }
    
    @discardableResult
    func waitForDone(canAbort: Bool,
                     keptWorkItems: [DispatchWorkItem]?) -> Bool {
        var abort = false
        var keptWorkItems = keptWorkItems       // Make a mutable copy
        
        var workItem: DispatchWorkItem?
        repeat {
            workItem = nil

            // We cannot keep the queue locked while executing the work item, or else, we might deadlock
            // if that work item tries to keep a new one.
            self.queueSync {
                if canAbort {
                    if self.runSemaphore > 0 {
                        abort = true
                    }
                    guard !abort else {
                        self.stopRequested = false
                        return
                    }
                }
                
                if self.workItems != nil {
                    if !self.workItems!.isEmpty {
                        workItem = self.workItems!.removeFirst()
                    }
                } else if keptWorkItems != nil {
                    if !keptWorkItems!.isEmpty {
                        workItem = keptWorkItems!.removeFirst()
                    }
                } else if canAbort {
                    abort = true
                }
            }
            if canAbort {
                guard !abort else {
                    self.stopRequested = false
                    return abort
                }
            }
            if let workItem = workItem {
                workItem.wait()
                self.waitForNoAction()
            }
        } while workItem != nil && !abort
        
        return abort
    }
}
