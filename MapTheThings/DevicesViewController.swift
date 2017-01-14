//
//  DevicesViewController.swift
//  MapTheThings
//
//  Created by Frank on 2017/1/12.
//  Copyright © 2017 The Things Network New York. All rights reserved.
//

import UIKit
import ReactiveCocoa

extension UIImage {
    class func circle(diameter: CGFloat, color: UIColor) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(diameter, diameter), false, 0)
        if let ctx = UIGraphicsGetCurrentContext() {
            defer {
                UIGraphicsEndImageContext()
            }
            CGContextSaveGState(ctx)
            defer {
                CGContextRestoreGState(ctx)
            }
            
            let rect = CGRectMake(0, 0, diameter, diameter)
            CGContextSetFillColorWithColor(ctx, color.CGColor)
            CGContextFillEllipseInRect(ctx, rect)
            
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
        self.stateDisposer = appStateObservable.observeOn(QueueScheduler.mainQueueScheduler).observeNext({state in
            //print(state)
            self.renderAppState(state.old, state: state.new)
        })
    }
    
    var state: AppState? = nil
    var devices: [Device] = []
    let connectedImage = UIImage.circle(15, color: UIColor.greenColor())
    
    func renderAppState(oldState: AppState, state: AppState) {
        self.state = state
        self.devices = state.bluetooth.values.sort({ (a, b) -> Bool in
            return a.identifier.UUIDString < b.identifier.UUIDString
        })
        self.tableView.reloadData()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        observeAppState()
        
        // Uncomment the following line to preserve selection between presentations
        self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return devices.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("DeviceCell", forIndexPath: indexPath) as! DeviceCellView
        
        let device = self.devices[indexPath.row]
        cell.deviceName.text = device.name
        cell.connectedImage.image = device.connected ? connectedImage : nil
        // cell.detailTextLabel?.text = device.identifier.UUIDString
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
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
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
