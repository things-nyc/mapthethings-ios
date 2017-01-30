//
//  DevicesViewController.swift
//  MapTheThings
//
//  Created by Frank on 2017/1/12.
//  Copyright © 2017 The Things Network New York. All rights reserved.
//

import UIKit
import ReactiveSwift
import Crashlytics

extension UIImage {
    class func circle(_ diameter: CGFloat, color: UIColor) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(CGSize(width: diameter, height: diameter), false, 0)
        if let ctx = UIGraphicsGetCurrentContext() {
            defer {
                UIGraphicsEndImageContext()
            }
            ctx.saveGState()
            defer {
                ctx.restoreGState()
            }
            
            let rect = CGRect(x: 0, y: 0, width: diameter, height: diameter)
            ctx.setFillColor(color.cgColor)
            ctx.fillEllipse(in: rect)
            
            if let img = UIGraphicsGetImageFromCurrentImageContext() {
                return img
            }
        }
        return nil
    }
}

class DeviceCellView : UITableViewCell {
    @IBOutlet weak var deviceName: UILabel!
    @IBOutlet weak var connectedImage: UIImageView!
}

class DevicesViewController: UITableViewController {
    var stateDisposer: Disposable?
    func observeAppState() {
        // Copied from AppStateViewController because this inherits differently. Should mix in.
        // Listen for app state changes...
        self.stateDisposer = appStateObservable.observe(on: QueueScheduler.main).observeValues({state in
            //print(state)
            self.renderAppState(state.old, state: state.new)
        })
    }
    
    @IBOutlet weak var refreshButton: UIBarButtonItem?
    var state: AppState? = nil
    var devices: [Device] = []
    let connectedImage = UIImage.circle(15, color: UIColor.green)
    
    func renderAppState(_ oldState: AppState, state: AppState) {
        self.state = state
        self.devices = state.bluetooth.values.sorted(by: { (a, b) -> Bool in
            return a.identifier.uuidString < b.identifier.uuidString
        })
        self.tableView.reloadData()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.refreshButton!.target = self
        self.refreshButton!.action = #selector(DevicesViewController.rescanBluetooth)

        observeAppState()
        
        // Uncomment the following line to preserve selection between presentations
        self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        let signal = appStateProperty.value
        renderAppState(signal.old, state: signal.new)
    }

    @IBAction func rescanBluetooth(_ sender: UIButton) {
        Answers.logCustomEvent(withName: "RescanBT", customAttributes: nil)
        debugPrint("rescanBluetooth")
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.bluetooth!.rescan()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return devices.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DeviceCell", for: indexPath) as! DeviceCellView
        
        let device = self.devices[indexPath.row]
        cell.deviceName.text = device.name
        cell.connectedImage.image = device.connected ? connectedImage : nil
        // cell.detailTextLabel?.text = device.identifier.uuidString
        return cell
    }

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        
        if let row = self.tableView.indexPathForSelectedRow?.row {
            updateAppState({
                var state = $0
                state.viewDetailDeviceID = self.devices[row].identifier
                return state
            })
        }
    }

}
