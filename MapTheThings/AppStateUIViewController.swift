//
//  AppStateUIViewController.swift
//  MapTheThings
//
//  Created by Frank on 2016/7/3.
//  Copyright © 2016 The Things Network New York. All rights reserved.
//

import UIKit
import ReactiveSwift

class AppStateUIViewController: UIViewController {
    var stateDisposer: Disposable?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Listen for app state changes...
        self.stateDisposer = appStateObservable.observe(on: QueueScheduler.main)
            .observeValues({ state in
            //print(state)
            return self.renderAppState(state.old, state: state.new)
        })

        // Set initial view
        let initial = appStateProperty.value
        renderAppState(initial.old, state: initial.new)
    }
    
    func renderAppState(_ oldState: AppState, state: AppState) -> Void {
        preconditionFailure("This method must be overridden")
    }
}
