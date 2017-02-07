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
import Alamofire
import PromiseKit
import ReactiveSwift

open class Transmission: NSManagedObject {
    @NSManaged var created: Date

    @NSManaged var latitude: Double
    @NSManaged var longitude: Double
    @NSManaged var altitude: Double
    @NSManaged var packet: Data?

    // When node reports transmission, store seq_no
    @NSManaged var dev_eui: String
    @NSManaged var seq_no: NSNumber?

    // Date transmission was stored at server
    @NSManaged var synced: Date?
    
    static var syncWorkDisposer: Disposable?
    static var syncDisposer: Disposable?
    static var recordWorkDisposer: Disposable?
    static var recordDisposer: Disposable?
    
    override open func awakeFromInsert() {
        super.awakeFromInsert()
        created = Date()
    }
    
    open static func create(
        _ dataController: DataController,
        latitude: Double, longitude: Double, altitude: Double,
        packet: Data, device: UUID
        ) throws -> Transmission {
        return try dataController.performAndWaitInContext() { moc in
            let tx = NSEntityDescription.insertNewObject(forEntityName: "Transmission", into: moc) as! Transmission
            tx.latitude = latitude
            tx.longitude = longitude
            tx.altitude = altitude
            tx.packet = packet
            tx.dev_eui = device.uuidString
            tx.seq_no = nil
            try moc.save()
            return tx
        }
    }
    
    open static func loadTransmissions(_ data: DataController) {
        // NOTE: The following code represents a pattern regarding idempotency of work
        // that is emerging in the AppState logic. I expect I'll add some code to 
        // explicitly support the pattern when I get a chance.
        
        // Recognize that there is work to do and flag that it should happen
        self.syncWorkDisposer = appStateObservable.observeValues { signal in
            if (!signal.new.syncState.syncWorking
                && signal.new.syncState.syncPendingCount>0) {
                // Don't just start async work here. There's a chance with 
                // multiple enqueued updates to AppState that this method will be called 
                // many times in the same state of needing to start work. We wouldn't want to 
                // start doing the same work every time.
                updateAppState({ (old) -> AppState in
                    var state = old
                    state.syncState.syncWorking = true
                    return state
                })
            }
        }
        
        // Recognize that the work flag went up and do the work.
        self.syncDisposer = appStateObservable.observeValues { signal in
            if (!signal.old.syncState.syncWorking && signal.new.syncState.syncWorking) {
                syncOneTransmission(data, host: signal.new.host)
                //debugPrint("Sync one: \(signal.new.syncState)")
            }
        }

        // Recognize that there is work to do and flag that it should happen
        self.recordWorkDisposer = appStateObservable.observeValues { signal in
            if (!signal.new.syncState.recordWorking
                && signal.new.syncState.recordLoraToObject.count>0) {
                updateAppState({ (old) -> AppState in
                    var state = old
                    state.syncState.recordWorking = true
                    return state
                })
            }
        }
        
        // Recognize that the work flag went up and do the work.
        self.recordDisposer = appStateObservable.observeValues { signal in
            if (!signal.old.syncState.recordWorking && signal.new.syncState.recordWorking) {
                //debugPrint("Record one: \(signal.new.syncState)")
                recordOneLoraSeqNo(data, update: signal.new.syncState.recordLoraToObject)
            }
        }

        data.performInContext() { moc in
            do {
                let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: "Transmission")
                let calendar = Calendar.autoupdatingCurrent
                let now = Date()
                if let earlier = (calendar as NSCalendar).date(byAdding: .hour, value: -8, to: now, options: []) {
                    fetch.predicate = NSPredicate(format: "created > %@", earlier as CVarArg)
                    let transmissions = try moc.fetch(fetch) as! [Transmission]
                    let samples = transmissions.map { (tx) in
                        return TransSample(location: CLLocationCoordinate2D(latitude: tx.latitude, longitude: tx.longitude), altitude: tx.altitude, timestamp: tx.created,
                            device: nil, ble_seq: nil, // Not live transmission, so nil OK
                            lora_seq: tx.seq_no?.uint32Value, objectID: nil)
                    }
                    
                    updateAppState({ (old) -> AppState in
                        var state = old
                        state.map.transmissions = samples
                        return state
                    })
                }
 
                fetch.predicate = NSPredicate(format: "synced = nil and seq_no != nil")
                let syncReady = try moc.count(for: fetch)
                updateAppState { old in
                    var state = old
                    state.syncState.syncPendingCount = syncReady
                    return state
                }
                fetch.predicate = NSPredicate(format: "synced = nil")
                let unsynced = try moc.count(for: fetch)
                debugPrint("Transmissions without node confirmation: \(unsynced)")
            }
            catch let error as NSError {
                setAppError(error, fn: "loadTransmissions", domain: "database")
            }
            catch let error {
                let nserr = NSError(domain: "database", code: 1, userInfo: [NSLocalizedDescriptionKey: "\(error)"])
                setAppError(nserr, fn: "loadTransmissions", domain: "database")
            }
        }
    }
    
    static func recordOneLoraSeqNo(_ data: DataController, update: [(NSManagedObjectID, UInt32)]) {
        if (update.isEmpty) {
            return
        }
        data.performInContext() { moc in
            let (objID, loraSeq) = update.first!
            do {
                let tx = try moc.existingObject(with: objID) as! Transmission
                tx.seq_no = NSNumber(value: loraSeq)
                try moc.save()
            }
            catch let error as NSError {
                setAppError(error, fn: "applicationDidFinishLaunchingWithOptions", domain: "database")
            }
            catch let error {
                let nserr = NSError(domain: "database", code: 1, userInfo: [NSLocalizedDescriptionKey: "\(error)"])
                setAppError(nserr, fn: "applicationDidFinishLaunchingWithOptions", domain: "database")
            }
            updateAppState({ (old) -> AppState in
                var state = old
                state.syncState.recordWorking = false
                state.syncState.recordLoraToObject = state.syncState.recordLoraToObject.filter({ pair -> Bool in
                    return pair.0 != objID
                })
                return state
            })
        }
    }
    
    static func formatterForJSONDate() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }

    open static func syncOneTransmission(_ data: DataController, host: String) {
        data.performInContext() { moc in
            do {
                let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: "Transmission")
                fetch.predicate = NSPredicate(format: "synced = nil and seq_no != nil")
                fetch.fetchLimit = 1
                let transmissions = try moc.fetch(fetch) as! [Transmission]
                if (transmissions.count>=1) {
                    postTransmission(transmissions[0], data: data, host: host)
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

    open static func postTransmission(_ tx: Transmission, data: DataController, host: String) {
        let formatter = formatterForJSONDate()
        let params = Promise<[String:AnyObject]>{ fulfill, reject in
            data.performInContext() { _ in
                // Access database object within moc queue
                let parameters = [
                    "lat": tx.latitude,
                    "lon": tx.longitude,
                    "alt": tx.altitude,
                    "timestamp": formatter.string(from: tx.created),
                    "dev_eui": tx.dev_eui,
                    "msg_seq": tx.seq_no!,
                ] as [String : Any]
                fulfill(parameters as [String : AnyObject])
            }
        }
        params.then { parameters -> Promise<NSDictionary> in
            //debugPrint("Params: \(parameters)")
            let url = "http://\(host)/api/v0/transmissions"
            debugPrint("URL: \(url)")
            let rsp = Promise<NSDictionary> { fulfill, reject in
                request(url, method: .post,
                    parameters: parameters,
                    encoding: JSONEncoding())
                .responseJSON(queue: nil, options: .allowFragments, completionHandler: { response in
                    switch response.result {
                    case .success(let value):
                        fulfill(value as! NSDictionary)
                    case .failure(let error):
                        reject(error)
                    }
                })
            }
            return rsp
        }.then { jsonResponse -> Void in
            //debugPrint(jsonResponse)
            // Write sync time to tx
            try data.performAndWaitInContext() { moc in
                let now = Date()
                tx.synced = now
                try moc.save()
                updateAppState({ (old) -> AppState in
                    var state = old
                    state.syncState.lastPost = now
                    if (state.syncState.syncPendingCount>0) {
                        state.syncState.syncPendingCount -= 1;
                    }
                    state.syncState.syncWorking = false
                    return state
                })
            }
        }.catch { (error) in
            debugPrint("\(error)")
            setAppError(error, fn: "postTransmission", domain: "web")
            updateAppState({ (old) -> AppState in
                var state = old
                state.syncState.lastPost = Date()
                state.syncState.syncWorking = false
                return state
            })
        }
    }
}
