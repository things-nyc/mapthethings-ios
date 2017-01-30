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
    
    func testModifyingAppStateStruct() {
        let state = defaultState
        
        var mutable1 = state
        let now = Date()
        mutable1.now = now
        let copy = mutable1
        XCTAssertEqual(now, mutable1.now)
        XCTAssertEqual(now, copy.now)
        
        var mutable2 = state
        XCTAssertEqual(0, mutable2.syncState.syncPendingCount)
        mutable2.syncState.syncPendingCount = 2
        XCTAssertEqual(2, mutable2.syncState.syncPendingCount)
        let copy2 = mutable2
        XCTAssertEqual(2, copy2.syncState.syncPendingCount)
        
        let mutator = { (state: AppState) -> AppState in
            var mutable3 = state
            mutable3.syncState.syncPendingCount = 2
            return mutable3
        }
        let copy3 = mutator(state)
        XCTAssertEqual(2, copy3.syncState.syncPendingCount)
    }
    
    func testObservingSyncChange() {
        let expectation = self.expectation(description: "Should observe count set")
        
        let disposer = appStateObservable.observeValues { signal in
            if (signal.old.syncState.syncPendingCount != 5 && signal.new.syncState.syncPendingCount==5) {
                XCTAssertEqual(5, signal.new.syncState.syncPendingCount)
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
        
        waitForExpectations(timeout: 10.0) { (error) in
            if let err = error {
                XCTFail("Failed with error \(err)")
            }
        }
    }
    
    func testObservingSyncChangeRepeated() {
        let expectation = self.expectation(description: "Should observe count set")
        
        let disposer = appStateObservable.observeValues { signal in
            if (signal.old.syncState.syncPendingCount != 5 && signal.new.syncState.syncPendingCount==5) {
                XCTAssertEqual(5, signal.new.syncState.syncPendingCount)
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
