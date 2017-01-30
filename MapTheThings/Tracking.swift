//
//  Tracking.swift
//  MapTheThings
//
//  Created by Frank on 2016/7/17.
//  Copyright © 2016 The Things Network New York. All rights reserved.
//
//  - Create BT-transaction ID
//  - Send packet with BT-transaction ID
//  - Store last packet data and location
//  - Store record in DB
//  - On successful transmit mark

import CoreLocation
//import ReactiveSwift

let CURRENT_LOCATION_EXPIRY = 15.0  // How many seconds a current location remains valid
let DISTANCE_BETWEEN_SAMPLES = 10.0 // Don't report samples closer than this number of meters
let TIME_BETWEEN_SAMPLES = 12.0     // Don't report samples more often than this number of seconds

extension CLLocation {
    var data48: Data? {
        let ilon = Int32(self.coordinate.longitude * 46603)
        var lon = UInt32(ilon < 0 ? (UINT32_MAX-UInt32(abs(ilon))+1) : UInt32(ilon)) // Expand +/-180 coordinate to fill 24bits
        let ilat = Int32(self.coordinate.latitude * 93206)
        var lat = UInt32(ilat < 0 ? (UINT32_MAX-UInt32(abs(ilat))+1) : UInt32(ilat))  // Expand +/-90 coordinate to fill 24bits
        lat = NSSwapHostIntToLittle(lat)
        lon = NSSwapHostIntToLittle(lon)
        if let data = NSMutableData(capacity: 6) {
            // Append each coordinate. Post conversion to little endian, lower 24 bits are all we need.
            let latBytes = UnsafeBufferPointer(start: &lat, count: 3)
            data.append(Data(buffer: latBytes))
            let lonBytes = UnsafeBufferPointer(start: &lon, count: 3)
            data.append(Data(buffer: lonBytes))
            return data as Data
        }
        return nil
    }
}

open class Tracking {
//    var sendDisposer: Disposable?
    
    fileprivate static func makePacket(_ version: UInt8, location: CLLocation) -> Data? {
        if let data = NSMutableData(capacity: 7) {
            data.append(version.data as Data)
            if let ld = location.data48 {
                data.append(ld)
                assert(7==data.length, "Expected to make 7 byte coordinate")
                return data as Data
            }
        }
        else {
            NSLog("Warning: Unable to allocate location data")
        }
        return nil
    }
    
    fileprivate static func sendPacket(_ device: Device, location: CLLocation, bluetooth: Bluetooth, dataController: DataController) -> Void {
        // Send it to the Bluetooth peripheral
        let deviceId = device.identifier
        if let v2data = Tracking.makePacket(2, location: location),
            let v1data = Tracking.makePacket(1, location: location),
            let node = bluetooth.node(deviceId) {
            do {
                var sent = false
                var ble_seq:UInt8? = nil
                var sent_data = v2data
                ble_seq = node.sendPacketWithAck(v2data)
                if ble_seq==nil {
                    // Tracked send not available, try regular send
                    sent = node.sendPacket(v1data)
                    sent_data = v1data
                }
                else {
                    sent = true
                }
                if sent {
                    // Write packet data. Not ready to sync until we hear that it was 
                    // sent successfully and learn the seq_no.
                    let tx = try Transmission.create(
                        dataController,
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude,
                        altitude: location.altitude,
                        packet: sent_data,
                        device: device.identifier)
                    let (objectID, created) = try dataController.performAndWaitInContext() { _ in
                        return (tx.objectID, tx.created)
                    }
                    let ts = TransSample(location: location.coordinate, altitude: location.altitude, timestamp: created, device: deviceId, ble_seq: ble_seq, lora_seq: nil, objectID: objectID)
                    updateAppState { (old) -> AppState in
                        var state = old
                        state.map.transmissions.append(ts)
                        state.bluetooth[deviceId]?.lastPacket = sent_data
                        state.bluetooth[deviceId]?.lastLocation = location
                        return state
                    }
                }
            }
            catch let error as NSError {
                setAppError(error, fn: "sendPacket", domain: "database")
            }
            catch let error {
                let nserr = NSError(domain: "database", code: 1, userInfo: [NSLocalizedDescriptionKey: "\(error)"])
                setAppError(nserr, fn: "sendPacket", domain: "database")
            }
        }
    }
    
    open static func shouldSend(_ device: Device, location currentLocation: CLLocation) -> Bool {
        // Sampled in last 15 seconds. We don't want to be moving, get a location, and attempt to transmit it
        // when we've moved to a different location.
        let isCurrentLocation = fabs(currentLocation.timestamp.timeIntervalSinceNow) < CURRENT_LOCATION_EXPIRY
        
        // Confirm different in time and distance
        var movedSignificantly = true // If first location
        if let lastLoc = device.lastLocation {
            let d = lastLoc.distance(from: currentLocation) // in meters
            let t = lastLoc.timestamp.timeIntervalSince(currentLocation.timestamp)
            movedSignificantly = d > DISTANCE_BETWEEN_SAMPLES && fabs(t) > TIME_BETWEEN_SAMPLES
        }
        return isCurrentLocation && movedSignificantly && device.mode==SamplingMode.play
    }
    
    public init(bluetooth: Bluetooth, dataController: DataController) {
        // Listen for app state changes...
//        self.sendDisposer =
        appStateObservable.observeValues { update in
            let manualSend: Bool = stateValChanged(update) {$0.sendPacket}
            if let location = update.new.map.currentLocation {
                // Send to all connected devices
                for (_, device) in update.new.bluetooth {
                    if device.connected {
                        if (manualSend || Tracking.shouldSend(device, location: location)) {
                            Tracking.sendPacket(device, location: location, bluetooth: bluetooth, dataController: dataController)
                        }
                    }
                }
            }
        }
    }
}
