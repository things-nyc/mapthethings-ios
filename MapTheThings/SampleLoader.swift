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
//import ReactiveCocoa

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
//    var boundsDisposer: Disposable?
    
    init() {
//        self.boundsDisposer =
        appStateObservable.observeNext({state in
            self.checkBoundsChanged(state.new.map.bounds, host: state.new.host)
        })
    }
    
    private func checkBoundsChanged(bounds: Edges, host: String) {
        if let last = self.lastBounds where (last.ne == bounds.ne && last.sw == bounds.sw) {
            return
        }
        lastBounds = bounds
        load(bounds, host: host)
    }
    
    private func load(bounds: Edges, host: String) {
        let fmt =  { (x: Double) -> (String) in return String(format: "%0.6f", x) }
        let apiurl = "http://\(host)/api/v0/grids" +
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
                self.gotSamples(allSamples)
            }

            self.gotCells(gridUrls)
        }
    }
    
    private func loadGrid(gridUrl: NSURL) -> Promise<Array<Sample>> {
        //debugPrint("loadGrid(\(gridUrl))")
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

                    let count = (cell["count"] as! NSNumber).intValue
                    let attempts = (cell["attempt-cnt"] as! NSNumber).intValue
                    
                    // timestamp = cell["timestamp"]
                    let s = Sample(count: count, attempts: attempts,
                        location: CLLocationCoordinate2D(latitude: clat, longitude: clon),
                        rssi: rssi, snr: snr,
                        timestamp: nil)
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
    
    private func hashToGridCell(hash: String) -> GridCell {
        let hexhash = hash.substringFromIndex(hash.startIndex.advancedBy(1))

        // Based on https://github.com/kungfoo/geohash-java/blob/master/src/main/java/ch/hsr/geohash/GeoHash.java#L95
        
        func divideRangeDecode(range: [Double], b: Bool) -> [Double] {
            let mid = (range[0] + range[1]) / 2.0;
            if (b) {
//                hash.addOnBitToEnd();
                return [mid, range[1]]
            } else {
//                hash.addOffBitToEnd();
                return [range[0], mid]
            }
        }

        let startLatitudeRange = [ -90.0, 90.0 ]
        let startLongitudeRange = [ -180.0, 180.0 ]
        var isEvenBit = true;
        // TODO: have to prefix binary string with 0 bits as determined by hash prefix character
        let (latitudeRange, longitudeRange) = hexhash.characters.reduce(
            (startLatitudeRange, startLongitudeRange),
            combine: { (latLon, hexChar) -> ([Double], [Double]) in
            let cd = Int("\(hexChar)", radix: 16)!
            var latitudeRange = latLon.0
            var longitudeRange = latLon.1
            for j in (0...3).reverse() {
                let mask = 1 << j
                if (isEvenBit) {
                    longitudeRange = divideRangeDecode(longitudeRange, b: (cd & mask) != 0)
                } else {
                    latitudeRange = divideRangeDecode(latitudeRange, b: (cd & mask) != 0)
                }
                isEvenBit = !isEvenBit;
            }
            return (latitudeRange, longitudeRange)
        })

//        let latitude = (latitudeRange[0] + latitudeRange[1]) / 2.0;
//        let longitude = (longitudeRange[0] + longitudeRange[1]) / 2.0;

//        debugPrint("Hex \(hexhash) resolves to \(latitudeRange) vs \(longitudeRange)")
        let nw = CLLocationCoordinate2D(latitude: latitudeRange[1], longitude: longitudeRange[0])
        let se = CLLocationCoordinate2D(latitude: latitudeRange[0], longitude: longitudeRange[1])
        return GridCell(nw: nw, se: se)
    }
    
    private func gotCells(urls: [AnyObject]) {
        let cells = urls.map({ (gridUrl: Any) -> GridCell in
            let gridUrlString = gridUrl as! String
            // https://s3.amazonaws.com/nyc.thethings.map.grids/ED2791W-v0
            let regex = try! NSRegularExpression(pattern: "/([^/]+)-v\\d$", options: [])
            let matches = regex.matchesInString(gridUrlString,
                options: [], range: NSMakeRange(0, gridUrlString.characters.count))
            let range = matches.first!.rangeAtIndex(1) // Group
            let r = gridUrlString.startIndex.advancedBy(range.location) ..<
                gridUrlString.startIndex.advancedBy(range.location+range.length)
            let hash = String(gridUrlString.substringWithRange(r).characters.reverse())
            return self.hashToGridCell(hash)
        })
        updateAppState { (old) -> AppState in
            var state = old
            state.map.cells = cells
            return state
        }
    }
    
    private func gotSamples(samples: Array<Sample>) {
        updateAppState { (old) -> AppState in
            var state = old
            state.map.samples = samples
            return state
        }
    }
}
