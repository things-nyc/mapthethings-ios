//
//  Tracking.swift
//  MapTheThings
//
//  Created by Frank on 2016/7/17.
//  Copyright © 2016 The Things Network New York. All rights reserved.
//

import CoreLocation

let CURRENT_LOCATION_EXPIRY = 15.0  // How many seconds a current location remains valid
let DISTANCE_BETWEEN_SAMPLES = 10.0 // Don't report samples closer than this number of meters
let TIME_BETWEEN_SAMPLES = 12.0     // Don't report samples more often than this number of seconds

extension CLLocation {
    var data48: NSData? {
        let ilon = Int32(self.coordinate.longitude * 46603)
        var lon = UInt32(ilon < 0 ? (UINT32_MAX-UInt32(abs(ilon))+1) : UInt32(ilon)) // Expand +/-180 coordinate to fill 24bits
        let ilat = Int32(self.coordinate.latitude * 93206)
        var lat = UInt32(ilat < 0 ? (UINT32_MAX-UInt32(abs(ilat))+1) : UInt32(ilat))  // Expand +/-90 coordinate to fill 24bits
        lat = NSSwapHostIntToLittle(lat)
        lon = NSSwapHostIntToLittle(lon)
        if let data = NSMutableData(capacity: 6) {
            // Append each coordinate. Post conversion to little endian, lower 24 bits are all we need.
            data.appendData(NSData(bytes: &lat, length: 3))
            data.appendData(NSData(bytes: &lon, length: 3))
            return data
        }
        return nil
    }
}

public class Tracking {
    private static func makePacket(location: CLLocation) -> NSData? {
        if let data = NSMutableData(capacity: 7) {
            data.appendData(UInt8(0x01).data)
            if let ld = location.data48 {
                data.appendData(ld)
                assert(7==data.length, "Expected to make 7 byte coordinate")
                return data
            }
        }
        else {
            NSLog("Warning: Unable to allocate location data")
        }
        return nil
    }
    
    private static func sendPacket(location: CLLocation, bluetooth: Bluetooth) -> ((NSUUID, Device) -> Void) {
        return { (uuid: NSUUID, _: Device) in
            // Send it to the Bluetooth peripheral
            if let data = Tracking.makePacket(location),
                node = bluetooth.node(uuid) {
                let sent = node.sendPacket(data)
                if sent {
                    updateAppState { (old) -> AppState in
                        var state = old
                        state.bluetooth[uuid]?.lastPacket = data
                        state.bluetooth[uuid]?.lastLocation = location
                        return state
                    }
                }
            }
        }
    }
    
    public static func shouldSend(currentLocation: CLLocation, manualSend: Bool) -> ((NSUUID, Device) -> Bool) {
        if manualSend {
            return { _,_ in true }
        }
        
        // Sampled in last 15 seconds. We don't want to be moving, get a location, and attempt to transmit it 
        // when we've moved to a different location.
        let isCurrentLocation = fabs(currentLocation.timestamp.timeIntervalSinceNow) < CURRENT_LOCATION_EXPIRY
        
        return { (_, dev) -> Bool in
            // Confirm different in time and distance
            var movedSignificantly = true // If first location
            if let lastLoc = dev.lastLocation {
                let d = lastLoc.distanceFromLocation(currentLocation) // in meters
                let t = lastLoc.timestamp.timeIntervalSinceDate(currentLocation.timestamp)
                movedSignificantly = d > DISTANCE_BETWEEN_SAMPLES && fabs(t) > TIME_BETWEEN_SAMPLES
            }
            return isCurrentLocation && movedSignificantly && dev.mode==SamplingMode.Play
        }
    }
    
    public init(bluetooth: Bluetooth) {
        // Listen for app state changes...
        appStateObservable.observeNext({update in
            if let location = update.new.map.currentLocation {
                let manualSend = stateValChanged(update) { (state) -> (NSUUID?) in
                    state.sendPacket
                }
                
                let state = update.new
                state.bluetooth
                .filter({ _,dev in
                    dev.connected // Only devices that are connected
                })
                .filter(Tracking.shouldSend(location, manualSend: manualSend))
                .forEach(Tracking.sendPacket(location, bluetooth: bluetooth))
            }
        })
    }
}