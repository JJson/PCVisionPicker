//
//  PCVisionPickerViewController.swift
//  PCVisionPicker
//
//  Created by linjj on 2017/12/26.
//  Copyright © 2017年 linjj. All rights reserved.
//

import UIKit
import PBJVision
import ImageIO
public class PCVisionPickerViewController: UIViewController {
    public var cameraMode:PBJCameraMode = .photo
    public var flashMode:PBJFlashMode = .auto {
        didSet{
            vision.flashMode = flashMode
            switch flashMode {
            case .auto:
                btLight.setImage(UIImage(named: "light_auto", in: bundle, compatibleWith: nil), for: .normal)
            case .off:
                btLight.setImage(UIImage(named: "light_off", in: bundle, compatibleWith: nil), for: .normal)
            case .on:
                btLight.setImage(UIImage(named: "light_on", in: bundle, compatibleWith: nil), for: .normal)
            }
        }
    }
    var vision = PBJVision()
    var bundle = Bundle(for: PCVisionPickerViewController.self)
    var recording = false{
        didSet{
            if recording {
                btStart.setBackgroundImage(UIImage(named: "pcvision_stop", in: bundle, compatibleWith: nil), for: .normal)
            }
            else {
                btStart.setBackgroundImage(UIImage(named: "pcvision_start", in: bundle, compatibleWith: nil), for: .normal)
            }
        }
    }
    
    var touchEnable = true {
        didSet {
            btLight.isEnabled = touchEnable
            btStart.isEnabled = touchEnable
            btSwitch.isEnabled = touchEnable
        }
    }
    
    public var handleDone:((UIImage?,URL?)->(Void))?
    
    public var skipPreview = false
    
    let focusView = PBJFocusView(frame: CGRect.zero)
    @IBOutlet weak var lbTimeTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var previewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var lbTime: UILabel!
    @IBOutlet weak var btLight: UIButton!
    @IBOutlet weak var btStart: UIButton!
    @IBOutlet weak var btSwitch: UIButton!
    
    fileprivate let orginIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
    
    public override var prefersStatusBarHidden: Bool {
        get {
            return true
        }
    }
    override public func viewDidLoad() {
        super.viewDidLoad()
        if cameraMode == .photo {
            lbTime.isHidden = true
        }
        else {
            lbTime.isHidden = false
        }
        // Do any additional setup after loading the view.
    }
    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: Bundle(for: PCVisionPickerViewController.self))
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    deinit {
        vision.stopPreview()
        vision.previewLayer.removeFromSuperlayer()
        print("PCVisionPickerViewController deinit")
    }
    
    override public func viewSafeAreaInsetsDidChange() {
        if #available(iOS 11.0, *) {
            super.viewSafeAreaInsetsDidChange()
            lbTimeTopConstraint.constant += view.safeAreaInsets.top
            previewTopConstraint.constant += view.safeAreaInsets.top
            bottomConstraint.constant = view.safeAreaInsets.bottom
            
        } else {
            // Fallback on earlier versions
        }
        
    }
    
    override public func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        initViews()
        resetCapture()
        SwiftProgressHUD.showWait()
        touchEnable = false
        vision.startPreview()
    }
    
    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        vision.stopPreview()
        vision.previewLayer.removeFromSuperlayer()
        
    }
    
    
    // MARK: - functions
    func initViews() {
        let previewLayer = vision.previewLayer
        previewLayer.frame = previewView.bounds
        previewLayer.videoGravity = .resizeAspectFill
        previewView.layer.addSublayer(previewLayer)
        
    }
    
    func resetCapture() {
        vision.delegate = self
        if vision.isCameraDeviceAvailable(.back) {
            vision.cameraDevice = .back
        }
        else {
            vision.cameraDevice = .front
        }
        vision.cameraMode = cameraMode
        vision.cameraOrientation = .portrait
        vision.flashMode = .auto
        vision.outputFormat = .preset
        vision.isVideoRenderingEnabled = true
        if cameraMode == .photo {
            vision.captureSessionPreset = AVCaptureSession.Preset.hd1280x720.rawValue
        }
        else {
            if UIDevice.current.isIPhoneX() {
                vision.captureSessionPreset = AVCaptureSession.Preset.hd1280x720.rawValue
                vision.videoBitRate = PBJVideoBitRate1280x720
            }
            else {
                vision.captureSessionPreset = AVCaptureSession.Preset.hd1920x1080.rawValue
            }
            vision.videoBitRate = 1920*1080*3
            vision.additionalCompressionProperties = [AVVideoProfileLevelKey:AVVideoProfileLevelH264BaselineAutoLevel]
        }
        
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    // MARK: - actions
    @IBAction func switchFlashModeAction(_ sender: Any) {
        flashMode = flashMode.next()
    }
    
    @IBAction func switchCameraAction(_ sender: Any) {
        vision.cameraDevice = vision.cameraDevice.next()
    }
    
    @IBAction func startAction(_ sender: Any) {
        if cameraMode == .photo {
            vision.capturePhoto()
        }
        else if cameraMode == .video {
            if recording    {
                stopVideoCapture()
            }
            else {
                startVideoCapture()
            }
        }
    }
    
    public func stopVideoCapture(skipPreview bSkipPreview: Bool? = nil) {
        if bSkipPreview != nil {
            skipPreview = bSkipPreview!
        }
        
        if vision.isRecording {
            SwiftProgressHUD.showWait()
            touchEnable = false
            vision.endVideoCapture()
        }
    }
    public func startVideoCapture() {
        if !vision.isRecording {
            vision.startVideoCapture()
        }
    
    }
    @IBAction func cancelAction(_ sender: Any) {
        self.dismiss(animated: true) {
            
        }
    }
    
    
    @IBAction func handleFocusTapGesterRecognizer(gestureRecognizer:UIGestureRecognizer) {
        let tapPoint = gestureRecognizer.location(in: previewView)
        focusView.center = tapPoint
        previewView.addSubview(focusView)
        focusView.startAnimation()
        let previewLayer = vision.previewLayer
        let  adjustPoint = previewLayer.captureDevicePointConverted(fromLayerPoint: tapPoint)
        vision.focusExposeAndAdjustWhiteBalance(atAdjustedPoint: adjustPoint)
    }
    
}

// MARK: - PBJVisionDelegate
extension PCVisionPickerViewController: PBJVisionDelegate {
    
    
    public func visionDidStopFocus(_ vision: PBJVision) {
        DispatchQueue.main.async {[weak self] in
            self?.focusView.stopAnimation()
        }
    }
    
    
    public func visionDidChangeExposure(_ vision: PBJVision) {
        //        DispatchQueue.main.async {[weak self] in
        //            self?.focusView.stopAnimation()
        //        }
    }
    
    public func vision(_ vision: PBJVision, capturedPhoto photoDict: [AnyHashable : Any]?, error: Error?) {
        if let photoInfo = photoDict {
            let photoData = photoInfo[PBJVisionPhotoJPEGKey] as! Data
            
            //            let tmpImage = UIImage(data: photoData)
            
            let metadata = photoInfo[PBJVisionPhotoMetadataKey]  as! [AnyHashable : Any]
            if let image = UIImage(imageData: photoData, metaData: metadata) {
                let previewCtr = PCVisionPickerPreviewController(nibName: "PCVisionPickerPreviewController", bundle: nil)
                previewCtr.image = image
                previewCtr.handleDone = {[weak self] image,videoUrl in
                    self?.dismiss(animated: true, completion: {
                        self?.handleDone?(image,videoUrl)
                    })
                    
                }
                self.navigationController?.pushViewController(previewCtr, animated: true)

            }
        }
    }
    
    public func visionSessionDidStart(_ vision: PBJVision) {
        SwiftProgressHUD.hideAllHUD()
        touchEnable = true
    }
    
    public func visionDidStartVideoCapture(_ vision: PBJVision) {
        SwiftProgressHUD.hideAllHUD()//其实这里的hide应该没什么用
        recording = true
        UIApplication.shared.isIdleTimerDisabled = true
    }
    public func visionSessionDidStop(_ vision: PBJVision) {
        recording = false
        UIApplication.shared.isIdleTimerDisabled = orginIdleTimerDisabled
    }
    public func visionDidEndVideoCapture(_ vision: PBJVision) {
        SwiftProgressHUD.hideAllHUD()
        touchEnable = true
    }
    
    public func vision(_ vision: PBJVision, capturedVideo videoDict: [AnyHashable : Any]?, error: Error?) {
        //        if error != nil {
        //            return
        //        }
        guard let videoInfo = videoDict else {
            return
        }
        let videoPath = videoInfo[PBJVisionVideoPathKey]
        let thumbnail = videoInfo[PBJVisionVideoThumbnailKey] as? UIImage
        let videoUrl = URL(fileURLWithPath: videoPath as! String)
        if skipPreview {
            self.dismiss(animated: true, completion: {
                self.handleDone?(thumbnail,videoUrl)
            })
        } else {
            let ctr = PCVisionPickerPreviewController(nibName: "PCVisionPickerPreviewController", bundle: nil)
            ctr.videoUrl = videoUrl
            ctr.handleDone = {[weak self] _,videoUrl in
                self?.dismiss(animated: true, completion: {
                    self?.handleDone?(thumbnail,videoUrl)
                })
            }
            
            lbTime.text = "00:00:00"
            navigationController?.pushViewController(ctr, animated: true)
        }
        
    }
    public func vision(_ vision: PBJVision, didCaptureVideoSampleBuffer sampleBuffer: CMSampleBuffer) {
        let seconds = vision.capturedVideoSeconds
        let hour = Int(seconds / (60*60))
        let minute = Int((seconds / 60).truncatingRemainder(dividingBy: 60))
        let second = Int(seconds.truncatingRemainder(dividingBy: 60))
        lbTime.text = String(format: "%02d:%02d:%02d", hour,minute,second)
    }
}

extension PBJFlashMode {
    func next() -> PBJFlashMode {
        let value = self.rawValue + 1
        if  value <= PBJFlashMode.auto.rawValue{
            let result = PBJFlashMode(rawValue: value)
            return result!
        }
        else {
            return .off
        }
    }
}

extension PBJCameraDevice {
    func next() -> PBJCameraDevice {
        let value = self.rawValue + 1
        if  value <= PBJCameraDevice.front.rawValue{
            let result = PBJCameraDevice(rawValue: value)
            return result!
        }
        else {
            return .back
        }
        
    }
}

extension UIImage {
    convenience init?(imageData:Data,metaData:[AnyHashable:Any]) {
        let source = CGImageSourceCreateWithData(imageData as CFData, nil)
        let sourceType = CGImageSourceGetType(source!)
        let imageDataWithMetaData = NSMutableData()
        let destination = CGImageDestinationCreateWithData(imageDataWithMetaData, sourceType!, 1, nil)
        if destination == nil {
            print("could not create image destination")
        }
        CGImageDestinationAddImageFromSource(destination!, source!, 0, metaData as CFDictionary)
        let success = CGImageDestinationFinalize(destination!)
        if !success {
            print("could not finalize image at destination")
        }
        if destination != nil {
            
        }
        
        if source != nil {
            
        }
        self.init(data: imageDataWithMetaData as Data)
    }
}

extension UIDevice {
    public func isIPhoneX() -> Bool {
        if UIScreen.main.bounds.height == 812 {
            return true
        }
        
        return false
    }
}





