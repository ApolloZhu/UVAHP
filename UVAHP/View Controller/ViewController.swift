//
//  ViewController.swift
//  UVAHP
//
//  Created by Apollo Zhu on 3/24/18.
//  Copyright © 2018 UVAHP. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        let face = CIFaceFeature()
        let session = AVCaptureSession()
        session.sessionPreset = AVCaptureSession.Preset.photo
        var frontCamera: AVCaptureDevice? = {
            guard let devices = AVCaptureDevice.devices(for: AVMediaType.video) as? [AVCaptureDevice] else { return nil }
            return devices.filter { $0.position == .front }.first
        }()
        let deviceInput = try AVCaptureDeviceInput(device: frontCamera!)
        session.beginConfiguration()
        if session.canAddInput(deviceInput) {
            session.addInput(deviceInput)
        }
//        if face.hasLeftEyePosition || face.hasRightEyePosition{
//            print("Hello World!")
//        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

