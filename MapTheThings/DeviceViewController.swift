//
//  DeviceViewController.swift
//  MapTheThings
//
//  Created by Frank on 2016/6/30.
//  Copyright © 2016 The Things Network New York. All rights reserved.
//

import UIKit
import CoreLocation
import Crashlytics

extension Data {
    
    func hexadecimalString() -> String? {
        let buffer = (self as NSData).bytes.bindMemory(to: UInt8.self, capacity: self.count)
        
        var hexadecimalString = ""
        for i in 0..<self.count {
            hexadecimalString += String(format: "%02x", buffer.advanced(by: i).pointee)
        }
        return hexadecimalString.uppercased()
    }
}

func stringFromTimeInterval(_ interval:TimeInterval) -> String {
    
    let ti = NSInteger(interval)
    
    //let ms = Int((interval % 1) * 1000)
    
    let seconds = ti % 60
    let minutes = (ti / 60) % 60
    let hours = (ti / 3600)
    
    //return NSString(format: "%0.2d:%0.2d:%0.2d.%0.3d",hours,minutes,seconds,ms) as String
    return String(format: "%0.2d:%0.2d:%0.2d",hours,minutes,seconds)
}

class ProvisioningViewController: UITableViewController {
    @IBOutlet weak var devAddr: UILabel!
    @IBOutlet weak var nwkSKey: UILabel!
    @IBOutlet weak var appSKey: UILabel!

    @IBOutlet weak var appKey: UILabel!
    @IBOutlet weak var appEUI: UILabel!
    @IBOutlet weak var devEUI: UILabel!
}

class StatusViewController: UITableViewController {
    @IBOutlet weak var connected: UILabel!
    @IBOutlet weak var lastLocation: UILabel!
    @IBOutlet weak var lastTimestamp: UILabel!
    @IBOutlet weak var lastAccuracy: UILabel!
    @IBOutlet weak var lastPacket: UILabel!
    @IBOutlet weak var batteryLevel: UILabel!
}

class DeviceViewController: AppStateUIViewController {
    var provisioningView: ProvisioningViewController?
    var statusView: StatusViewController?
    
    @IBOutlet weak var provisioningContainer: UIStackView!
    @IBOutlet weak var toggleProvisioningButton: UIButton!
    
    @IBOutlet weak var spreadingFactor: UISegmentedControl!
    @IBOutlet weak var debugView: UITextView!
    @IBOutlet weak var toggleConnection: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        Answers.logContentView(withName: "DeviceView", contentType: "View", contentId: "DeviceView", customAttributes: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        updateAppState {
            var state = $0
            state.viewDetailDeviceID = nil
            return state
        }
    }
    
    @IBAction func sendPacket(_ sender: UIButton) {
        Answers.logCustomEvent(withName: "ManualSend", customAttributes: nil)
        debugPrint("sendPacket button pressed")
        updateAppState { (old) -> AppState in
            var state = old
            state.sendPacket = UUID() // Each press of command
            return state
        }
    }
    
    @IBAction func toggleProvisioningView(_ sender: UIButton) {
        updateAppState { (old) -> AppState in
            var state = old
            if let devID = state.viewDetailDeviceID, var dev = state.bluetooth[devID] {
                dev.hideProvisioning = !dev.hideProvisioning
                state.bluetooth[devID] = dev
            }
            return state
        }
    }
    
    @IBAction func getOTAA(_ sender: UIButton) {
        Answers.logCustomEvent(withName: "getOTAA", customAttributes: nil)
        debugPrint("getOTAA button pressed")
        updateAppState { (old) -> AppState in
            var state = old
            if let devID = old.viewDetailDeviceID {
                state.requestProvisioning = (UUID(), devID)
            }
            return state
        }
    }

    
    @IBAction func sendTestPacket(_ sender: UIButton) {
        Answers.logCustomEvent(withName: "TestPacket", customAttributes: nil)
        debugPrint("sendTestPacket button pressed")
        updateAppState { (old) -> AppState in
            var state = old
            if state.map.currentLocation==nil {
                state.map.currentLocation = CLLocation(latitude: 10, longitude: 10)
            }
            state.sendPacket = UUID() // Each press of command
            return state
        }
    }
    
    @IBAction func toggleConnection(_ sender: UIButton) {
        Answers.logCustomEvent(withName: "ConnectBT", customAttributes: nil)
        updateAppState {
            var state = $0
            if let devID = state.viewDetailDeviceID, let dev = state.bluetooth[devID] {
                if dev.connected {
                    state.disconnectDevice = UUID()
                }
                else {
                    state.connectToDevice = UUID()
                }
            }
            return state
        }
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.bluetooth!.rescan()
    }
    
    @IBAction func spreadingFactorChange(_ sender: UISegmentedControl) {
        let sf = UInt8(sender.selectedSegmentIndex) + 7
        Answers.logCustomEvent(withName: "SetSF", customAttributes: ["SF": NSNumber(value: sf as UInt8)])
        debugPrint("setSF: \(sf)")
        updateAppState { (old) -> AppState in
            if var dev = old.bluetooth.first?.1 {
                var state = old
                dev.spreadingFactor = sf
                state.bluetooth[dev.identifier] = dev
                return state
            }
            else {
                return old
            }
        }
    }
    
    override func renderAppState(_: AppState, state: AppState) {
        // Update UI according to app state
        if let devID = state.viewDetailDeviceID, let dev = state.bluetooth[devID] {
            if let devAddr = dev.devAddr {
                self.provisioningView!.devAddr.text = devAddr.hexadecimalString()
            }
            if let newSKey = dev.nwkSKey {
                self.provisioningView!.nwkSKey.text = newSKey.hexadecimalString()
            }
            if let appSKey = dev.appSKey {
                self.provisioningView!.appSKey.text = appSKey.hexadecimalString()
            }
            if let appKey = dev.appKey {
                self.provisioningView!.appKey.text = appKey.hexadecimalString()
            }
            if let appEUI = dev.appEUI {
                self.provisioningView!.appEUI.text = appEUI.hexadecimalString()
            }
            if let devEUI = dev.devEUI {
                self.provisioningView!.devEUI.text = devEUI.hexadecimalString()
            }
            if let lastLocation = dev.lastLocation {
                self.statusView!.lastLocation.text = String(format: "%0.5f, %0.5f", lastLocation.coordinate.latitude, lastLocation.coordinate.longitude)
                self.statusView!.lastTimestamp.text = stringFromTimeInterval(-lastLocation.timestamp.timeIntervalSinceNow) + " ago"
                self.statusView!.lastAccuracy.text = "\(lastLocation.horizontalAccuracy)"
            }
            if let lastPacket = dev.lastPacket {
                self.statusView!.lastPacket.text = lastPacket.hexadecimalString()
            }
            self.statusView!.batteryLevel.text = dev.battery.description
            self.statusView!.connected.text = dev.connected.description
            if let sf = dev.spreadingFactor {
                self.spreadingFactor.selectedSegmentIndex = Int(sf) - 7
            }
            self.toggleConnection.setTitle(dev.connected ? "Disconnect" : "Connect",
                                           for:UIControlState())
            self.provisioningContainer.isHidden = dev.hideProvisioning
            self.toggleProvisioningButton.setTitle(dev.hideProvisioning ? "Show" : "Hide",
                                                   for: UIControlState())

            var text = "Debug View\n"
            if let currentLocation = state.map.currentLocation {
                let locAge = fabs(currentLocation.timestamp.timeIntervalSinceNow)
                text += "Location age: \(stringFromTimeInterval(locAge))\n"
                let isCurrentLocation = locAge < CURRENT_LOCATION_EXPIRY
                text += "Location is current: \(isCurrentLocation)\n"
                
                if let lastLocation = dev.lastLocation {
                    let d = lastLocation.distance(from: currentLocation) // in meters
                    text += String(format: "Distance (sent vs latest): %0.1f meters\n", d)
                    let t = lastLocation.timestamp.timeIntervalSince(currentLocation.timestamp)
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

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if (segue.identifier=="provisioningView") {
            self.provisioningView = segue.destination as? ProvisioningViewController
        }
        else if (segue.identifier=="statusView") {
            self.statusView = segue.destination as? StatusViewController
        }
    }
}

