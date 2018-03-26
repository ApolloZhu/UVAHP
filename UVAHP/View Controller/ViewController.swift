////
////  ViewController.swift
////  UVAHP
////
////  Created by Apollo Zhu, Elizabeth Louie, Caroline Jin, and Ashley Young on 3/24/18.
////  Copyright © 2018 UVAHP. All rights reserved.
////
//

import UIKit
import AVFoundation
import CoreLocation
import GoogleMaps
import UserNotifications

extension String {
    static let submit = "Submit 😀"
    static let cancel = "Cancel"
}

class ViewController: UIViewController {
    lazy var locationManager: CLLocationManager = {
        $0.delegate = self
        $0.desiredAccuracy = kCLLocationAccuracyBest
        return $0
    }(CLLocationManager())
    
    lazy var session: AVCaptureSession = .init()
    let limit = 25
    var count = 0
    var smilecount = 0
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
    @IBOutlet var buttons: [UIButton]!
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
    
    var isButtonsEnabled: Bool {
        get { return fireButton.isEnabled }
        set {
            for button in buttons {
                button.isEnabled = newValue
                button.alpha = newValue ? 1 : 0.5
            }
        }
    }

    var someServicesSelected: Bool {
        return buttons.reduce(false) { $0 || $1.isSelected }
    }
    
    // MARK: - Actions

    func enableSubmitIfPossible() {
        if !someServicesSelected {
            submitButton.isEnabled = false
            resetTimer()
            submitButton.setTitle(.submit, for: .normal)
        } else {
            submitButton.isEnabled = true
        }
    }
    
    @IBAction func didTapFireButton() {
        if !isButtonsEnabled { return }
        isFireSelected.toggle()
        speak("Fire Department " + (isFireSelected ? "Selected" : "Deeselected"))
        enableSubmitIfPossible()
    }
    
    @IBAction func didTapAmbulanceButton() {
        if !isButtonsEnabled { return }
        isAmbulanceSelected.toggle()
        speak("Ambulance " + (isAmbulanceSelected ? "Selected" : "Deeselected"))
        enableSubmitIfPossible()
    }
    
    @IBAction func didTapPoliceButton() {
        if !isButtonsEnabled { return }
        isPoliceSelected.toggle()
        speak("Police " + (isPoliceSelected ? "Selected" : "Deeselected"))
        enableSubmitIfPossible()
    }
    
    var services: Services {
        return Services(
            police: isPoliceSelected,
            fire: isFireSelected,
            medical: isAmbulanceSelected
        )
    }
    
    @IBAction func submit() {
        switch submitButton.currentTitle {
        case .submit?:
            forceSubmit()
        case .cancel?:
            cancel()
        default:
            resetTimer()
            cancel()
            submitButton.setTitle(.submit, for: .normal)
        }
    }
    
    private func forceSubmit() {
        isButtonsEnabled = false
        smiled = true
        submitButton.setTitle(.cancel, for: .normal)
        startUpdate()
        if let loc = locationManager.location {
            SafeTrekManager.shared.triggerAlarm(
                services: services, location: loc
            )
        }
    }
    
    private func cancel(notify: Bool = false) {
        SafeTrekManager.shared.cancel(notify: notify)
    }
    
    @objc private func cancelUI() {
        stopUpdate()
        UNUserNotificationCenter.current()
            .removeAllDeliveredNotifications()
        submitButton.setTitle(.submit, for: .normal)
        smiled = false
        isButtonsEnabled = true
    }
    
    func stopUpdate() {
        locationManager.stopUpdatingLocation()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        stopUpdate()
        SafeTrekManager.shared.cancel(notify: false)
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
            submitButton.setTitle(.cancel, for: .normal)
        } else {
            cancel(notify: false)
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
                guard self.submitButton.currentTitle == .cancel else { return }
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
                    smilecount += 1
                    ui {
                        if self.smilecount >= self.limit
                            && self.submitButton.isEnabled {
                            self.startCountDown()
                        }
                    }
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

var counter = 3
var timer: Timer?

extension ViewController {
    func resetTimer() {
        timer?.invalidate()
        timer = nil
        counter = 3
    }
    func startCountDown() {
        guard timer == nil else { return }
        speak("Call services in")
        ui {
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                guard 0 != counter else {
                    self?.resetTimer()
                    if self?.submitButton.currentTitle != .cancel {
                        self?.forceSubmit()
                    }
                    return
                }
                UIView.animate(withDuration: 0.2,
                               animations: { [weak self] in
                                self?.submitButton?.titleLabel?.transform = .init(scaleX: 1.2, y: 1.2)
                                self?.submitButton?.setTitle("\(counter)", for: .normal)
                                speak("\(counter)")
                                counter -= 1
                    }, completion: { [weak self] _ in
                        self?.submitButton?.titleLabel?.transform = .identity
                })
            }
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
