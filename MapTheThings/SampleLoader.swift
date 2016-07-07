//
//  SampleLoader.swift
//  MapTheThings
//
//  Created by Frank on 2016/7/6.
//  Copyright © 2016 The Things Network New York. All rights reserved.
//

import Foundation
import CoreLocation

func == <T:Equatable> (tuple1:(T,T),tuple2:(T,T)) -> Bool
{
    return (tuple1.0 == tuple2.0) && (tuple1.1 == tuple2.1)
}

let COORD_EPSILON = 0.000001
func == (a: CLLocationCoordinate2D, b: CLLocationCoordinate2D) -> Bool
{
    return fabs(a.latitude - b.latitude) < COORD_EPSILON && fabs(a.longitude - b.longitude) < COORD_EPSILON
}

class SampleLoader {
    var lastBounds: Edges?
    
    init() {
        appStateObservable.observeNext({state in
            self.checkBoundsChanged(state.map.bounds)
        })
    }
    
    private func checkBoundsChanged(bounds: Edges) {
        if let last = self.lastBounds where (last.ne == bounds.ne && last.sw == bounds.sw) {
            return
        }
        lastBounds = bounds
        load(bounds)
    }
    
    private func load(bounds: Edges) {
        let fmt =  { (x: Double) -> (String) in return String(format: "%0.6f", x) }
        let apiurl = "http://map.thethings.nyc/api/v0/grids" +
            "/\(fmt(bounds.ne.latitude))/\(fmt(bounds.ne.longitude))" +
            "/\(fmt(bounds.sw.latitude))/\(fmt(bounds.sw.longitude))"
        debugPrint(apiurl)
        let requestURL: NSURL = NSURL(string: apiurl)!
        let urlRequest: NSMutableURLRequest = NSMutableURLRequest(URL: requestURL)
        let session = NSURLSession.sharedSession()
        let task = session.dataTaskWithRequest(urlRequest) { (data, response, error) -> Void in
            
            let httpResponse = response as! NSHTTPURLResponse
            let statusCode = httpResponse.statusCode
            
            if (statusCode == 200) {
                do {
                    let json = try NSJSONSerialization.JSONObjectWithData(data!, options:.AllowFragments)
                    debugPrint("JSON", json)
                    let gridUrls: NSArray = json as! NSArray
                    gridUrls.forEach({ (gridUrl: Any) -> (Void) in
                        let gridUrlString = gridUrl as! String
                        let requestURL: NSURL = NSURL(string: gridUrlString)!
                        self.loadGrid(requestURL)
                    })
                }
                catch {
                    print("Error with grid array: \(error)")
                }
             }
            else {
                print("Error loading grid array: \(statusCode) \(httpResponse.description)")
            }
        }
        
        task.resume()
    }
    
    private func loadGrid(gridUrl: NSURL) {
        let urlRequest: NSMutableURLRequest = NSMutableURLRequest(URL: gridUrl)
        let session = NSURLSession.sharedSession()
        let task = session.dataTaskWithRequest(urlRequest) { (data, response, error) -> Void in
            if let err = error {
                print("Error loading grid \(gridUrl): \(err)")
                return
            }
            
            let httpResponse = response as! NSHTTPURLResponse
            let statusCode = httpResponse.statusCode
            
            if (statusCode == 200) {
                do {
                    let json = try NSJSONSerialization.JSONObjectWithData(data!, options:.AllowFragments)
                    //debugPrint("JSON Grid", json)
                    let cells = json["cells"]! as! [String : AnyObject]
                    for (_, cell) in cells {
                        let clat = (cell["clat"] as! NSNumber).doubleValue
                        let clon = (cell["clon"] as! NSNumber).doubleValue
                        let rssiStats = cell["rssi"] as! [String : AnyObject]
                        let snrStats = cell["lsnr"] as! [String : AnyObject]
                        let rssi = (rssiStats["avg"] as! NSNumber).floatValue
                        let snr = (snrStats["avg"] as! NSNumber).floatValue
                        let s = Sample(location: CLLocationCoordinate2D(latitude: clat, longitude: clon), rssi: rssi, snr: snr, timestamp: nil, seqno: nil)
                    }
                }
                catch {
                    print("Error parsing grid: \(error)")
                }
            }
            else if (statusCode == 404) {
                // We expect 404's
            }
            else {
                print("HTTP error loading grid: \(statusCode) \(httpResponse.description)")
            }
        }
        task.resume()
    }
}