//
//  MapViewController.swift
//  MapTheThings
//
//  Created by Frank on 2016/6/30.
//  Copyright © 2016 The Things Network New York. All rights reserved.
//

import UIKit
import CoreLocation
import MapKit

// Wrote up here: http://stackoverflow.com/a/38236363/1207583
extension MKMapView {
    func edgePoints() -> Edges {
        let corners = [
            CGPoint(x: self.bounds.minX, y: self.bounds.minY),
            CGPoint(x: self.bounds.minX, y: self.bounds.maxY),
            CGPoint(x: self.bounds.maxX, y: self.bounds.maxY),
            CGPoint(x: self.bounds.maxX, y: self.bounds.minY)
        ]
        let coords = corners.map { corner in
            self.convertPoint(corner, toCoordinateFromView: self)
        }
        let startBounds = (
            n: coords[0].latitude, s: coords[0].latitude,
            e: coords[0].longitude, w: coords[0].longitude)
        let bounds = coords.reduce(startBounds) { b, c in
            let n = max(b.n, c.latitude)
            let s = min(b.s, c.latitude)
            let e = max(b.e, c.longitude)
            let w = min(b.w, c.longitude)
            return (n: n, s: s, e: e, w: w)
        }
        return (ne: CLLocationCoordinate2D(latitude: bounds.n, longitude: bounds.e),
                sw: CLLocationCoordinate2D(latitude: bounds.s, longitude: bounds.w))
    }
}

class MapViewController: AppStateUIViewController, MKMapViewDelegate, UIGestureRecognizerDelegate {
    @IBOutlet var timestamp: UILabel!
    @IBOutlet var toggle: UIButton!
    @IBOutlet var mapView: MKMapView!
    var lastSamples: Set<SampleAnnotation>?
    var mapDragRecognizer: UIPanGestureRecognizer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
        
        // Wire up gesture recognizer so that we can stop tracking when the user moves map elsewhere
        mapDragRecognizer = UIPanGestureRecognizer(target: self, action: #selector(didDragMap))
        mapDragRecognizer.delegate = self
        mapView.addGestureRecognizer(mapDragRecognizer)
    }
    
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer
        otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Thanks http://stackoverflow.com/a/5089553/1207583
        return true
    }
    
    func didDragMap(gestureRecognizer: UIGestureRecognizer) {
        if (gestureRecognizer.state == .Began) {
            updateAppState { (old) -> AppState in
                var state = old
                state.map.tracking = false
                return state
            }
        }
    }
    
    func mapView(mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        let edges = mapView.edgePoints()
        updateAppState { (old) -> AppState in
            var state = old
            state.map.bounds = (edges.ne, edges.sw)
            return state
        }
    }
    
    @IBAction func toggleTracking(event: UIEvent) {
        updateAppState { (old) -> AppState in
            var state = old
            state.map.tracking = !state.map.tracking
            return state
        }
    }
    
    override func renderAppState(oldState: AppState, state: AppState) {
        
        if let location = state.map.currentLocation {
            // Show current location in lat/lon on top of view
            let cordinateLong = location.coordinate.longitude
            let cordinateLat = location.coordinate.latitude
            let truncatedCoordinates = String(format: "Lat: %.3f, Lon: %.3f", cordinateLat, cordinateLong)
            self.timestamp.text = truncatedCoordinates
            
        }
        
        self.toggle.setTitle("Toggle Tracking: " + (state.map.tracking ? "True" : "False"), forState: UIControlState.Normal)
        if (state.map.tracking) {
            mapView.setUserTrackingMode(MKUserTrackingMode.Follow, animated:true)
        }
        else {
            mapView.setUserTrackingMode(MKUserTrackingMode.None, animated:true)
        }
        
        // TODO
        // - In Sampling mode, show last sample info
        let samples = state.map.samples.map { (s) -> SampleAnnotation in
            var typ = SampleAnnotationType.Summary
            if (s.attempts>0 && s.count==0) {
                typ = SampleAnnotationType.DeadZone
            }
            return SampleAnnotation(coordinate: s.location, type: typ)
        }
        let transmissions = state.map.transmissions.map { (s) -> SampleAnnotation in
            var type: SampleAnnotationType
            if s.ble_seq==nil {
                type = SampleAnnotationType.TransmissionUntracked
            }
            else if s.lora_seq==nil {
                type = SampleAnnotationType.TransmissionTracked
            }
            else {
                type = SampleAnnotationType.TransmissionSuccess
            }
            return SampleAnnotation(coordinate: s.location, type: type)
        }
        let new = Set<SampleAnnotation>(samples).union(Set<SampleAnnotation>(transmissions))
        if let last = self.lastSamples {
            // Figure out what remains, what gets added, and what gets removed
            let same = last.intersect(new)
            let add = new.subtract(same)
            let remove = last.subtract(same)
            if !remove.isEmpty {
                debugPrint("Removing", remove.count)
                switch remove.count {
                case 1: self.mapView.removeAnnotation(remove.first!)
                default: self.mapView.removeAnnotations([SampleAnnotation](remove))
                }
            }
            if !add.isEmpty {
                debugPrint("Adding", add.count)
                self.mapView.addAnnotations([SampleAnnotation](add))
            }
            self.lastSamples = same.union(add)
        }
        else {
            // No prior samples - add all annotations
            self.mapView.addAnnotations([SampleAnnotation](new))
            self.lastSamples = new
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

