//
//  MapAnnotations.swift
//  MapTheThings
//
//  Created by Frank on 2016/7/12.
//  Copyright © 2016 The Things Network New York. All rights reserved.
//

import MapKit

public enum SampleAnnotationType {
    case summary
    case deadZone

    case transmissionUntracked
    case transmissionTracked
    case transmissionSuccess
    case transmissionError
}

open class SampleAnnotation : NSObject, MKAnnotation {
    open let title: String?
    open let subtitle: String?
    open let coordinate: CLLocationCoordinate2D
    open let type: SampleAnnotationType
    let image: UIImage?
    
    public init(coordinate: CLLocationCoordinate2D,
                type: SampleAnnotationType,
                details: String,
                image: UIImage? = nil) {
        self.subtitle = details
        self.coordinate = coordinate
        self.type = type
        self.image = image
        
        var title: String
        switch self.type {
        case .summary: title = "Summary"
        case .deadZone: title = "Dead Zone"
            
        case .transmissionUntracked: title = "Untracked"
        case .transmissionTracked: title = "Tracked"
        case .transmissionSuccess: title = "Success"
        case .transmissionError: title = "Error"
        }
        self.title = title
        
        super.init()
    }
    
    public func isLocal() -> Bool {
        return !(self.type == SampleAnnotationType.summary || self.type == SampleAnnotationType.deadZone)
    }
    
    public convenience init(sample s: Sample) {
        var image: UIImage = SampleAnnotation.deadZoneImage
        var typ = SampleAnnotationType.summary
        if (s.attempts>0 && s.count==0) {
            typ = SampleAnnotationType.deadZone
        }
        else {
            // SNR (dBm): -20 (Red) -11 (Orange) -4 (Green)
            
            if (s.snr >= -4.0) {
                image = SampleAnnotation.highSnrImage
            }
            else if (s.snr >= -11.0) {
                image = SampleAnnotation.mediumSnrImage
            }
            else {
                image = SampleAnnotation.lowSnrImage
            }
        }
        let details = "\(s.count) packets. \(s.snr) SNR."
        
        self.init(coordinate: s.location, type: typ, details: details, image: image)
    }
    
    public convenience init(transSample s: TransSample) {
        var type: SampleAnnotationType
        var details: String
        if s.ble_seq==nil {
            type = SampleAnnotationType.transmissionUntracked
            details = "Untracked"
        }
        else if s.lora_seq==nil {
            type = SampleAnnotationType.transmissionTracked
            details = "Tracked"
        }
        else {
            type = SampleAnnotationType.transmissionSuccess
            details = "Sent"
        }
        self.init(coordinate: s.location, type: type, details:details)
    }

    open func pinTintColor() -> UIColor {
        switch self.type {
        case .summary: return UIColor.blue
        case .deadZone: return UIColor.gray

        case .transmissionUntracked: return UIColor.yellow
        case .transmissionTracked: return UIColor(red: 0.6, green: 1, blue: 0.6, alpha: 0.5)
        case .transmissionSuccess: return UIColor.green
        case .transmissionError: return UIColor.red
        }
    }
    
    open override var hashValue: Int {
        get {
            var hash: Int = 0
            if let title = self.title {
                hash ^= title.hashValue
            }
            if let subtitle = self.subtitle {
                hash ^= subtitle.hashValue
            }
            hash ^= self.type.hashValue
            hash ^= Int(100000 * self.coordinate.longitude)
            hash ^= Int(100000 * self.coordinate.latitude)
            // debugPrint(hash)
            return hash
        }
    }
    // Thanks to http://stackoverflow.com/questions/33319959/nsobject-subclass-in-swift-hash-vs-hashvalue-isequal-vs
    override open func isEqual(_ object: Any?) -> Bool {
        if let other = object as? SampleAnnotation {
            return self==other
        } else {
            return false
        }
    }
    
    static func createMarker(color: UIColor) -> UIImage {
        let size = 30.0
        UIGraphicsBeginImageContextWithOptions(CGSize(width: size, height: size), false, 0)
        let ctx = UIGraphicsGetCurrentContext()!
        ctx.saveGState()
        
        StyleKit.drawMapSampleMarker(annotationColor: color)
        
        ctx.restoreGState()
        let img = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return img
    }
    
    static let deadZoneImage = createMarker(color: UIColor.gray)
    static let highSnrImage = createMarker(color: StyleKit.highSNR)
    static let mediumSnrImage = createMarker(color: StyleKit.mediumSNR)
    static let lowSnrImage = createMarker(color: StyleKit.lowSNR)
}
func dEq(_ a: Double, b: Double) -> Bool {
    return fabs(a - b) < DBL_EPSILON
}
public func ==(lhs: SampleAnnotation, rhs: SampleAnnotation) -> Bool {
    let eq = dEq(lhs.coordinate.latitude, b: rhs.coordinate.latitude) &&
            dEq(lhs.coordinate.longitude, b: rhs.coordinate.longitude) &&
            lhs.type==rhs.type
    return eq
}

extension MapViewController {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if let annotation = annotation as? SampleAnnotation {
            if annotation.isLocal() {
                let identifier = "pin"
                var view: MKPinAnnotationView
                if let dequeuedView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                    as? MKPinAnnotationView {
                    dequeuedView.annotation = annotation
                    view = dequeuedView
                } else {
                    // 3
                    view = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    view.canShowCallout = true
                    view.calloutOffset = CGPoint(x: -5, y: 5)
//                    view.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
                }
                view.pinTintColor = annotation.pinTintColor()
                return view
            }
            else {
                let identifier = "sample"
                var view: MKAnnotationView
                if let dequeuedView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) {
                    dequeuedView.annotation = annotation
                    view = dequeuedView
                } else {
                    // 3
                    view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    view.canShowCallout = true
                    view.calloutOffset = CGPoint(x: -5, y: 5)
//                    view.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
                }
                view.image = annotation.image
                return view
            }
        }
        return nil
    }
}
