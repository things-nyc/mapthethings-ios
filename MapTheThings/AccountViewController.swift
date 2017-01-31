//
//  AccountViewController.swift
//  MapTheThings
//
//  Created by Frank on 2017/1/30.
//  Copyright © 2017 The Things Network New York. All rights reserved.
//

import UIKit
import Crashlytics
import ReactiveSwift

class LoggedInViewController : UITableViewController {
    var stateDisposer: Disposable?

    @IBOutlet weak var provider_logo: UIImageView!
    @IBOutlet weak var provider: UILabel!
    @IBOutlet weak var user_id: UILabel!
    @IBOutlet weak var user_name: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        var first = true
        self.stateDisposer = appStateObservable.observe(on: QueueScheduler.main)
            .observeValues({ (old, new) in
                if let auth = new.authState, first || old.authState==nil {
                    self.provider.text = auth.provider.capitalized
                    self.user_name.text = auth.user_name
                    self.user_id.text = auth.user_id
                    first = false
                }
            })
        
    }
    @IBAction func logout(_ sender: UIButton) {
        Answers.logCustomEvent(withName: "Logout", customAttributes: nil)
        updateAppState({ (old) -> AppState in
            var state = old
            state.authState = nil
            return state
        })
    }
}

class LoginViewController : UITableViewController {
    @IBAction func login(_ sender: UIButton) {
        Answers.logCustomEvent(withName: "Login", customAttributes: nil)
        let auth = Authentication()
        auth.authorize(viewController: self)
    }
}

class AccountViewController: AppStateUIViewController {
    @IBOutlet weak var loggedInPanel: UIView!
    @IBOutlet weak var loginPanel: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func renderAppState(_ oldState: AppState, state: AppState) {
        let loggedIn = (state.authState != nil)
        self.loginPanel.isHidden = loggedIn
        self.loggedInPanel.isHidden = !loggedIn
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
