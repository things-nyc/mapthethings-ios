//
//  AppStateUIViewController.swift
//  MapTheThings
//
//  Created by Frank on 2016/7/3.
//  Copyright © 2016 The Things Network New York. All rights reserved.
//

import UIKit
import ReactiveCocoa

class AppStateUIViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Listen for app state changes...
        appStateObservable.observeOn(QueueScheduler.mainQueueScheduler).observeNext({state in
            //print(state)
            self.renderAppState(state)
        })
    }
    
    func renderAppState(state: AppState) {
    }
}
