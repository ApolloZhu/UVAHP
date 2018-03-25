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
import UIKit

struct Exception: Error { }

let speaker = AVSpeechSynthesizer()

func speak(_ content: String) {
    speaker.speak(.init(string: content))
}

func ui(_ exec: @escaping () -> Void) {
    DispatchQueue.main.async {
        exec()
    }
}

extension Bool {
    mutating func toggle() {
        self = !self
    }
}

class RoundedButton: UIButton {
    override var bounds: CGRect {
        get { return super.bounds }
        set { super.bounds = newValue;layoutIfNeeded() }
    }
    
    override func layoutIfNeeded() {
        let radius = bounds.width / 2
        layer.cornerRadius = radius
        layer.shadowColor = UIColor.darkGray.cgColor
        layer.shadowPath = UIBezierPath(
            roundedRect: bounds,
            cornerRadius: radius
            ).cgPath
        layer.shadowOffset = CGSize(width: 1, height: 1)
        layer.shadowRadius = 5
        layer.shadowOpacity = 0.8
        super.layoutIfNeeded()
    }
}

func showNotification(title: String, message: String, soundName: String? = nil) {
    let center = UNUserNotificationCenter.current()
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = message
    if let name = soundName {
        content.sound = UNNotificationSound.init(named: name)
    }
    let request = UNNotificationRequest(
        identifier: title,
        content: content,
        trigger: nil
    )
    center.add(request, withCompletionHandler: nil)
}

func showError(_ message: String) {
    showNotification(title: "Something Went Wrong", message: message)
}
