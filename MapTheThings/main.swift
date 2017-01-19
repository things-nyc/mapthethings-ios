//
//  main.swift
//  MapTheThings
//
//  Created by Frank on 2017/1/5.
//  Copyright © 2017 The Things Network New York. All rights reserved.
//

import Foundation
import UIKit

let isRunningTests = NSClassFromString("XCTestCase") != nil

let argv = UnsafeMutableRawPointer(CommandLine.unsafeArgv)
    .bindMemory(to: UnsafeMutablePointer<Int8>.self,
                capacity: Int(CommandLine.argc))

if isRunningTests {
    UIApplicationMain(CommandLine.argc, argv, nil, NSStringFromClass(TestingAppDelegate.self))
} else {
    UIApplicationMain(CommandLine.argc, argv, nil, NSStringFromClass(AppDelegate.self))
}
