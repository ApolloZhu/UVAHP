////
////  ViewController.swift
////  UVAHP
////
////  Created by Apollo Zhu on 3/24/18.
////  Copyright © 2018 UVAHP. All rights reserved.
////
//

import UIKit
import AVFoundation
import CoreLocation
import GoogleMaps
import UserNotifications

class ViewController: UIViewController {
    lazy var locationManager: CLLocationManager = {
        $0.delegate = self
        $0.desiredAccuracy = kCLLocationAccuracyBest
        return $0
    }(CLLocationManager())
    
    lazy var session: AVCaptureSession = .init()
    let limit = 25
    var count = 0
    var prev = -1
    
    lazy var previewLayer: AVCaptureVideoPreviewLayer? = {
        $0.videoGravity = .resizeAspectFill
        return $0
    }(AVCaptureVideoPreviewLayer(session: session))
    
    lazy var frontCamera: AVCaptureDevice? = AVCaptureDevice.DiscoverySession.init(deviceTypes: [.builtInDuoCamera, .builtInMicrophone, .builtInTelephotoCamera, .builtInWideAngleCamera], mediaType: .video, position: .front).devices.first
    
    let faceDetector = CIDetector(
        ofType: CIDetectorTypeFace, context: nil,
        options: [CIDetectorAccuracy: CIDetectorAccuracyLow]
    )
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.frame
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        prepareSession()
        session.startRunning()
        requestLocationAccess()
        NotificationCenter.default.addObserver(
            self, selector: #selector(cancelUI),
            name: .safeTrekDidCancel, object: nil
        )
    }
    
    // MARK: - UI controls
    @IBOutlet weak var fireButton: UIButton!
    var isFireSelected: Bool {
        get { return fireButton.isSelected }
        set { fireButton.isSelected = newValue }
    }
    @IBOutlet weak var ambulanceButton: UIButton!
    var isAmbulanceSelected: Bool {
        get { return ambulanceButton.isSelected }
        set { ambulanceButton.isSelected = newValue }
    }
    @IBOutlet weak var policeButton: UIButton!
    var isPoliceSelected: Bool {
        get { return policeButton.isSelected }
        set { policeButton.isSelected = newValue }
    }
    @IBOutlet weak var submitButton: UIButton! {
        didSet {
            submitButton?.setNeedsLayout()
        }
    }
    @IBOutlet weak var mapView: GMSMapView! {
        didSet {
            requestLocationAccess()
            startUpdate()
            mapView.isMyLocationEnabled = true
        }
    }
    
    // MARK: - Actions
    
    @IBAction func didTapFireButton() {
        isFireSelected.toggle()
        if isFireSelected {
            speak("Fire Department and Ambulance Selected")
            isAmbulanceSelected = true
        } else {
            speak("Fire Department Deeselected")
        }
    }
    
    @IBAction func didTapAmbulanceButton() {
        isAmbulanceSelected.toggle()
        speak("Ambulance " + (isAmbulanceSelected ? "Selected" : "Deeselected"))
    }
    
    @IBAction func didTapPoliceButton() {
        isPoliceSelected.toggle()
        speak("Police " + (isPoliceSelected ? "Selected" : "Deeselected"))
    }
    
    var services: Services {
        return Services(
            police: isPoliceSelected,
            fire: isFireSelected,
            medical: isAmbulanceSelected
        )
    }
    
    @IBAction func submit() {
        if submitButton.currentTitle == "Submit" {
            smiled = true
            submitButton.setTitle("Cancel", for: .normal)
            startUpdate()
            if let loc = locationManager.location {
                SafeTrekManager.shared.triggerAlarm(
                    services: services, location: loc
                )
            }
        } else { cancel() }
    }
    
    private func cancel() {
        SafeTrekManager.shared.cancel()
    }
    
    @objc private func cancelUI() {
        stopUpdate()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        submitButton.setTitle("Submit", for: .normal)
        smiled = false
        speak("")
    }
    
    func stopUpdate() {
        locationManager.stopUpdatingLocation()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        stopUpdate()
        SafeTrekManager.shared.cancel()
    }
}

let queue = DispatchQueue(label: "output.queue")

extension ViewController: CLLocationManagerDelegate {
    func prepareSession() {
        guard let captureDevice = frontCamera
            , let deviceInput = try? AVCaptureDeviceInput(device: captureDevice)
            else { return }
        
        session.sessionPreset = .photo
        
        session.beginConfiguration()
        
        if session.canAddInput(deviceInput) {
            session.addInput(deviceInput)
        }
        
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String
            : NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
        
        output.alwaysDiscardsLateVideoFrames = true
        
        output.setSampleBufferDelegate(self, queue: queue)
        
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        
        session.commitConfiguration()
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if SafeTrekManager.shared.isActive {
            submitButton.setTitle("Cancel", for: .normal)
        } else {
            cancel()
        }
    }
    
    
    func requestLocationAccess() {
        locationManager.requestAlwaysAuthorization()
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        startUpdate()
    }
    
    func startUpdate() {
        if CLLocationManager.locationServicesEnabled()
            && (CLLocationManager.authorizationStatus() == .authorizedAlways
                || CLLocationManager.authorizationStatus() == .authorizedWhenInUse)
        {
            locationManager.startUpdatingLocation()
        } else {
            requestLocationAccess()
        }
    }
    
    
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let userLocation = locations[0]
        let coord = userLocation.coordinate
        let zoom = autoZoomed ? mapView.camera.zoom : 15
        autoZoomed = false
        mapView.camera = GMSCameraPosition.camera(withTarget: coord, zoom: zoom)
        if SafeTrekManager.shared.isActive {
            SafeTrekManager.shared.updateLocation(to: userLocation)
        } else {
            ui {
                guard self.submitButton.currentTitle == "Cancel" else { return }
                SafeTrekManager.shared.triggerAlarm(
                    services: self.services,
                    location: userLocation
                )
            }
        }
    }
}

var autoZoomed = false
var smiled = false

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate)
        let ciImage = CIImage(cvImageBuffer: buffer, options: attachments as? [String : Any])
        let options: [String : Any] = [
            CIDetectorImageOrientation: UIDevice.current.orientation.exif,
            CIDetectorSmile: true,
            CIDetectorEyeBlink: true
        ]
        let allFeatures = faceDetector?.features(in: ciImage, options: options)
        
        guard let features = allFeatures else { return }
        
        for feature in features {
            if let faceFeature = feature as? CIFaceFeature {
                let current = outputSignals(face :faceFeature)
                if faceFeature.hasSmile && smiled == false {
                    speak("Smiled")
                    ui { self.submit() }
                }
                if prev != current {
                    count = 0
                } else if prev == current && prev != -1 {
                    if count >= limit {
                        // call function pass in current
                        ui {
                            if current == 0 && self.isFireSelected { //lefteye <- based on user eye
                                self.didTapFireButton()
                            } else if current == 1 && self.isPoliceSelected { //righteye <- based on user eye
                                self.didTapPoliceButton()
                            } else if current == 2 && self.isAmbulanceSelected { //botheye
                                self.didTapAmbulanceButton()
                            }
                            self.count = 0
                        }
                    }
                    count += 1
                }
                prev = current
            }
        }
    }
    
    //Everything based on ImageFeatures
    func outputSignals(face: CIFaceFeature) -> Int {
        switch (face.leftEyeClosed, face.rightEyeClosed) {
        case (true, true): return 2 // Ambulance
        case (true, _): return 1 // Police
        case (_, true): return 0
        default: return -1
        }
    }
    
    
    
}

extension UIDeviceOrientation {
    var exif: Int {
        switch self {
        case .portraitUpsideDown:
            return 8
        case .landscapeLeft:
            return 3
        case .landscapeRight:
            return 1
        default:
            return 6
        }
    }
}

extension ViewController {
    override func motionEnded(_ motion: UIEventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            SafeTrekManager.shared.login()
        }
    }
}
