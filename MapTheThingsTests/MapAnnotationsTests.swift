//
//  MapAnnotationsTests.swift
//  MapTheThings
//
//  Created by Frank on 2016/7/13.
//  Copyright © 2016 The Things Network New York. All rights reserved.
//

import XCTest
import CoreLocation
import MapTheThings

class MapAnnotationsTests: XCTestCase {

    func testSetOperations() {
        // Ensure that SampleAnnotation works correctly within a Set
        let l1: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 10, longitude: 10)
        let s1 = SampleAnnotation(coordinate: l1, type: .summary)
        let s2 = SampleAnnotation(coordinate: l1, type: .summary)
        XCTAssert(s1==s2)
        XCTAssertEqual(s1.hashValue, s2.hashValue)
        let set1 = Set<SampleAnnotation>([s1])
        XCTAssertEqual(1, set1.count)
        let set2 = Set<SampleAnnotation>([s2])
        XCTAssertEqual(1, set2.count)
        let sub = set1.subtracting(set2)
        XCTAssertEqual(0, sub.count)
        //XCTAssertEqual(set1, set2)
        let intersection = set1.intersection(set2)
        XCTAssertEqual(1, intersection.count)
        let removed = set1.subtracting(intersection)
        XCTAssertEqual(0, removed.count)
        let union = set1.union(set2)
        XCTAssertEqual(1, union.count)
    }
}
