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

public enum SamplingActive {
    case Play
    case Pause
    case Stop
}

public struct SamplingState {
    var state: SamplingActive
    var mostRecentSample: Sample?
}

public struct AppState {
    var now: NSDate
    var map: MapState
    var sampling: SamplingState
    static internal func x() -> Int {
        return 1
    }
}

private func defaultAppState() -> AppState {
    let samples = Array<Sample>()
    let nyNE = CLLocationCoordinate2D(latitude: 40.8476, longitude: -73.0543)
    let nySW = CLLocationCoordinate2D(latitude: 40.4976, longitude: -73.8631)
    let mapState = MapState(currentLocation: nil, updated: NSDate(), bounds: (ne: nyNE, sw: nySW), tracking: true, samples: samples)
    let samplingState = SamplingState(state: SamplingActive.Stop, mostRecentSample: nil)
    return AppState(now: NSDate(), map: mapState, sampling: samplingState)
}

public var appStateProperty = MutableProperty(defaultAppState())
public var appStateObservable = appStateProperty.signal

let sq = dispatch_queue_create("AppState", DISPATCH_QUEUE_SERIAL)

// Update app state in serial queue to avoid threading conflicts
public typealias AppStateUpdateFn = (AppState) -> AppState
public func updateAppState(fn: AppStateUpdateFn) {
    dispatch_async(sq) {
        appStateProperty.modify(fn)
    }
}

