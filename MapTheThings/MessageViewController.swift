//
//  MessageViewController.swift
//  MapTheThings
//
//  Created by Forrest Filler on 1/15/17.
//  Copyright © 2017 The Things Network New York. All rights reserved.
//

import UIKit
import ReactiveCocoa

class MessageViewController: AppStateUIViewController, UITextFieldDelegate{
    var disposer: Disposable?
    
    func convMessageToByte (num: String, msg: String) -> NSData {
        
        
        let data = NSMutableData()
        
        let format = NSData.dataWithHexString("03")
        data.appendData(format!)
        
        let formatCallType = NSData.dataWithHexString("0B")
        data.appendData(formatCallType!)
        
        var numStr = num
        
        if numStr.characters.count % 2 == 1 {
            print(numStr)
            numStr = numStr + "0"
        }
        
        
        let formatNum = NSData.dataWithHexString(numStr)
        data.appendData(formatNum!)
        
        
        let formatMsg = msg.asData()
        data.appendData(formatMsg)
        
        
        print(data)
    
        
        return data

        
    }
    
    
    
    // 03 0B 164655512120 Message-bytes (UTF)
    
    @IBOutlet weak var connectedLbl: UILabel!
    @IBOutlet weak var phoneNum: UITextField!
    @IBOutlet weak var msgText: UITextField!
    @IBOutlet weak var sendMsg: UIButton!

    @IBOutlet weak var send: UIButton!
    private var msg : String  {
        get {
            if msgText.text! == "" {
                return "...."
            }
            return msgText.text!
        }
    }
    
    private var num : String {
        get {
            let strNum =  phoneNum.text!.componentsSeparatedByCharactersInSet(
                NSCharacterSet.decimalDigitCharacterSet().invertedSet)
            let formattedNum = strNum.joinWithSeparator("")
            return formattedNum
        }
    }
    
    
    override func renderAppState(oldState: AppState, state: AppState) {
        
        let isConnected = state.bluetooth.reduce(false) { (connected, tuple) -> Bool in
            print(tuple.0.UUIDString)
            return connected || tuple.1.connected
        }
    
        self.connectedLbl.text! = isConnected ? "Node Status : Connected" : "Node Status: Not Connected"
        
        
    }
    
    @IBAction func sendMsg(sender: AnyObject) {
        self.resignFirstResponder()
        
        let data = convMessageToByte(num, msg: msg)
        print("_______________________")
        
        updateAppState {
            var state = $0
            state.requestSendPacket = (NSUUID(), data)
            return state
        }
        
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        phoneNum.delegate = self
        msgText.delegate = self
        
        
        
        self.disposer = appStateObservable.observeNext { update in
            if let (_, packet) = update.new.requestSendPacket
                where stateValChanged(update, access: { $0.requestSendPacket }) {
                
                //update.new.bluetooth.
                let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
                


                update.new.bluetooth.forEach({ (node: (NSUUID, Device)) in
                    
                    
                        appDelegate.bluetooth.node(node.0)?.sendPacket(packet)
                    
                    
                })
            }
        }
    }
    
    /**
     * Called when 'return' key pressed. return NO to ignore.
     */
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    
    /**
     * Called when the user click on the view (outside the UITextField).
     */
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        self.view.endEditing(true)
    }
    
    override func viewWillDisappear(animated: Bool) {
        self.disposer?.dispose()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
