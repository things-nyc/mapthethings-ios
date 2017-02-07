//
//  Authentication.swift
//  MapTheThings
//
//  Created by Frank on 2017/1/18.
//  Copyright © 2017 The Things Network New York. All rights reserved.
//

/* What's the idea with authentication?
 We offer an API that allows people to post data to our servers.
 We'd like to be able to identify who is posting what. The main purpose
 is to be able to limit or later purge samples that we learn are inaccurate.
 
 Rather than having people create accounts, we'll allow them to log in using
 Twitter. In the future we'll support other identity providers.
 
 1. The user logs into Twitter within the app and we extract
    user_id
    screen_name
    oauth_token
    oauth_secret
 
 2. The app stores this info in the secure store so that it can reuse it without 
    requesting it again.
 
 3. Each API call to the server includes an Auth header that carries this information.
    Auth: provider="twitter", user_id="23423423", screen_name="username", oauth_token="", oauth_secret=""

 4. The server calls the Twitter API verify_credentials using this information.
    After doing that once, it may cache the successful verified response and allow API calls
    with identical parameters for some reasonable time window, like an hour.
 
 Unfortunately, this mechanism requires distributing the app keys in the client app and transmitting
 the oauth keys over the wire to the API. There's probably a better way that keeps the secrets
 on the server and ties the client to an account via a unique session ID. We'll use that later.
 */

import UIKit
import OAuthSwift
import KeychainSwift

class Authentication: NSObject {
    public func storeAuth(auth: AuthState) {
        let keychain = KeychainSwift()
        keychain.set(auth.provider, forKey: "auth_provider")
        keychain.set(auth.user_id, forKey: "auth_user_id")
        keychain.set(auth.user_name, forKey: "auth_user_name")
        keychain.set(auth.oauth_token, forKey: "oauth_token")
        keychain.set(auth.oauth_secret, forKey: "oauth_secret")
    }
    
    public func loadAuth() -> AuthState? {
        let keychain = KeychainSwift()
        if let provider = keychain.get("auth_provider"),
         let user_id = keychain.get("auth_user_id"),
         let user_name = keychain.get("auth_user_name"),
         let oauth_token = keychain.get("oauth_token"),
         let oauth_secret = keychain.get("oauth_secret") {
            return AuthState(provider: provider, user_id: user_id, user_name: user_name, oauth_token: oauth_token, oauth_secret: oauth_secret)
        }
        else {
            return nil
        }
    }
    
    let oauthswift = OAuth1Swift(
        consumerKey:    PrivateConfig.TwitterConsumerKey,
        consumerSecret: PrivateConfig.TwitterConsumerSecret,
        requestTokenUrl: "https://api.twitter.com/oauth/request_token",
        authorizeUrl:    "https://api.twitter.com/oauth/authenticate", // authorize always asks
        accessTokenUrl:  "https://api.twitter.com/oauth/access_token"
    )
    public func authorize(viewController: UIViewController) {
        oauthswift.authorizeURLHandler = SafariURLHandler(viewController: viewController, oauthSwift: oauthswift)
        let _ = oauthswift.authorize(
            withCallbackURL: URL(string: "mapthethings://oauth-callback/twitter")!,
            success: { credential, response, parameters in
//                print(credential.oauthToken)
//                print(credential.oauthTokenSecret)
//                print(credential.oauthVerifier)
//                print(parameters["user_id"] ?? "-")
//                print(parameters["screen_name"] ?? "-")
                updateAppState({ (old) -> AppState in
                    var state = old
                    if let user_id = parameters["user_id"] as? String,
                        let screen_name = parameters["screen_name"] as? String {
                        let auth = AuthState(
                            provider: "twitter",
                            user_id: user_id,
                            user_name: screen_name,
                            oauth_token: credential.oauthToken,
                            oauth_secret: credential.oauthTokenSecret)
                        state.authState = auth
                        print("Authenticated: \(state.authState)")
                        self.storeAuth(auth: auth)
                    }
                    return state
                })
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
        let _ = oauthswift.client.get(url,
                              success: { response in
                                if let dataString = response.string {
                                    print(dataString)
                                }
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
