//
//  DeviceViewController.swift
//  MapTheThings
//
//  Created by Frank on 2016/6/30.
//  Copyright © 2016 The Things Network New York. All rights reserved.
//

import UIKit
import CoreLocation

extension NSData {
    
    func hexadecimalString() -> String? {
        let buffer = UnsafePointer<UInt8>(self.bytes)
        if buffer == nil {
            return nil
        }
        
        var hexadecimalString = ""
        for i in 0..<self.length {
            hexadecimalString += String(format: "%02x", buffer.advancedBy(i).memory)
        }
        return hexadecimalString.uppercaseString
    }
}

func stringFromTimeInterval(interval:NSTimeInterval) -> String {
    
    let ti = NSInteger(interval)
    
    //let ms = Int((interval % 1) * 1000)
    
    let seconds = ti % 60
    let minutes = (ti / 60) % 60
    let hours = (ti / 3600)
    
    //return NSString(format: "%0.2d:%0.2d:%0.2d.%0.3d",hours,minutes,seconds,ms) as String
    return String(format: "%0.2d:%0.2d:%0.2d",hours,minutes,seconds)
}

class DeviceViewController: AppStateUIViewController {
    @IBOutlet var devAddr: UITextField!
    @IBOutlet var nwkSKey: UITextField!
    @IBOutlet var appSKey: UITextField!
    @IBOutlet var connected: UITextField!
    @IBOutlet var lastLocation: UITextField!
    @IBOutlet var lastTimestamp: UITextField!
    @IBOutlet var lastAccuracy: UITextField!
    @IBOutlet var lastPacket: UITextField!
    @IBOutlet var batteryLevel: UITextField!
    @IBOutlet var spreadingFactor: UISegmentedControl!
    @IBOutlet var debugView: UITextView!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    @IBAction func sendPacket(sender: UIButton) {
        debugPrint("sendPacket")
        updateAppState { (old) -> AppState in
            var state = old
            state.sendPacket = NSUUID() // Each press of command
            return state
        }
    }

    @IBAction func sendTestPacket(sender: UIButton) {
        debugPrint("sendTestPacket")
        updateAppState { (old) -> AppState in
            var state = old
            if state.map.currentLocation==nil {
                state.map.currentLocation = CLLocation(latitude: 10, longitude: 10)
            }
            state.sendPacket = NSUUID() // Each press of command
            return state
        }
    }
    
    @IBAction func reconnectBluetooth(sender: UIButton) {
        debugPrint("reconnectBluetooth")
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        appDelegate.bluetooth!.rescan()
    }
    
    @IBAction func spreadingFactorChange(sender: UISegmentedControl) {
        debugPrint("setSF: ", sender.selectedSegmentIndex)
        updateAppState { (old) -> AppState in
            if var dev = old.bluetooth.first?.1 {
                var state = old
                dev.spreadingFactor = UInt8(sender.selectedSegmentIndex) + 7
                state.bluetooth[dev.identifier] = dev
                return state
            }
            else {
                return old
            }
        }
    }
    
    override func renderAppState(oldState: AppState, state: AppState) {
        // Update UI according to app state
        if let dev = state.bluetooth.first?.1 {
            if let devAddr = dev.devAddr {
                self.devAddr.text = devAddr.hexadecimalString()
            }
            if let newSKey = dev.nwkSKey {
                self.nwkSKey.text = newSKey.hexadecimalString()
            }
            if let appSKey = dev.appSKey {
                self.appSKey.text = appSKey.hexadecimalString()
            }
            if let lastLocation = dev.lastLocation {
                self.lastLocation.text = String(format: "%0.5f, %0.5f", lastLocation.coordinate.latitude, lastLocation.coordinate.longitude)
                self.lastTimestamp.text = stringFromTimeInterval(-lastLocation.timestamp.timeIntervalSinceNow) + " ago"
                self.lastAccuracy.text = "\(lastLocation.horizontalAccuracy)"
            }
            if let lastPacket = dev.lastPacket {
                self.lastPacket.text = lastPacket.hexadecimalString()
            }
            self.batteryLevel.text = dev.battery.description
            self.connected.text = dev.connected.description
            if let sf = dev.spreadingFactor {
                self.spreadingFactor.selectedSegmentIndex = Int(sf) - 7
            }
            
            var text = "Debug View\n"
            if let currentLocation = state.map.currentLocation {
                let locAge = fabs(currentLocation.timestamp.timeIntervalSinceNow)
                text += "Location age: \(stringFromTimeInterval(locAge))\n"
                let isCurrentLocation = locAge < CURRENT_LOCATION_EXPIRY
                text += "Location is current: \(isCurrentLocation)\n"
                
                if let lastLocation = dev.lastLocation {
                    let d = lastLocation.distanceFromLocation(currentLocation) // in meters
                    text += String(format: "Distance (sent vs latest): %0.1f meters\n", d)
                    let t = lastLocation.timestamp.timeIntervalSinceDate(currentLocation.timestamp)
                    text += "Time (sent vs latest): \(stringFromTimeInterval(fabs(t)))\n"
                }

            }
            else {
                text += "No current location"
            }
            text = text + "\n\n"
            text = dev.log.reduce(text) {(t, l) -> String in return t + l }
            self.debugView?.text = text
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

