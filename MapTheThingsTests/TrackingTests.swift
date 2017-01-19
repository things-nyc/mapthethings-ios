//
//  TrackingTests.swift
//  MapTheThings
//
//  Created by Frank on 2016/7/25.
//  Copyright © 2016 The Things Network New York. All rights reserved.
//

import XCTest
import CoreLocation
@testable import MapTheThings

class TrackingTests: XCTestCase {
    func testShouldSend() {
        let now = Date()
        let coordinate = CLLocationCoordinate2D(latitude: 10, longitude: 10)
        let currentLocation = CLLocation(coordinate: coordinate, altitude: 15, horizontalAccuracy: 5, verticalAccuracy: 5, course: 0, speed: 0, timestamp: now)
        let uuid = UUID()
        var device = Device(uuid: uuid, name: "DeviceName")
        
        device.lastLocation = currentLocation
        XCTAssertFalse(Tracking.shouldSend(device, location: currentLocation), "Don't report same location")
        
        let lastLocation1 = CLLocation(coordinate: coordinate, altitude: 15, horizontalAccuracy: 5, verticalAccuracy: 5, course: 0, speed: 0, timestamp: now.addingTimeInterval(-30))
        device.lastLocation = lastLocation1
        XCTAssertFalse(Tracking.shouldSend(device, location: currentLocation), "Don't report same location even sampled 30 seconds before")
        
        let coordinate2 = CLLocationCoordinate2D(latitude: 10.0002, longitude: 10)
        let lastLocation2 = CLLocation(coordinate: coordinate2, altitude: 15, horizontalAccuracy: 5, verticalAccuracy: 5, course: 0, speed: 0, timestamp: now.addingTimeInterval(-10))
        // Ensure that coordinate2 is more than 10 meters away but not that much more
        XCTAssertGreaterThan(currentLocation.distance(from: lastLocation2), 10)
        XCTAssertLessThan(currentLocation.distance(from: lastLocation2), 25)
        
        device.lastLocation = lastLocation2
        XCTAssertFalse(Tracking.shouldSend(device, location: currentLocation), "Don't report different location if prior only 10 seconds before")

        let lastLocation3 = CLLocation(coordinate: coordinate2, altitude: 15, horizontalAccuracy: 5, verticalAccuracy: 5, course: 0, speed: 0, timestamp: now.addingTimeInterval(-15))
        device.lastLocation = lastLocation3
        XCTAssert(Tracking.shouldSend(device, location: currentLocation), "Report current if prior is 15 sec ago and >10 meters away")
    }
}
