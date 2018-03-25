//
//  Extensions.swift
//  UVAHP
//
//  Created by Apollo Zhu on 3/24/18.
//  Copyright © 2018 UVAHP. All rights reserved.
//

import Foundation
import AVFoundation

struct Exception: Error {
    
}

func print(_ items: Any...) {
    DispatchQueue.global().async {
        Swift.print(items)
        AVSpeechSynthesizer().speak(.init(string: "\(items)"))
    }
}
