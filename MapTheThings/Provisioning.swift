//
//  Provisioning.swift
//  MapTheThings
//
//  Created by Frank on 2017/1/14.
//  Copyright © 2017 The Things Network New York. All rights reserved.
//

import CoreData
import Foundation
import MapKit
import Alamofire
import PromiseKit
import ReactiveCocoa

extension NSData {
// Thanks: http://stackoverflow.com/a/26502285/1207583
    /// Create `NSData` from hexadecimal string representation
    ///
    /// This takes a hexadecimal representation and creates a `NSData` object. Note, if the string has any spaces or non-hex characters (e.g. starts with '<' and with a '>'), those are ignored and only hex characters are processed.
    ///
    /// - returns: Data represented by this hexadecimal string.
    
    static func dataWithHexString(s: String) -> NSData? {
        let data = NSMutableData(capacity: s.characters.count / 2)
        
        let regex = try! NSRegularExpression(pattern: "[0-9a-f]{1,2}", options: .CaseInsensitive)
        regex.enumerateMatchesInString(s, options: [], range: NSMakeRange(0, s.characters.count)) { match, flags, stop in
            let byteString = (s as NSString).substringWithRange(match!.range)
            var num = UInt8(byteString, radix: 16)
            data?.appendBytes(&num, length: 1)
        }
        
        return data
    }
}

public class Provisioning {
    var provisionDisposer: Disposable?

    init() {
        self.provisionDisposer = appStateObservable.observeNext { update in
            if let (_, deviceID) = update.new.requestProvisioning
                where stateValChanged(update, access: { $0.requestProvisioning}) {
                self.getOTAA(deviceID, host: update.new.host)
            }
        }
    }

    private func getOTAA(deviceID: NSUUID, host: String) {
        let parameters: [String: AnyObject] = ["devName": "My Name"]
        debugPrint("Params: \(parameters)")
        let url = "http://\(host)/api/v0/provision-device"
        debugPrint("URL: \(url)")
        let rsp = Promise<NSDictionary> { fulfill, reject in
            return request(.POST, url,
                    parameters: parameters,
                    encoding: ParameterEncoding.JSON)
                .responseJSON(queue: nil, options: .AllowFragments, completionHandler: { response in
                    switch response.result {
                    case .Success(let value):
                        fulfill(value as! NSDictionary)
                    case .Failure(let error):
                        reject(error)
                    }
                })
        }
        rsp.then { jsonResponse -> Void in
            debugPrint(jsonResponse)
            if let appKey = jsonResponse["app_key"] as? String,
                let appKeyData = NSData.dataWithHexString(appKey),
                let appEUI = jsonResponse["app_eui"] as? String,
                let appEUIData = NSData.dataWithHexString(appEUI),
                let devEUI = jsonResponse["dev_eui"] as? String,
                let devEUIData = NSData.dataWithHexString(devEUI)
                where appKeyData.length==16 && appEUIData.length==8 && devEUIData.length==8 {
                updateAppState {
                    var state = $0
                    if var dev = state.bluetooth[deviceID] {
                        dev.appKey = appKeyData
                        dev.appEUI = appEUIData
                        dev.devEUI = devEUIData
                        state.bluetooth[deviceID] = dev
                        state.assignProvisioning = (NSUUID(), deviceID)
                    }
                    return state
                }
            }
            else {
                var msg = "Invalid JSON response"
                if let reason = jsonResponse["error"] as? String {
                    msg = reason
                }
                let userInfo = [NSLocalizedFailureReasonErrorKey: msg]
                throw NSError(domain: "web", code: 0, userInfo: userInfo)
            }
        }.error { (error) in
            debugPrint("\(error)")
            setAppError(error, fn: "getOTAA", domain: "web")
        }
    }
}
