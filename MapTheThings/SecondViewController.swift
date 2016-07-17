//
//  SecondViewController.swift
//  MapTheThings
//
//  Created by Frank on 2016/6/30.
//  Copyright © 2016 The Things Network New York. All rights reserved.
//

import UIKit

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
        return hexadecimalString
    }
}

class SecondViewController: AppStateUIViewController {
    @IBOutlet var devAddr: UITextField!
    @IBOutlet var nwkSKey: UITextField!
    @IBOutlet var appSKey: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func renderAppState(state: AppState) {
        // Update UI according to app state
        let dev = state.bluetooth.first?.1
        if let devAddr = dev?.devAddr {
            self.devAddr.text = devAddr.hexadecimalString()
        }
        if let newSKey = dev?.nwkSKey {
            self.nwkSKey.text = newSKey.hexadecimalString()
        }
        if let appSKey = dev?.appSKey {
            self.appSKey.text = appSKey.hexadecimalString()
        }
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

