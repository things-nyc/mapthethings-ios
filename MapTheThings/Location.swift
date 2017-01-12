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

let MINIMUM_HORIZONTAL_ACCURACY_METERS = 100.0

public class Location : NSObject, CLLocationManagerDelegate {
    let locationManager : CLLocationManager
    
    public override init() {
        locationManager = CLLocationManager()

        super.init()
        
        if CLLocationManager.locationServicesEnabled() {
            let status = CLLocationManager.authorizationStatus()
            if (status==CLAuthorizationStatus.AuthorizedWhenInUse || status == CLAuthorizationStatus.Denied) {
//                let title = (status == CLAuthorizationStatus.Denied) ? "Location services are off" : "Background location is not enabled";
//                let message = "To use background location you must turn on 'Always' in the Location Services Settings";
//                
//                let alert = UIAlertController(title: title, message: message, preferredStyle:  UIAlertControllerStyle.Alert)
//                alert.addAction(UIAlertAction(title: "Settings", style: UIAlertActionStyle.Default, handler:
//                    { action in
//                        switch action.style{
//                        case .Default:
//                            let settingsURL = NSURL.init(string: UIApplicationOpenSettingsURLString);
//                            UIApplication.sharedApplication().openURL(settingsURL!);
//                        case .Cancel:
//                            print("cancel")
//                            
//                        case .Destructive:
//                            print("destructive")
//                        }
//                }))
//                vc.presentViewController(alert, animated: true, completion: nil)
                locationManager.requestAlwaysAuthorization()
            }
                // The user has not enabled any location services. Request background authorization.
            else if (status == CLAuthorizationStatus.NotDetermined) {
                locationManager.requestAlwaysAuthorization()
            }

            
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            
            // Set a movement threshold for new events.
            locationManager.distanceFilter = 10 // meters
            
            locationManager.startUpdatingLocation()
        }
    }
    
    public func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Ignore updates that aren't at least accurate to 25 meters
        if let location = locations.last {
            if (location.horizontalAccuracy<MINIMUM_HORIZONTAL_ACCURACY_METERS) {
                debugPrint("Got lat/lon", location)
                updateAppState { (old) -> AppState in
                    var state = old
                    state.map.currentLocation = location
                    return state
                }
            }
        }
    }
    
    public func locationManagerDidPauseLocationUpdates(manager: CLLocationManager) {
        debugPrint("locationManagerDidPauseLocationUpdates")
    }
    public func locationManager(manager: CLLocationManager,
                           didFailWithError error: NSError) {
        debugPrint("didFailWithError", error)
    }
}
