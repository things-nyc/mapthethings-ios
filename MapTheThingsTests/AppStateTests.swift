//
//  AppStateTests.swift
//  MapTheThings
//
//  Created by Frank on 2017/1/5.
//  Copyright © 2017 The Things Network New York. All rights reserved.
//

import XCTest
import ReactiveSwift
@testable import MapTheThings

class AppStateTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        updateAppState { state in
            return defaultState
        }
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testObservingSyncChange() {
        let expectation = self.expectation(description: "Should observe count set")
        
        let disposer = appStateObservable.observeValues { (old, new) in
            if (old.syncState.syncPendingCount != 5 && new.syncState.syncPendingCount==5) {
                XCTAssertEqual(5, new.syncState.syncPendingCount)
                expectation.fulfill()
            }
        }
        defer {
            disposer?.dispose()
        }
        
        updateAppState { old in
            var state = old
            state.syncState.syncPendingCount = 5
            return state
        }
        
        waitForExpectations(timeout: 5.0) { (error) in
            if let err = error {
                XCTFail("Failed with error \(err)")
            }
        }
    }
    
    func testObservingSyncChangeRepeated() {
        let expectation = self.expectation(description: "Should observe count set")
        
        let disposer = appStateObservable.observeValues { (old, new) in
            if (old.syncState.syncPendingCount != 5 && new.syncState.syncPendingCount==5) {
                XCTAssertEqual(5, new.syncState.syncPendingCount)
                expectation.fulfill()
            }
        }
        defer {
            disposer?.dispose()
        }
        
        updateAppState { old in
            var state = old
            state.syncState.syncPendingCount = 5
            return state
        }
        
        waitForExpectations(timeout: 5.0) { (error) in
            if let err = error {
                XCTFail("Failed with error \(err)")
            }
        }
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
