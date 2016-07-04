//
//  FirstViewController.swift
//  MapTheThings
//
//  Created by Frank on 2016/6/30.
//  Copyright © 2016 The Things Network New York. All rights reserved.
//

import UIKit

class FirstViewController: AppStateUIViewController {
    @IBOutlet var timestamp: UILabel!
    @IBOutlet var toggle: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func toggleTracking(event: UIEvent) {
        updateAppState { (old) -> AppState in
            var state = old
            state.map.tracking = !state.map.tracking
            return state
        }
    }
    
    override func renderAppState(state: AppState) {
        self.timestamp.text = state.now.description
        self.toggle.setTitle("Toggle Tracking: " + (state.map.tracking ? "T" : "F"), forState: UIControlState.Normal)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

