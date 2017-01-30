//
//  AppState.swift
//  MapTheThings
//
//  Created by Frank on 2016/7/3.
//  Copyright © 2016 The Things Network New York. All rights reserved.
//

import CoreData
import CoreLocation
import ReactiveSwift
import enum Result.NoError
import Crashlytics


typealias Edges = (ne: CLLocationCoordinate2D, sw: CLLocationCoordinate2D)

public struct Sample {
    var count: Int32
    var attempts: Int32
    var location: CLLocationCoordinate2D
    var rssi: Float
    var snr: Float
    var timestamp: Date?
}

public struct TransSample {
    var location: CLLocationCoordinate2D
    var altitude: Double
    var timestamp: Date?

    var device: UUID? // LoraNode ID - device+ble_seq uniquely identify BLE transmit
    var ble_seq: UInt8?
    
    var lora_seq: UInt32?
    var objectID: NSManagedObjectID? // Where to write lora_seq when we get it back
}

public struct GridCell {
    var nw: CLLocationCoordinate2D
    var se: CLLocationCoordinate2D
}

public struct MapState {
    var currentLocation: CLLocation?
    var updated: Date
    var bounds: Edges
    var tracking: Bool
    var samples: [Sample]
    var cells: [GridCell]
    var transmissions: [TransSample]
}

public enum SamplingStrategy {
    case connectedNode // Bluetooth connected node is directed by app to send TTN message
    //case Periodic // Node sends message periodically.
}

public enum SamplingMode {
    case play
    case pause
    case stop
}

public struct SamplingState {
    var strategy: SamplingStrategy
    var mode: SamplingMode
    var mostRecentSample: Sample?
}

public struct Device {
    public init(uuid: UUID, name: String) {
        self.identifier = uuid
        self.name = name
    }
    let identifier: UUID
    var name: String
    var devAddr: Data?
    var nwkSKey: Data?
    var appSKey: Data?
    var appKey: Data?
    var appEUI: Data?
    var devEUI: Data?
    var connected: Bool = false
    var mode: SamplingMode = SamplingMode.play
    var lastLocation: CLLocation?
    var lastPacket: Data?
    var battery: UInt8 = 100
    var spreadingFactor: UInt8?
    var log: [String] = []
    var hideProvisioning: Bool = false
}

public struct SyncState {
    var syncWorking: Bool
    var syncPendingCount: Int
    var lastPost: Date?

    var recordWorking: Bool
    var recordLoraToObject: [(NSManagedObjectID, UInt32)]
}

public struct AppState {
    var now: Date
    var host: String
    var error: [String]
    var bluetooth: Dictionary<UUID, Device>
    var viewDetailDeviceID: UUID? = nil
    var map: MapState
    var sampling: SamplingState
    var syncState: SyncState

    var connectToDevice: UUID? = nil
    var disconnectDevice: UUID? = nil
    var sendPacket: UUID? = nil
    var requestProvisioning: (UUID, UUID)? = nil // (click ID, device ID)
    var assignProvisioning: (UUID, UUID)? = nil // (click ID, device ID)
}

private func defaultAppState() -> AppState {
    let samples = [Sample]()
    let cells = [GridCell]()
    let transmissions = [TransSample]()
    let nyNE = CLLocationCoordinate2D(latitude: 40.8476, longitude: -73.0543)
    let nySW = CLLocationCoordinate2D(latitude: 40.4976, longitude: -73.8631)
    let mapState = MapState(currentLocation: nil, updated: Date(), bounds: (ne: nyNE, sw: nySW), tracking: true, samples: samples, cells: cells, transmissions: transmissions)
    let samplingState = SamplingState(strategy: SamplingStrategy.connectedNode, mode: SamplingMode.stop, mostRecentSample: nil)

    var host = "map.thethings.nyc"
    if let testHost = Bundle.main.object(forInfoDictionaryKey: "TestHost") as? String {
        host = testHost
    }

    return AppState(
        now: Date(),
        host: host,
        error: [],
        bluetooth: Dictionary(),
        viewDetailDeviceID: nil,
        map: mapState,
        sampling: samplingState,
        syncState: SyncState(syncWorking: false, syncPendingCount: 0, lastPost: nil, recordWorking: false, recordLoraToObject: []),
        connectToDevice: nil,
        disconnectDevice: nil,
        sendPacket: nil,
        requestProvisioning: nil,
        assignProvisioning: nil
    )
}

let defaultState = defaultAppState()
public typealias AppStateSignal = (old: AppState, new: AppState)
public var appStateProperty = MutableProperty<AppStateSignal>((old: defaultState, new: defaultState))
public var appStateObservable = appStateProperty.signal

let sq = DispatchQueue(label: "AppState", attributes: [])

// Update app state in serial queue to avoid threading conflicts
public typealias AppStateUpdateFn = (AppState) -> AppState
public func updateAppState(_ fn: @escaping AppStateUpdateFn) {
    sq.async {
        appStateProperty.modify({ (mutable) -> Void in
            mutable.old = mutable.new
            mutable.new = fn(mutable.new)
        })
    }
}

public func stateValChanged<T : Equatable>(_ state: AppStateSignal, access: (AppState) -> T?) -> Bool {
    let new = access(state.new)
    let old = access(state.old)
    var changed = false
    if let newValue = new {
        if let oldValue = old {
            changed = !(newValue==oldValue) // Different from last one?
        }
        else {
            changed = true // New this state!
        }
    }
    else if (old != nil) {
        changed = true // Was set, now it isn't
    }
    return changed
}

public func stateValChanged<T1 : Equatable, T2 : Equatable>(_ state: AppStateSignal, access: (AppState) -> (T1, T2)?) -> Bool {
    let new = access(state.new)
    let old = access(state.old)
    var changed = false
    if let newValue = new {
        if let oldValue = old {
            changed = !(newValue==oldValue) // Different from last one?
        }
        else {
            changed = true // New this state!
        }
    }
    else if (old != nil) {
        changed = true // Was set, now it isn't
    }
    return changed
}

public func setAppError(_ error: NSError, fn: String, domain: String) {
    let msg = "Error in \(domain)/\(fn): \(error)"
    debugPrint(msg)
    Crashlytics.sharedInstance().recordError(error, withAdditionalUserInfo: ["domain": domain, "function": fn])
    updateAppState { (old) -> AppState in
        var state = old
        state.error.append(msg)
        return state
    }
}

public func setAppError(_ error: Error, fn: String, domain: String) {
    let msg = "Error in \(domain)/\(fn): \(error)"
    debugPrint(msg)
    let nserr = NSError(domain: domain, code: 0, userInfo: [NSLocalizedDescriptionKey: "\(error)"])
    Crashlytics.sharedInstance().recordError(nserr, withAdditionalUserInfo: ["domain": domain, "function": fn])
    updateAppState { (old) -> AppState in
        var state = old
        state.error.append(msg)
        return state
    }
}


