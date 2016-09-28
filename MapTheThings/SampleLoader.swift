//
//  SampleLoader.swift
//  MapTheThings
//
//  Created by Frank on 2016/7/6.
//  Copyright © 2016 The Things Network New York. All rights reserved.
//

import Foundation
import CoreLocation
import Haneke
import PromiseKit

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
    let jsonCache = Cache<JSON>(name: "SampleLoader")
    
    init() {
        appStateObservable.observeNext({state in
            self.checkBoundsChanged(state.new.map.bounds)
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
            "/\(fmt(bounds.ne.latitude))/\(fmt(bounds.sw.longitude))" +
            "/\(fmt(bounds.sw.latitude))/\(fmt(bounds.ne.longitude))"
        debugPrint("Fetching grids for \(apiurl)")
        let requestURL: NSURL = NSURL(string: apiurl)!
        jsonCache.fetch(URL: requestURL).onSuccess { json in
            //debugPrint("JSON", json)
            let gridUrls = json.array
            let sampleLists = gridUrls.map({ (gridUrl: Any) -> (Promise<Array<Sample>>) in
                let gridUrlString = gridUrl as! String
                let requestURL: NSURL = NSURL(string: gridUrlString)!
                return self.loadGrid(requestURL)
            })
            when(sampleLists).then { (lists) -> (Void) in
                let allSamples = lists.reduce([Sample](), combine: { all, list in
                    return all + list
                })
                self.gotSamples(requestURL, samples: allSamples)
            }
        }
    }
    
    private func loadGrid(gridUrl: NSURL) -> Promise<Array<Sample>> {
        return Promise { fulfill, reject in
            jsonCache.fetch(URL: gridUrl).onSuccess { json in
                //debugPrint("JSON Grid", json)
                let cells = json.dictionary["cells"]! as! [String : AnyObject]
                let samples = cells.reduce([], combine: { (r: Array<Sample>, c: (String, AnyObject)) -> Array<Sample> in
                    let cell = c.1
                    let clat = (cell["clat"] as! NSNumber).doubleValue
                    let clon = (cell["clon"] as! NSNumber).doubleValue
                    let rssiStats = cell["rssi"] as! [String : AnyObject]
                    let snrStats = cell["lsnr"] as! [String : AnyObject]
                    let rssi = (rssiStats["avg"] as! NSNumber).floatValue
                    let snr = (snrStats["avg"] as! NSNumber).floatValue
                    let s = Sample(location: CLLocationCoordinate2D(latitude: clat, longitude: clon), rssi: rssi, snr: snr, timestamp: nil, seqno: nil)
                    return r + [s]
                })
                fulfill(samples)
            }.onFailure({ (error) in
                if (error?.code == -402) {
                    fulfill([Sample]())
                }
                else {
                    reject(error!)
                }
            })
        }
    }
    
    private func gotSamples(gridUrl: NSURL, samples: Array<Sample>) {
        updateAppState { (old) -> AppState in
            var state = old
            state.map.samples = samples
            return state
        }
    }
}