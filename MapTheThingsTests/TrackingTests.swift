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
        let now = NSDate()
        let coordinate = CLLocationCoordinate2D(latitude: 10, longitude: 10)
        let currentLocation = CLLocation(coordinate: coordinate, altitude: 15, horizontalAccuracy: 5, verticalAccuracy: 5, course: 0, speed: 0, timestamp: now)
        let shouldSendGivenLastDeviceLocation = Tracking.shouldSend(currentLocation, manualSend: false)

        let uuid = NSUUID()
        var device = Device(uuid: uuid)
        
        device.lastLocation = currentLocation
        XCTAssertFalse(shouldSendGivenLastDeviceLocation(uuid, device), "Don't report same location")
        
        let lastLocation1 = CLLocation(coordinate: coordinate, altitude: 15, horizontalAccuracy: 5, verticalAccuracy: 5, course: 0, speed: 0, timestamp: now.dateByAddingTimeInterval(-30))
        device.lastLocation = lastLocation1
        XCTAssertFalse(shouldSendGivenLastDeviceLocation(uuid, device), "Don't report same location even sampled 30 seconds before")
        
        let coordinate2 = CLLocationCoordinate2D(latitude: 10.0002, longitude: 10)
        let lastLocation2 = CLLocation(coordinate: coordinate2, altitude: 15, horizontalAccuracy: 5, verticalAccuracy: 5, course: 0, speed: 0, timestamp: now.dateByAddingTimeInterval(-10))
        // Ensure that coordinate2 is more than 10 meters away but not that much more
        XCTAssertGreaterThan(currentLocation.distanceFromLocation(lastLocation2), 10)
        XCTAssertLessThan(currentLocation.distanceFromLocation(lastLocation2), 25)
        
        device.lastLocation = lastLocation2
        XCTAssertFalse(shouldSendGivenLastDeviceLocation(uuid, device), "Don't report different location if prior only 10 seconds before")

        let lastLocation3 = CLLocation(coordinate: coordinate2, altitude: 15, horizontalAccuracy: 5, verticalAccuracy: 5, course: 0, speed: 0, timestamp: now.dateByAddingTimeInterval(-15))
        device.lastLocation = lastLocation3
        XCTAssert(shouldSendGivenLastDeviceLocation(uuid, device), "Report current if prior is 15 sec ago and >10 meters away")
    }
}
