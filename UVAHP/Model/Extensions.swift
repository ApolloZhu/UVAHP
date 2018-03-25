//
//  Extensions.swift
//  UVAHP
//
//  Created by Apollo Zhu on 3/24/18.
//  Copyright © 2018 UVAHP. All rights reserved.
//

import Foundation
import AVFoundation
import UserNotifications

struct Exception: Error { }

func speak(_ content: String) {
    DispatchQueue.global().async {
        AVSpeechSynthesizer().speak(.init(string: content))
    }
}

func showError(_ message: String) {
    let center = UNUserNotificationCenter.current()
    let content = UNMutableNotificationContent()
    content.title = "Something Went Wrong"
    content.body = message
    let request = UNNotificationRequest.init(identifier: message, content: content, trigger: nil)
    center.add(request, withCompletionHandler: nil)
}
