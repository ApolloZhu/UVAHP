//
//  SafeTrekManager.swift
//  UVAHP
//
//  Created by Apollo Zhu on 3/24/18.
//  Copyright © 2018 UVAHP. All rights reserved.
//

import Foundation
import UIKit

class SafeTrekManager {
    private init() { }
    public static let shared = SafeTrekManager()
    public func login() {
        let string = "https://account-sandbox.safetrek.io/authorize?"
            + "client_id=m5qXF5ztOdT4cdQtUbZT2grBhF187vw6&"
            + "scope=openid phone offline_access&"
            //                + "state=<state_string>&"
            + "response_type=code&"
            + "redirect_uri=uvahp://"
        let url = string
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        UIApplication.shared.open(URL(string: url!)!
            , options: [:], completionHandler: nil)
    }
    public var code: String? {
        get { return UserDefaults.standard.string(forKey: "CODE") }
        set { UserDefaults.standard.set(newValue, forKey: "CODE") }
    }
}
