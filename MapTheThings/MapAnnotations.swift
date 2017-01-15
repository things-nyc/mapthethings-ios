//
//  MapAnnotations.swift
//  MapTheThings
//
//  Created by Frank on 2016/7/12.
//  Copyright © 2016 The Things Network New York. All rights reserved.
//

import MapKit

public enum SampleAnnotationType {
    case Summary
    case DeadZone

    case TransmissionUntracked
    case TransmissionTracked
    case TransmissionSuccess
    case TransmissionError
}

public class SampleAnnotation : NSObject, MKAnnotation {
    public let title: String?
    public let subtitle: String?
    public let coordinate: CLLocationCoordinate2D
    public let type: SampleAnnotationType
    
    public init(coordinate: CLLocationCoordinate2D, type: SampleAnnotationType) {
        self.title = nil
        self.subtitle = nil
        self.coordinate = coordinate
        self.type = type
        
        super.init()
    }
    
    public func pinTintColor() -> UIColor {
        switch self.type {
        case .Summary: return UIColor.blueColor()
        case .DeadZone: return UIColor.grayColor()

        case .TransmissionUntracked: return UIColor.yellowColor()
        case .TransmissionTracked: return UIColor(red: 0.6, green: 1, blue: 0.6, alpha: 0.5)
        case .TransmissionSuccess: return UIColor.greenColor()
        case .TransmissionError: return UIColor.redColor()
        }
    }
    
    public override var hashValue: Int {
        get {
            var hash: Int = 0
            if let title = self.title {
                hash += title.hashValue
            }
            if let subtitle = self.subtitle {
                hash += subtitle.hashValue
            }
            hash += self.type.hashValue
            hash = 1234567 ^ hash ^ Int(100000 * self.coordinate.longitude) ^ Int(100000 * self.coordinate.latitude)
//            debugPrint(hash)
            return hash
        }
    }
    // Thanks to http://stackoverflow.com/questions/33319959/nsobject-subclass-in-swift-hash-vs-hashvalue-isequal-vs
    override public func isEqual(object: AnyObject?) -> Bool {
        if let other = object as? SampleAnnotation {
            return self==other
        } else {
            return false
        }
    }
}
func dEq(a: Double, b: Double) -> Bool {
    return fabs(a - b) < DBL_EPSILON
}
public func ==(lhs: SampleAnnotation, rhs: SampleAnnotation) -> Bool {
    let eq = dEq(lhs.coordinate.latitude, b: rhs.coordinate.latitude) &&
            dEq(lhs.coordinate.longitude, b: rhs.coordinate.longitude) &&
            lhs.type==rhs.type
    return eq
}


extension MapViewController {
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        if let annotation = annotation as? SampleAnnotation {
            let identifier = "pin"
            var view: MKPinAnnotationView
            if let dequeuedView = mapView.dequeueReusableAnnotationViewWithIdentifier(identifier)
                as? MKPinAnnotationView { // 2
                dequeuedView.annotation = annotation
                view = dequeuedView
            } else {
                // 3
                view = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                view.canShowCallout = true
                view.calloutOffset = CGPoint(x: -5, y: 5)
                view.rightCalloutAccessoryView = UIButton(type: .DetailDisclosure)
            }
            view.pinTintColor = annotation.pinTintColor()
            return view
        }
        return nil
    }
}
