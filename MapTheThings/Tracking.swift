//
//  Tracking.swift
//  MapTheThings
//
//  Created by Frank on 2016/7/17.
//  Copyright © 2016 The Things Network New York. All rights reserved.
//

import Foundation
import CoreLocation

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
    public init(bluetooth: Bluetooth) {
        // Listen for app state changes...
        appStateObservable.observeNext({update in
            if let location = update.new.map.currentLocation {
                let manualSend = stateValChanged(update, access: { (state) -> (NSUUID?) in
                    state.sendPacket
                })
                let locUpdate = stateValChanged(update, access: { (state) -> (CLLocation?) in
                    state.map.currentLocation
                })
                
                // Make a packet of the location
                update.new.bluetooth
                .filter({ (uuid, dev) -> Bool in
                    // Find all devices which are connected and currently tracking (Play)
                    return dev.connected
                })
                .filter({ (uuid, dev) -> Bool in
                    // Confirm different in time and distance
                    var moved = false
                    if let lastLoc = dev.lastLocation {
                        let d = lastLoc.distanceFromLocation(location)
                        let t = lastLoc.timestamp.timeIntervalSinceDate(location.timestamp)
                        moved = d > 10 || fabs(t) > 60
                    }
                    return ((locUpdate || moved) && dev.mode==SamplingMode.Play) || manualSend
                })
                .forEach({ (uuid, dev) in
                    // Send it to the Bluetooth peripheral
                    if let data = NSMutableData(capacity: 7) {
                        data.appendData(UInt8(0x01).data)
                        if let ld = location.data48 {
                            data.appendData(ld)
                            assert(7==data.length, "Expected to make 7 byte coordinate")
                            if let node = bluetooth.node(uuid) {
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
                        else {
                            debugPrint("Unable to allocate location data")
                        }
                    }
                })
            }
        })
    }
}