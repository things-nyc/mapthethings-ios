//
//  Authentication.swift
//  MapTheThings
//
//  Created by Frank on 2017/1/18.
//  Copyright © 2017 The Things Network New York. All rights reserved.
//

import UIKit
import OAuthSwift

class Authentication: NSObject {
    let oauthswift = OAuth1Swift(
        consumerKey:    "fBOTUUtjGUAGERlMrHDIFyEwO",
        consumerSecret: "OHSgEG4ua9BtYIKFIzkjrjJsQwjeOt7u1wQGIUuO1YuPJOFxep",
        requestTokenUrl: "https://api.twitter.com/oauth/request_token",
        authorizeUrl:    "https://api.twitter.com/oauth/authorize",
        accessTokenUrl:  "https://api.twitter.com/oauth/access_token"
    )
    public func authorize(viewController: UIViewController) {
        oauthswift.authorizeURLHandler = SafariURLHandler(viewController: viewController, oauthSwift: oauthswift)
        let handle = oauthswift.authorize(
            withCallbackURL: URL(string: "mapthethings://oauth-callback/twitter")!,
            success: { credential, response, parameters in
                print(credential.oauth_token)
                print(credential.oauth_token_secret)
                print(parameters["user_id"])
            },
            failure: { error in
                print(error.localizedDescription)
            }             
        )
    }

    
//    let oauthswift = OAuth2Swift(
//        consumerKey:    "********",
//        consumerSecret: "********",
//        authorizeUrl:   "https://api.instagram.com/oauth/authorize",
//        responseType:   "token"
//    )
//
//    public func authorize(viewController: UIViewController) {
//        oauthswift.authorizeURLHandler = SafariURLHandler(viewController: viewController, oauthSwift: oauthswift)
//        
//        let handle = oauthswift.authorize(
//            withCallbackURL: URL(string: "mapthethings://oauth-callback/instagram")!,
//            scope: "likes+comments", state:"INSTAGRAM",
//            success: { credential, response, parameters in
//                print(credential.oauthToken)
//        },
//            failure: { error in
//                print(error.localizedDescription)
//        }
//        )
//    }
    
    public func get(url: String) {
        oauthswift.client.get(url,
                              success: { response in
                                let dataString = response.string
                                print(dataString)
            },
                              failure: { error in
                                print(error)
            }
        )
//        oauthswift.client.request("https://api.linkedin.com/v1/people/~", .GET,
//                                  parameters: [:], headers: [:],
//                                  success: { ...    }
    }
}
