//
//  Location.swift
//  MapTheThings
//
//  Created by Frank on 2016/7/16.
//  Copyright © 2016 The Things Network New York. All rights reserved.
//

import Foundation
import UIKit
import CoreLocation

let MINIMUM_HORIZONTAL_ACCURACY_METERS = 25.0

open class Location : NSObject, CLLocationManagerDelegate {
    let locationManager : CLLocationManager
    
    public override init() {
        locationManager = CLLocationManager()

        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        // Set a movement threshold for new events.
        locationManager.distanceFilter = 10 // meters

        let status = CLLocationManager.authorizationStatus()
        switch status {
        case .notDetermined:
            // Request when-in-use authorization initially
            locationManager.requestWhenInUseAuthorization()
            break
            
        case .restricted, .denied:
            // Disable location features
            disableMyLocationBasedFeatures()
            break
            
        case .authorizedWhenInUse, .authorizedAlways:
            // Enable location features
            enableMyWhenInUseFeatures()
            break
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Ignore updates that aren't at least accurate to 25 meters
        if let location = locations.last {
            if (location.horizontalAccuracy<MINIMUM_HORIZONTAL_ACCURACY_METERS) {
                //debugPrint("Got lat/lon", location)
                updateAppState { (old) -> AppState in
                    var state = old
                    state.map.currentLocation = location
                    return state
                }
            }
        }
    }
 
    public func locationManager(_ manager: CLLocationManager,
                         didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .restricted, .denied:
            disableMyLocationBasedFeatures()
            break
            
        case .authorizedWhenInUse:
            enableMyWhenInUseFeatures()
            break
            
        case .notDetermined, .authorizedAlways:
            break
        }
        updateAppState { (old) -> AppState in
            var state = old
            state.map.locationAuthStatus = status
            return state
        }
    }
    
    open func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
        debugPrint("locationManagerDidPauseLocationUpdates")
    }
    open func locationManager(_ manager: CLLocationManager,
                           didFailWithError error: Error) {
        debugPrint("didFailWithError", error)
    }
    
    func disableMyLocationBasedFeatures() {
        self.locationManager.stopUpdatingLocation()
    }
    
    func enableMyWhenInUseFeatures() {
        self.locationManager.startUpdatingLocation()
    }
}
