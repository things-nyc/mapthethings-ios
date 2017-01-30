//
//  AppDelegate.swift
//  MapTheThings
//
//  Created by Frank on 2016/6/30.
//  Copyright © 2016 The Things Network New York. All rights reserved.
//

import UIKit
import CoreData
import Fabric
import Crashlytics

class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var timer: NSTimer?
    var loader: SampleLoader?
    var bluetooth: Bluetooth!
    var location: Location?
    var tracker: Tracking?
    var data: DataController?
    var provisioning: Provisioning?
    
    func onTick() {
        updateAppState { (old) -> AppState in
            var state = old
            state.now = NSDate()
            return state
        }
    }
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        Fabric.with([Crashlytics.self])

        self.timer = NSTimer(timeInterval: 1.0, target: self, selector: #selector(AppDelegate.onTick), userInfo: nil, repeats: true)
        NSRunLoop.currentRunLoop().addTimer(timer!, forMode: NSRunLoopCommonModes)
        
        self.loader = SampleLoader()
        self.bluetooth = Bluetooth(savedIdentifiers: [])
        self.location = Location()
        self.data = DataController()
        self.tracker = Tracking(bluetooth: self.bluetooth, dataController: self.data!)
        self.provisioning = Provisioning()
        
        Transmission.loadTransmissions(self.data!)

        if let fakeDevice = (NSBundle.mainBundle().objectForInfoDictionaryKey("FakeDevice") as? NSNumber)?.unsignedIntegerValue
            where fakeDevice>0 {
            for _ in 1...fakeDevice {
                self.bluetooth.addFakeNode()
            }
        }
       
        return true
    }

    func application(application: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        if let source = options[UIApplicationOpenURLOptionsKey.sourceApplication] as? String,
            (source == "com.apple.SafariViewService") {
            if (url.host == "oauth-callback") {
//                OAuthSwift.handle(url: url)
                return true
            }
        }
        return false
    }
    
    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}

