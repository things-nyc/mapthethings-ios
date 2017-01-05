//
//  AppStateTests.swift
//  MapTheThings
//
//  Created by Frank on 2017/1/5.
//  Copyright © 2017 The Things Network New York. All rights reserved.
//

import XCTest
@testable import MapTheThings

class AppStateTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testObservingSyncChange() {
        let expectation = expectationWithDescription("Should observe count set")
        
        appStateObservable.observeNext { (old, new) in
            if (old.syncState.countToSync != 5 && new.syncState.countToSync==5) {
                XCTAssertEqual(5, new.syncState.countToSync)
                expectation.fulfill()
            }
        }
        
        updateAppState { old in
            var state = old
            state.syncState.countToSync = 5
            return state
        }
        
        waitForExpectationsWithTimeout(5.0) { (error) in
            if let err = error {
                XCTFail("Failed with error \(err)")
            }
        }
    }
    
    func testObservingSyncChangeRepeated() {
        let expectation = expectationWithDescription("Should observe count set")
        
        appStateObservable.observeNext { (old, new) in
            if (old.syncState.countToSync != 5 && new.syncState.countToSync==5) {
                XCTAssertEqual(5, new.syncState.countToSync)
                expectation.fulfill()
            }
        }
        
        updateAppState { old in
            var state = old
            state.syncState.countToSync = 5
            return state
        }
        
        waitForExpectationsWithTimeout(5.0) { (error) in
            if let err = error {
                XCTFail("Failed with error \(err)")
            }
        }
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock {
            // Put the code you want to measure the time of here.
        }
    }
    
}
