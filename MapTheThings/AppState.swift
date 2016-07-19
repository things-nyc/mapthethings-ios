//
//  AppState.swift
//  MapTheThings
//
//  Created by Frank on 2016/7/3.
//  Copyright © 2016 The Things Network New York. All rights reserved.
//

import Foundation
import CoreLocation
import ReactiveCocoa
import enum Result.NoError

typealias Edges = (ne: CLLocationCoordinate2D, sw: CLLocationCoordinate2D)

public struct Sample {
    var location: CLLocationCoordinate2D
    var rssi: Float
    var snr: Float
    var timestamp: NSDate?
    var seqno: Int32?
}

public struct MapState {
    var currentLocation: CLLocation?
    var updated: NSDate
    var bounds: Edges
    var tracking: Bool
    var samples: Array<Sample>
}

public enum SamplingStrategy {
    case ConnectedNode // Bluetooth connected node is directed by app to send TTN message
    //case Periodic // Node sends message periodically.
}

public enum SamplingMode {
    case Play
    case Pause
    case Stop
}

public struct SamplingState {
    var strategy: SamplingStrategy
    var mode: SamplingMode
    var mostRecentSample: Sample?
}

public struct Device {
    public init(uuid: NSUUID) {
        identifier = uuid
    }
    let identifier: NSUUID
    var devAddr: NSData?
    var nwkSKey: NSData?
    var appSKey: NSData?
    var connected: Bool = false
    var mode: SamplingMode = SamplingMode.Play
    var lastLocation: CLLocation?
    var lastPacket: NSData?
}

public struct AppState {
    var now: NSDate
    var bluetooth: Dictionary<NSUUID, Device>
    var map: MapState
    var sampling: SamplingState
    var sendPacket: NSUUID? = nil
}

private func defaultAppState() -> AppState {
    let samples = Array<Sample>()
    let nyNE = CLLocationCoordinate2D(latitude: 40.8476, longitude: -73.0543)
    let nySW = CLLocationCoordinate2D(latitude: 40.4976, longitude: -73.8631)
    let mapState = MapState(currentLocation: nil, updated: NSDate(), bounds: (ne: nyNE, sw: nySW), tracking: true, samples: samples)
    let samplingState = SamplingState(strategy: SamplingStrategy.ConnectedNode, mode: SamplingMode.Stop, mostRecentSample: nil)
    return AppState(
        now: NSDate(),
        bluetooth: Dictionary(),
        map: mapState,
        sampling: samplingState,
        sendPacket: nil)
}

let defaultState = defaultAppState()
public var appStateProperty = MutableProperty((old: defaultState, new: defaultState))
public var appStateObservable = appStateProperty.signal

let sq = dispatch_queue_create("AppState", DISPATCH_QUEUE_SERIAL)

// Update app state in serial queue to avoid threading conflicts
public typealias AppStateUpdateFn = (AppState) -> AppState
public func updateAppState(fn: AppStateUpdateFn) {
    dispatch_async(sq) {
        appStateProperty.modify({ (last: (old: AppState, new: AppState)) -> ((old: AppState, new: AppState)) in
            let newState = fn(last.new)
            return (old: last.new, new: newState)
        })
    }
}

public func stateValChanged<T : Equatable>(state: (old: AppState, new: AppState), access: (AppState) -> (T?)) -> Bool {
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
    return changed
}

