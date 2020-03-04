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

public struct DispatchWorkItemKeeper {
    fileprivate class Shared {
        var workItems = [UUID : [DispatchWorkItem]]()
    }
    fileprivate static let shared = Shared()

    private let uuid = UUID()
    
    public init() {}
    
    public func keep(_ workItem: DispatchWorkItem) -> DispatchWorkItem {
        if var array = Self.shared.workItems[uuid] {
            array.append(workItem)
        } else {
            Self.shared.workItems[uuid] = [workItem]
        }
        return workItem
    }
    public func invalidateAll() {
        if let array = Self.shared.workItems.removeValue(forKey: uuid) {
            array.forEach { $0.cancel() }
        }
    }
}
