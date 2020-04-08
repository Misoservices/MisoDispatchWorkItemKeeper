//
//  InnerClass.swift
//  MisoDispatchWorkItemKeeper
//
//  Created by Michel Donais on 2020-04-08.
//  Copyright © 2020 Misoservices Inc. All rights reserved.
//  [BSL-1.0] This package is Licensed under the Boost Software License - Version 1.0
//

import Foundation

extension DispatchWorkItemKeeper {
    /// The `Implementation` class can have multiple references, including from its own dispatch queue,
    /// meaning its queue can destroy its own object. We cannot have that. So `InnerClass` servers as an
    /// intermediate whose only goal is to deinit when our real owner is done.
    class InnerClass {
        var impl: Implementation
        
        init(_ autoCleanCount: Int,
             _ cancelAtStop: Bool,
             _ queueLabel: String) {
            self.impl = Implementation(autoCleanCount, cancelAtStop, queueLabel)
        }
        
        deinit {
            self.impl.finalStop()
        }
    }
}
