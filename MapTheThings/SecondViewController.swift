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

class DeviceViewController: AppStateUIViewController {
    @IBOutlet var devAddr: UITextField!
    @IBOutlet var nwkSKey: UITextField!
    @IBOutlet var appSKey: UITextField!
    @IBOutlet var connected: UITextField!
    @IBOutlet var lastLocation: UITextField!
    @IBOutlet var lastTimestamp: UITextField!
    @IBOutlet var lastAccuracy: UITextField!
    @IBOutlet var lastPacket: UITextField!

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
                self.lastLocation.text = "\(lastLocation.coordinate.latitude),\(lastLocation.coordinate.longitude)"
                self.lastTimestamp.text = lastLocation.timestamp.description
                self.lastAccuracy.text = "\(lastLocation.horizontalAccuracy)"
            }
            if let lastPacket = dev.lastPacket {
                self.lastPacket.text = lastPacket.hexadecimalString()
            }
            self.connected.text = dev.connected.description
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

