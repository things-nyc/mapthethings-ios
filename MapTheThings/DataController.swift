//
//  DataController.swift
//  MapTheThings
//
//  Created by Frank on 2017/1/1.
//  Copyright © 2017 The Things Network New York. All rights reserved.
//

import UIKit
import CoreData

open class DataController: NSObject {
    
    let managedObjectContext: NSManagedObjectContext
    
    override init() {
        // This resource is the same name as your xcdatamodeld contained in your project.
        guard let modelURL = Bundle.main.url(forResource: "DataModel", withExtension:"momd")
        else {
            fatalError("Error loading model from bundle")
        }
        
        // The managed object model for the application. It is a fatal error for the application not to be able to find and load its model.
        guard let mom = NSManagedObjectModel(contentsOf: modelURL)
        else {
            fatalError("Error initializing mom from: \(modelURL)")
        }
        let psc = NSPersistentStoreCoordinator(managedObjectModel: mom)
        managedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = psc
        managedObjectContext.perform {
            let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            let docURL = urls[urls.endIndex-1]
            /* The directory the application uses to store the Core Data store file.
             This code uses a file named "DataModel.sqlite" in the application's documents directory.
             */
            let storeURL = docURL.appendingPathComponent("DataModel.sqlite")
            do {
                try psc.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: nil)
            } catch {
                fatalError("Error migrating store: \(error)")
            }
        }
    }
    
    open func performInContext(_ block: @escaping (_ moc: NSManagedObjectContext) -> Void) {
        managedObjectContext.perform { 
            block(self.managedObjectContext)
        }
    }
    
    func currentQueueName() -> String? {
        let name = __dispatch_queue_get_label(nil)
        return String(cString: name, encoding: .utf8)
    }

    /* Performs get block on NSManagedObjectContext queue and returns result on synchronously.
     If get block throws an exception, this function rethrows the same exception to the caller. */
    open func performAndWaitInContext<T : Any>(_ get: @escaping (_ moc: NSManagedObjectContext) throws -> T) throws -> T {
        var result: T?
        var throwError: Error?
        print("performBlockAndWait outer: \(self.currentQueueName())")
        managedObjectContext.performAndWait {
            print("performBlockAndWait inner: \(self.currentQueueName())")
            do {
                result = try get(self.managedObjectContext)
            }
            catch let error {
                throwError = error
            }
        }
        if let error = throwError {
            throw error
        }
        return result!
    }
}
