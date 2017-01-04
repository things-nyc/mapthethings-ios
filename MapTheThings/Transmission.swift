//
//  Transmission.swift
//  MapTheThings
//
//  Created by Frank on 2017/1/1.
//  Copyright © 2017 The Things Network New York. All rights reserved.
//

import CoreData
import Foundation
import MapKit

public class Transmission: NSManagedObject {
    @NSManaged var created: NSDate

    @NSManaged var latitude: Double
    @NSManaged var longitude: Double
    @NSManaged var altitude: Double
    @NSManaged var packet: NSData?

    // When node reports transmission, store seq_no
    @NSManaged var dev_eui: String
    @NSManaged var seq_no: NSNumber?

    // Date transmission was stored at server
    @NSManaged var synced: NSDate?
    
    override public func awakeFromInsert() {
        super.awakeFromInsert()
        created = NSDate()
    }
    
    public static func create(
        moc: NSManagedObjectContext,
        latitude: Double, longitude: Double, altitude: Double,
        packet: NSData, device: NSUUID
        ) throws -> Transmission {
        return try performAndWaitInContext(moc) {
            let tx = NSEntityDescription.insertNewObjectForEntityForName("Transmission", inManagedObjectContext: moc) as! Transmission
            tx.latitude = latitude
            tx.longitude = longitude
            tx.altitude = altitude
            tx.packet = packet
            tx.dev_eui = device.UUIDString
            try moc.save()
            return tx
        }
    }
    
    public static func loadTransmissions(data: DataController) {
        data.performInContext() { moc in
            do {
                let fetch = NSFetchRequest(entityName: "Transmission")
                let calendar = NSCalendar.autoupdatingCurrentCalendar()
                let now = NSDate()
                if let earlier = calendar.dateByAddingUnit(.Hour, value: -8, toDate: now, options: []) {
                    //fetch.predicate = NSPredicate(format: "created > %@", earlier)
                    let transmissions = try moc.executeFetchRequest(fetch) as! [Transmission]
                    let samples = transmissions.map { (tx) in
                        return TransSample(location: CLLocationCoordinate2D(latitude: tx.latitude, longitude: tx.longitude), altitude: tx.altitude, timestamp: tx.created)
                    }
                    updateAppState({ (old) -> AppState in
                        var state = old
                        state.map.transmissions = samples
                        return state
                    })
                }
            }
            catch let error as NSError {
                setAppError(error, fn: "applicationDidFinishLaunchingWithOptions", domain: "database")
            }
            catch let error {
                let nserr = NSError(domain: "database", code: 1, userInfo: [NSLocalizedDescriptionKey: "\(error)"])
                setAppError(nserr, fn: "applicationDidFinishLaunchingWithOptions", domain: "database")
            }
        }
    }
}
