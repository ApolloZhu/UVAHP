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
import MapKit

func ui(_ exec: @escaping () -> Void) {
    DispatchQueue.main.async {
        exec()
    }
}

class DetailsView: UIView {
    
    lazy var detailsLabel: UILabel = {
        let detailsLabel = UILabel(frame: CGRect(x: 0, y: 0, width: self.frame.size.width, height: self.frame.size.height))
        detailsLabel.numberOfLines = 0
        detailsLabel.textColor = .white
        detailsLabel.font = UIFont.systemFont(ofSize: 18.0)
        detailsLabel.textAlignment = .left
        
        return detailsLabel
    }()
    
    func setup() {
        layer.borderColor = UIColor.red.withAlphaComponent(0.7).cgColor
        layer.borderWidth = 5.0
        
        addSubview(detailsLabel)
    }
    
    override var frame: CGRect {
        didSet(newFrame) {
            var detailsFrame = detailsLabel.frame
            detailsFrame = CGRect(x: 0, y: newFrame.size.height, width: newFrame.size.width * 2.0, height: newFrame.size.height / 2.0)
            detailsLabel.frame = detailsFrame
        }
    }
}


class ViewController: UIViewController {
    lazy var locationManager: CLLocationManager = {
        let locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        return locationManager
    }()
    
    lazy var session: AVCaptureSession = .init()
    var stillOutput = AVCaptureStillImageOutput()
    var borderLayer: CAShapeLayer?
    let limit = 25
    var count = 0
    var prev = -1
    var setCalls = Set<Int>()
    
    let detailsView: DetailsView = {
        let detailsView = DetailsView()
        detailsView.setup()
        
        return detailsView
    }()
    
    lazy var previewLayer: AVCaptureVideoPreviewLayer? = {
        var previewLay = AVCaptureVideoPreviewLayer(session: session)
        previewLay.videoGravity = AVLayerVideoGravity.resizeAspectFill
        
        return previewLay
    }()
    
    lazy var frontCamera: AVCaptureDevice? = {
        return AVCaptureDevice.DiscoverySession.init(deviceTypes: [.builtInDuoCamera, .builtInMicrophone, .builtInTelephotoCamera, .builtInWideAngleCamera], mediaType: .video, position: .front).devices.first
        // let devices = AVCaptureDevice.devices(for: .video)
        // return devices.filter { $0.position == .front }.first!
    }()
    
    let faceDetector = CIDetector(
        ofType: CIDetectorTypeFace, context: nil,
        options: [CIDetectorAccuracy : CIDetectorAccuracyHigh]
    )
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.frame
    }
    
    //    override func viewDidAppear(_ animated: Bool) {
    //        super.viewDidAppear(animated)
    //        guard let previewLayer = previewLayer else { return }
    //
    //        view.layer.addSublayer(previewLayer)
    //        view.addSubview(detailsView)
    //        view.bringSubview(toFront: detailsView)
    //    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sessionPrepare()
        session.startRunning()
        requestAuthorization()
        NotificationCenter.default.addObserver(self, selector: #selector(cancelUI),
                                               name: .safeTrekDidCancel, object: nil)
    }
    
    @IBOutlet weak var fireButton: UIButton!
    var isFireSelected: Bool {
        return fireButton.isSelected
    }
    @IBOutlet weak var ambulanceButton: UIButton!
    var isAmbulanceSelected: Bool {
        return ambulanceButton.isSelected
    }
    @IBOutlet weak var policeButton: UIButton!
    var isPoliceSelected: Bool {
        return policeButton.isSelected
    }
    @IBOutlet weak var submitButton: UIButton!
    @IBOutlet weak var mapView: MKMapView! {
        didSet {
            mapView?.setUserTrackingMode(.follow, animated: true)
            mapView?.showsUserLocation = true
        }
    }
    
    
    @IBAction func didTapFireButton() {
        fireButton.isSelected = !fireButton.isSelected
        if fireButton.isSelected {
            ambulanceButton.isSelected = true
        }
    }
    
    @IBAction func didTapAmbulanceButton() {
        ambulanceButton.isSelected = !ambulanceButton.isSelected
    }
    
    @IBAction func didTapPoliceButton() {
        policeButton.isSelected = !policeButton.isSelected
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
            print("Smile-Submit")
            submitButton.setTitle("Cancel", for: .normal)
            print("Smile-Set title to cancel")
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
        print("Smile-Cancel")
        stopUpdate()
        submitButton.setTitle("Submit", for: .normal)
        smiled = false
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
    func sessionPrepare() {
        guard let captureDevice = frontCamera else { return }
        
        session.sessionPreset = AVCaptureSession.Preset.photo
        
        let deviceInput = try! AVCaptureDeviceInput(device: captureDevice)
        session.beginConfiguration()
        
        if session.canAddInput(deviceInput) {
            session.addInput(deviceInput)
        }
        
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String : NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
        
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
    
    
    func requestAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        startUpdate()
    }
    
    func startUpdate() {
        if CLLocationManager.locationServicesEnabled()
        && CLLocationManager.authorizationStatus() == .authorized {
            locationManager.startUpdatingLocation()
        } else {
            requestAuthorization()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let userLocation = locations[0]
        if SafeTrekManager.shared.isActive {
            SafeTrekManager.shared.updateLocation(to: userLocation)
        } else {
            ui {
                SafeTrekManager.shared.triggerAlarm(
                    services: self.services,
                    location: userLocation
                )
            }
        }
    }
}

var smiled = false

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate)
        let ciImage = CIImage(cvImageBuffer: pixelBuffer!, options: attachments as? [String : Any])
        let options: [String : Any] = [
            CIDetectorImageOrientation: exifOrientation(orientation: UIDevice.current.orientation),
            CIDetectorSmile: true,
            CIDetectorEyeBlink: true
        ]
        let allFeatures = faceDetector?.features(in: ciImage, options: options)
        
        let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer)
        let cleanAperture = CMVideoFormatDescriptionGetCleanAperture(formatDescription!, false)
        
        guard let features = allFeatures else { return }
        
        for feature in features {
            if let faceFeature = feature as? CIFaceFeature {
                let faceRect = calculateFaceRect(facePosition: faceFeature.rightEyePosition, faceBounds: faceFeature.bounds, clearAperture: cleanAperture)
                let featureDetails = ["has smile: \(faceFeature.hasSmile)",
                    "has closed left eye: \(faceFeature.leftEyeClosed)",
                    "has closed right eye: \(faceFeature.rightEyeClosed)"]
                update(with: faceRect, text: featureDetails.joined(separator: "\n"))
                let current = outputSignals(face :faceFeature)
                print("Count:", count)
                if faceFeature.hasSmile && smiled == false {
                    print("Smile")
                    ui { self.submit() }
                }
                if prev != current {
                    count = 0
                    print("Inaction")
                } else if prev == current && prev != -1 {
                    if count >= limit {
                        // call function pass in current
                        ui {
                            print("Action")
                            if current == 0 && self.isFireSelected { //lefteye <- based on user eye
                                print("FireButton")
                                self.didTapFireButton()
                            }
                            else if current == 1 && self.isPoliceSelected { //righteye <- based on user eye
                                print("PoliceButton")
                                self.didTapPoliceButton()
                            } else if current == 2 && self.isAmbulanceSelected { //botheye
                                print("AmbulanceButton")
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
        
        if features.count == 0 {
            DispatchQueue.main.async {
                self.detailsView.alpha = 0.0
            }
        }
    }
    
    func outputSignals(face: CIFaceFeature) -> Int{
        //Everything based on ImageFeatures
        //Ambulance
        if face.rightEyeClosed && face.leftEyeClosed{
            print("Both")
            return 2
        }
            //Police
        else if face.leftEyeClosed{
            print("Left")
            return 1
        }
            //Fire
        else if face.rightEyeClosed{
            print("Right")
            return 0
        }
        return -1
    }
    
    func exifOrientation(orientation: UIDeviceOrientation) -> Int {
        switch orientation {
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
    
    func videoBox(frameSize: CGSize, apertureSize: CGSize) -> CGRect {
        let apertureRatio = apertureSize.height / apertureSize.width
        let viewRatio = frameSize.width / frameSize.height
        
        var size = CGSize.zero
        
        if (viewRatio > apertureRatio) {
            size.width = frameSize.width
            size.height = apertureSize.width * (frameSize.width / apertureSize.height)
        } else {
            size.width = apertureSize.height * (frameSize.height / apertureSize.width)
            size.height = frameSize.height
        }
        
        var videoBox = CGRect(origin: .zero, size: size)
        
        if (size.width < frameSize.width) {
            videoBox.origin.x = (frameSize.width - size.width) / 2.0
        } else {
            videoBox.origin.x = (size.width - frameSize.width) / 2.0
        }
        
        if (size.height < frameSize.height) {
            videoBox.origin.y = (frameSize.height - size.height) / 2.0
        } else {
            videoBox.origin.y = (size.height - frameSize.height) / 2.0
        }
        return videoBox
    }
    
    func calculateFaceRect(facePosition: CGPoint, faceBounds: CGRect, clearAperture: CGRect) -> CGRect {
        let parentFrameSize = previewLayer!.frame.size
        let previewBox = videoBox(frameSize: parentFrameSize, apertureSize: clearAperture.size)
        
        var faceRect = faceBounds
        
        swap(&faceRect.size.width, &faceRect.size.height)
        swap(&faceRect.origin.x, &faceRect.origin.y)
        
        let widthScaleBy = previewBox.size.width / clearAperture.size.height
        let heightScaleBy = previewBox.size.height / clearAperture.size.width
        
        faceRect.size.width *= widthScaleBy
        faceRect.size.height *= heightScaleBy
        faceRect.origin.x *= widthScaleBy
        faceRect.origin.y *= heightScaleBy
        
        faceRect = faceRect.offsetBy(dx: 0.0, dy: previewBox.origin.y)
        let frame = CGRect(x: parentFrameSize.width - faceRect.origin.x - faceRect.size.width / 2.0 - previewBox.origin.x / 2.0, y: faceRect.origin.y, width: faceRect.width, height: faceRect.height)
        
        return frame
    }
}

extension ViewController {
    func update(with faceRect: CGRect, text: String) {
        ui {
            UIView.animate(withDuration: 0.2) {
                self.detailsView.detailsLabel.text = text
                self.detailsView.alpha = 1.0
                self.detailsView.frame = faceRect
            }
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
