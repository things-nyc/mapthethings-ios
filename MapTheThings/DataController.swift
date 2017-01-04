//
//  DataController.swift
//  MapTheThings
//
//  Created by Frank on 2017/1/1.
//  Copyright © 2017 The Things Network New York. All rights reserved.
//

import UIKit
import CoreData

public class DataController: NSObject {
    
    let managedObjectContext: NSManagedObjectContext
    
    override init() {
        // This resource is the same name as your xcdatamodeld contained in your project.
        guard let modelURL = NSBundle.mainBundle().URLForResource("DataModel", withExtension:"momd")
        else {
            fatalError("Error loading model from bundle")
        }
        
        // The managed object model for the application. It is a fatal error for the application not to be able to find and load its model.
        guard let mom = NSManagedObjectModel(contentsOfURL: modelURL)
        else {
            fatalError("Error initializing mom from: \(modelURL)")
        }
        let psc = NSPersistentStoreCoordinator(managedObjectModel: mom)
        managedObjectContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = psc
        managedObjectContext.performBlock {
            let urls = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
            let docURL = urls[urls.endIndex-1]
            /* The directory the application uses to store the Core Data store file.
             This code uses a file named "DataModel.sqlite" in the application's documents directory.
             */
            let storeURL = docURL.URLByAppendingPathComponent("DataModel.sqlite")
            do {
                try psc.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: storeURL, options: nil)
            } catch {
                fatalError("Error migrating store: \(error)")
            }
        }
    }
    
    public func performInContext(block: (moc: NSManagedObjectContext) -> Void) {
        managedObjectContext.performBlock { 
            block(moc: self.managedObjectContext)
        }
    }
}

/* Performs get block on NSManagedObjectContext queue and returns result on synchronously.
 If get block throws an exception, this function rethrows the same exception to the caller. */
public func performAndWaitInContext<T : Any>(moc: NSManagedObjectContext, get: () throws -> T) throws -> T {
    var result: T?
    var throwError: ErrorType?
    print("performBlockAndWait: \(String(UTF8String: dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL))!)")
    moc.performBlockAndWait {
        print("performBlockAndWait: \(String(UTF8String: dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL))!)")
        do {
            result = try get()
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
