//
//  PCVisionPickerViewController.swift
//  PCVisionPicker
//
//  Created by linjj on 2017/12/26.
//  Copyright © 2017年 linjj. All rights reserved.
//

import UIKit
import NextLevel
import CoreMedia
import ImageIO
import AVFoundation
import Photos
import MediaPlayer

public enum PCVisionPickerMode {
    case photo
    case video
    func toNextLevelCaptureMode() -> NextLevelCaptureMode {
        switch self {
            
        case .photo:
            return .photo
        case .video:
            return .video
        }
    }
}

public enum PCVisionPickerFlashMode: Int {
    case off = 0
    case on
    case auto
    
    func next() -> PCVisionPickerFlashMode {
        let value = self.rawValue + 1
        if  value <= PCVisionPickerFlashMode.auto.rawValue{
            let result = PCVisionPickerFlashMode(rawValue: value)
            return result!
        }
        else {
            return .off
        }
    }
    
    func toNextLevelFlashMode() -> NextLevelFlashMode {
        switch self {
        
        case .off:
            return .off
        case .on:
            return .on
        case .auto:
            return .auto
        }
    }
    
    func toNextLevelTorchMode() -> NextLevelTorchMode {
        switch self {
        
        case .off:
            return .off
        case .on:
            return .on
        case .auto:
            return .auto
        }
    }
}

extension NextLevelDevicePosition {
    func next() -> NextLevelDevicePosition {
        let value = self.rawValue + 1
        if  value <= NextLevelDevicePosition.front.rawValue{
            let result = NextLevelDevicePosition(rawValue: value)
            return result!
        }
        else {
            return .back
        }
        
    }
}


public class PCVisionPickerViewController: UIViewController {
    public var cameraMode:PCVisionPickerMode = .photo
    public var flashMode:PCVisionPickerFlashMode = .auto {
        didSet{
            updateFlashMode()
        }
    }
    var nextLevel = NextLevel.shared
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
    /// 存储空间监听
    public var handleForSpaceListner:((Int64)->Void)?
    /// 是否跳过预览视图
    public var skipPreview = false
    /// 最大时长
    public var maxDuration = -1
    /// 是否显示黑屏开关
    public var showDarkScreen = false
    
    let focusView = PBJFocusView(frame: CGRect.zero)
    @IBOutlet weak var lbTimeTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var previewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var lbTime: UILabel!
    @IBOutlet weak var btLight: UIButton!
    @IBOutlet weak var btStart: UIButton!
    @IBOutlet weak var btDarkScreen: UIButton!
    @IBOutlet weak var btSwitch: UIButton!
    
    fileprivate let orginIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
    /// 是否已经适配safeArea
    fileprivate var hasOffsetForSafeArea = false
    
    fileprivate var camaraAuthReady = false
    fileprivate var micAuthReady = false
    
    fileprivate var orginBrightness = UIScreen.main.brightness
    fileprivate var timerForDarkScreen: Timer?
    
    fileprivate lazy var blackView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        return view
    }()
    
    fileprivate var bDarkScreen: Bool = false {
        didSet {
            guard bDarkScreen != oldValue else {return}
            if bDarkScreen {
                orginBrightness = UIScreen.main.brightness
                
                if let window = UIApplication.shared.keyWindow {
                    blackView.frame = window.bounds
                    window.addSubview(blackView)
                }
                
                timerForDarkScreen = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true, block: { _ in
                    if UIScreen.main.brightness > 0.01 {
                        UIScreen.main.brightness = 0.01
                        UIScreen.main.brightness = 0
                    }
                    
                })
            } else {
                timerForDarkScreen?.invalidate()
                UIScreen.main.brightness = 0.02
                UIScreen.main.brightness = orginBrightness
                blackView.removeFromSuperview()
            }
        }
    }
    
    internal var volumeValueObservation: NSKeyValueObservation?
    
    public override var prefersStatusBarHidden: Bool {
        get {
            return true
        }
    }
    override public func viewDidLoad() {
        super.viewDidLoad()
        if cameraMode == .photo {
            lbTime.isHidden = true
            showDarkScreen = false
            
        }
        else {
            lbTime.isHidden = false
        }
        btDarkScreen.isHidden = !showDarkScreen
        if showDarkScreen {
            flashMode = .off
        }
        // Do any additional setup after loading the view.
        nextLevel.delegate = self
        nextLevel.deviceDelegate = self
        nextLevel.flashDelegate = self
        nextLevel.videoDelegate = self
        nextLevel.photoDelegate = self
        if showDarkScreen {
            do {
                let audioSession = AVAudioSession.sharedInstance()
                
                try audioSession.setActive(true) // <- Important
                
                volumeValueObservation = audioSession.observe(\.outputVolume) { [weak self] (av, _) in
                    guard let strongSelf = self else { return }
                    strongSelf.bDarkScreen = false
                }
            } catch {}
        }
        
        if #available(iOS 11.0, *) {
            setNeedsUpdateOfHomeIndicatorAutoHidden()
        } else {
            // Fallback on earlier versions
        }
        
        let mpVolumeView = MPVolumeView()
        mpVolumeView.frame = CGRect(x: -500, y: -500, width: 10, height: 10)
        view.addSubview(mpVolumeView)
    }
    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: Bundle(for: PCVisionPickerViewController.self))
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    deinit {
        nextLevel.stop()
        print("PCVisionPickerViewController deinit")
    }
    
    override public func viewSafeAreaInsetsDidChange() {
        if #available(iOS 11.0, *) {
            super.viewSafeAreaInsetsDidChange()
            guard hasOffsetForSafeArea == false else { return }
            guard UIDevice.current.isIPhoneX() else { return }
            lbTimeTopConstraint.constant += view.safeAreaInsets.top
            previewTopConstraint.constant += view.safeAreaInsets.top
            bottomConstraint.constant = view.safeAreaInsets.bottom
            hasOffsetForSafeArea = true
        } else {
            // Fallback on earlier versions
        }
        
    }
    
    override public func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    public override var prefersHomeIndicatorAutoHidden: Bool {
        get {
            return true
        }
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: animated)

    }
    
    fileprivate func prepare() {
        do {
            initViews()
            SwiftProgressHUD.showWait()
            resetCapture()
            try nextLevel.start()
        } catch {
            print("NextLevel, failed to start camera session")
        }
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if NextLevel.authorizationStatus(forMediaType: AVMediaType.video) == .authorized &&
            NextLevel.authorizationStatus(forMediaType: AVMediaType.audio) == .authorized {
            prepare()
        } else {
            let group = DispatchGroup()
            group.enter()
            NextLevel.requestAuthorization(forMediaType: .video) { [weak self] (_, status) in
                guard let strongSelf = self else { return }
                if status == .notAuthorized {

                } else {
                    strongSelf.camaraAuthReady = true
                }
                group.leave()
            }
            group.enter()
            NextLevel.requestAuthorization(forMediaType: .audio) {[weak self] (_, status) in
                guard let strongSelf = self else { return }
                if status == .notAuthorized {
                    
                } else {
                    strongSelf.micAuthReady = true
                }
                group.leave()
            }
            
            group.notify(queue: .main) { [weak self] in
                guard let strongSelf = self else { return }
                if !strongSelf.camaraAuthReady {
                    let alert = UIAlertController(title: "提示", message: "请开启摄像头权限", preferredStyle: .alert)
                    let action = UIAlertAction(title: "确定", style: .default) { (_) in
                        if let rootCtr = strongSelf.navigationController?.viewControllers.first,
                            rootCtr != strongSelf {
                            strongSelf.navigationController?.popViewController(animated: true)
                        } else {
                            strongSelf.dismiss(animated: true, completion: nil)
                        }
                    }
                    alert.addAction(action)
                    strongSelf.present(alert, animated: true, completion: nil)
                } else if !strongSelf.micAuthReady,
                    strongSelf.cameraMode != .photo {
                    let alert = UIAlertController(title: "提示", message: "请开启麦克风权限", preferredStyle: .alert)
                    let action = UIAlertAction(title: "确定", style: .default) { (_) in
                        if let rootCtr = strongSelf.navigationController?.viewControllers.first,
                            rootCtr != strongSelf {
                            strongSelf.navigationController?.popViewController(animated: true)
                        } else {
                            strongSelf.dismiss(animated: true, completion: nil)
                        }
                    }
                    alert.addAction(action)
                    strongSelf.present(alert, animated: true, completion: nil)
                } else {
                    strongSelf.prepare()
                }
                
            }
        }
    }
    
    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if nextLevel.isRecording {
            nextLevel.pause()
        }
        nextLevel.stop()
    }
    
    func updateFlashMode() {
        if cameraMode == .photo {
            nextLevel.flashMode = flashMode.toNextLevelFlashMode()
        } else {
            nextLevel.torchMode = flashMode.toNextLevelTorchMode()
        }
        switch flashMode {
        case .auto:
            btLight.setImage(UIImage(named: "light_auto", in: bundle, compatibleWith: nil), for: .normal)
        case .off:
            btLight.setImage(UIImage(named: "light_off", in: bundle, compatibleWith: nil), for: .normal)
        case .on:
            btLight.setImage(UIImage(named: "light_on", in: bundle, compatibleWith: nil), for: .normal)
        }
    }
    
    // MARK: - functions
    func initViews() {

        previewView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        previewView.backgroundColor = UIColor.black
        NextLevel.shared.previewLayer.frame = previewView.bounds
        NextLevel.shared.previewLayer.videoGravity = .resizeAspectFill
        previewView.layer.addSublayer(NextLevel.shared.previewLayer)
    }
    
    func diskSpaceFree() -> Int64? {
        
        if #available(iOS 11.0, *) {
            let fileURL = URL(fileURLWithPath: NSHomeDirectory() as String)
            do {
                let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
                return values.volumeAvailableCapacityForImportantUsage
            } catch {
                print("Error retrieving capacity: \(error.localizedDescription)")
            }
        } else {
            // Fallback on earlier versions
            if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
                let freeSize = attrs[.systemFreeSize] as? NSNumber {
                    return freeSize.int64Value
            }
        }

        return nil
    }
    
    func resetCapture() {

        nextLevel.devicePosition = .back
        nextLevel.captureMode = cameraMode.toNextLevelCaptureMode()
        nextLevel.deviceOrientation = .portrait

        if cameraMode == .photo {
            nextLevel.photoConfiguration.preset = .hd1280x720
            if #available(iOS 11.0, *) {
                nextLevel.photoConfiguration.codec = .jpeg
            } else {
                
            }
        }
        else {
            if UIDevice.current.isIPhoneX() {
                nextLevel.videoConfiguration.preset = .hd1280x720

            }
            else {
                nextLevel.videoConfiguration.preset = .hd1920x1080
            }
            nextLevel.videoConfiguration.bitRate = 1920*1080*3
            nextLevel.videoConfiguration.profileLevel = AVVideoProfileLevelH264BaselineAutoLevel
            if maxDuration > 0 {
                nextLevel.videoConfiguration.maximumCaptureDuration = CMTimeMakeWithSeconds(Float64(maxDuration), preferredTimescale: 1)
            }
        }
    }
    
    func photoDidCaptured(withData photoData: Data, metaData: [String: Any]) {
        if let image = UIImage(imageData: photoData, metaData: metaData) {
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
    
    func videoDidCaptured() {
        // called when a configuration time limit is specified
        if let videoUrl = NextLevel.shared.session?.lastClipUrl,
            let thumb = NextLevel.shared.session?.lastClipThumbnailImage {
            if skipPreview {
                self.dismiss(animated: true, completion: {
                    self.handleDone?(thumb,videoUrl)
                })
            } else {
                let ctr = PCVisionPickerPreviewController(nibName: "PCVisionPickerPreviewController", bundle: nil)
                ctr.videoUrl = videoUrl
                ctr.handleDone = {[weak self] _,videoUrl in
                    self?.dismiss(animated: true, completion: {
                        self?.handleDone?(thumb,videoUrl)
                    })
                }
                
                lbTime.text = "00:00:00"
                navigationController?.pushViewController(ctr, animated: true)
            }
        } else {
            // prompt that the video has been saved
            // todo: handleDone返回形式
            let alertController = UIAlertController(title: "Oops!", message: "An error occured!", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
            alertController.addAction(okAction)
            self.present(alertController, animated: true, completion: nil)
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
        if cameraMode == .photo {
            nextLevel.flashMode = flashMode.toNextLevelFlashMode()
        } else {
            nextLevel.torchMode = flashMode.toNextLevelTorchMode()
        }
        
    }
    
    @IBAction func switchCameraAction(_ sender: Any) {
        nextLevel.devicePosition = nextLevel.devicePosition.next()
    }
    
    @IBAction func startAction(_ sender: Any) {
        if cameraMode == .photo {
            nextLevel.capturePhoto()
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
        if nextLevel.isRecording {
            SwiftProgressHUD.showWait()
            touchEnable = false
            nextLevel.pause { [weak self] in
                guard let strongSelf = self else { return }
                SwiftProgressHUD.hideAllHUD()
                strongSelf.videoDidCaptured()
            }
        }
    }
    public func startVideoCapture() {
        if !nextLevel.isRecording {
            nextLevel.record()
        }
    
    }
    @IBAction func cancelAction(_ sender: Any) {
        self.dismiss(animated: true) {
            
        }
    }
    @IBAction func darkScreenAction(_ sender: Any) {
        bDarkScreen = true
    }
    
    
    
    @IBAction func handleFocusTapGesterRecognizer(gestureRecognizer:UIGestureRecognizer) {
        let tapPoint = gestureRecognizer.location(in: previewView)
        focusView.center = tapPoint
        previewView.addSubview(focusView)
        focusView.startAnimation()
        let previewLayer = nextLevel.previewLayer
        let  adjustPoint = previewLayer.captureDevicePointConverted(fromLayerPoint: tapPoint)
        nextLevel.focusExposeAndAdjustWhiteBalance(atAdjustedPoint: adjustPoint)
    }
    
}

extension PCVisionPickerViewController: NextLevelDelegate {
    public func nextLevel(_ nextLevel: NextLevel, didUpdateVideoConfiguration videoConfiguration: NextLevelVideoConfiguration) {
        
    }
    
    public func nextLevel(_ nextLevel: NextLevel, didUpdateAudioConfiguration audioConfiguration: NextLevelAudioConfiguration) {
        
    }
    
    public func nextLevelSessionWillStart(_ nextLevel: NextLevel) {
        
    }
    
    public func nextLevelSessionDidStart(_ nextLevel: NextLevel) {
        updateFlashMode()
        SwiftProgressHUD.hideAllHUD()
    }
    
    public func nextLevelSessionDidStop(_ nextLevel: NextLevel) {
        
    }
    
    public func nextLevelSessionWasInterrupted(_ nextLevel: NextLevel) {
        if recording    {
            stopVideoCapture()
        }
    }
    
    public func nextLevelSessionInterruptionEnded(_ nextLevel: NextLevel) {
        
    }
    
    public func nextLevelCaptureModeWillChange(_ nextLevel: NextLevel) {
        
    }
    
    public func nextLevelCaptureModeDidChange(_ nextLevel: NextLevel) {
        
    }
    

}

// MARK: NextLevelDeviceDelegate
extension PCVisionPickerViewController: NextLevelDeviceDelegate {
    public func nextLevel(_ nextLevel: NextLevel, didChangeLensPosition lensPosition: Float) {
        
    }
    

    // position, orientation
    public func nextLevelDevicePositionWillChange(_ nextLevel: NextLevel) {
    }
    
    public func nextLevelDevicePositionDidChange(_ nextLevel: NextLevel) {
    }
    
    public func nextLevel(_ nextLevel: NextLevel, didChangeDeviceOrientation deviceOrientation: NextLevelDeviceOrientation) {
    }
    
    // format
    public func nextLevel(_ nextLevel: NextLevel, didChangeDeviceFormat deviceFormat: AVCaptureDevice.Format) {
    }
    
    // aperture
    public func nextLevel(_ nextLevel: NextLevel, didChangeCleanAperture cleanAperture: CGRect) {
    }
    
    // focus, exposure, white balance
    public func nextLevelWillStartFocus(_ nextLevel: NextLevel) {
    }
    
    public func nextLevelDidStopFocus(_  nextLevel: NextLevel) {
        DispatchQueue.main.async {[weak self] in
            self?.focusView.stopAnimation()
        }
    }
    
    public func nextLevelWillChangeExposure(_ nextLevel: NextLevel) {
    }
    
    public func nextLevelDidChangeExposure(_ nextLevel: NextLevel) {
        if focusView.superview != nil {
            focusView.stopAnimation()
        }
    }
    
    public func nextLevelWillChangeWhiteBalance(_ nextLevel: NextLevel) {
    }
    
    public func nextLevelDidChangeWhiteBalance(_ nextLevel: NextLevel) {
    }
    
}

// MARK: NextLevelFlashAndTorchDelegate
extension PCVisionPickerViewController: NextLevelFlashAndTorchDelegate {
    
    public func nextLevelDidChangeFlashMode(_ nextLevel: NextLevel) {
    }
    
    public func nextLevelDidChangeTorchMode(_ nextLevel: NextLevel) {
    }
    
    public func nextLevelFlashActiveChanged(_ nextLevel: NextLevel) {
    }
    
    public func nextLevelTorchActiveChanged(_ nextLevel: NextLevel) {
    }
    
    public func nextLevelFlashAndTorchAvailabilityChanged(_ nextLevel: NextLevel) {
    }

}

// MARK: - NextLevelVideoDelegate

extension PCVisionPickerViewController: NextLevelVideoDelegate {
    public func nextLevel(_ nextLevel: NextLevel, willProcessFrame frame: AnyObject, timestamp: TimeInterval, onQueue queue: DispatchQueue) {
        
    }
    

    // video zoom
    public func nextLevel(_ nextLevel: NextLevel, didUpdateVideoZoomFactor videoZoomFactor: Float) {
    }

    // video frame processing
    public func nextLevel(_ nextLevel: NextLevel, willProcessRawVideoSampleBuffer sampleBuffer: CMSampleBuffer, onQueue queue: DispatchQueue) {
    }
    
    @available(iOS 11.0, *)
    public func nextLevel(_ nextLevel: NextLevel, willProcessFrame frame: AnyObject, pixelBuffer: CVPixelBuffer, timestamp: TimeInterval, onQueue queue: DispatchQueue) {
    }
    
    // enabled by isCustomContextVideoRenderingEnabled
    public func nextLevel(_ nextLevel: NextLevel, renderToCustomContextWithImageBuffer imageBuffer: CVPixelBuffer, onQueue queue: DispatchQueue) {
    }
    
    // video recording session
    public func nextLevel(_ nextLevel: NextLevel, didSetupVideoInSession session: NextLevelSession) {

    }
    
    public func nextLevel(_ nextLevel: NextLevel, didSetupAudioInSession session: NextLevelSession) {
    }
    
    public func nextLevel(_ nextLevel: NextLevel, didStartClipInSession session: NextLevelSession) {
        recording = true
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    public func nextLevel(_ nextLevel: NextLevel, didCompleteClip clip: NextLevelClip, inSession session: NextLevelSession) {
        recording = false
        UIApplication.shared.isIdleTimerDisabled = orginIdleTimerDisabled
    }
    
    public func nextLevel(_ nextLevel: NextLevel, didAppendVideoSampleBuffer sampleBuffer: CMSampleBuffer, inSession session: NextLevelSession) {
        guard let seconds = nextLevel.session?.totalDuration.seconds else { return }
        let hour = Int(seconds / (60*60))
        let minute = Int((seconds / 60).truncatingRemainder(dividingBy: 60))
        let second = Int(seconds.truncatingRemainder(dividingBy: 60))
        lbTime.text = String(format: "%02d:%02d:%02d", hour,minute,second)
        if let space = diskSpaceFree(), touchEnable {
            handleForSpaceListner?(space)
        }
        
    }
    
    public func nextLevel(_ nextLevel: NextLevel, didAppendAudioSampleBuffer sampleBuffer: CMSampleBuffer, inSession session: NextLevelSession) {
    }
    
    public func nextLevel(_ nextLevel: NextLevel, didAppendVideoPixelBuffer pixelBuffer: CVPixelBuffer, timestamp: TimeInterval, inSession session: NextLevelSession) {
    }
    
    public func nextLevel(_ nextLevel: NextLevel, didSkipVideoPixelBuffer pixelBuffer: CVPixelBuffer, timestamp: TimeInterval, inSession session: NextLevelSession) {
    }
    
    public func nextLevel(_ nextLevel: NextLevel, didSkipVideoSampleBuffer sampleBuffer: CMSampleBuffer, inSession session: NextLevelSession) {
    }
    
    public func nextLevel(_ nextLevel: NextLevel, didSkipAudioSampleBuffer sampleBuffer: CMSampleBuffer, inSession session: NextLevelSession) {
    }
    
    public func nextLevel(_ nextLevel: NextLevel, didCompleteSession session: NextLevelSession) {
        // called when a configuration time limit is specified
        videoDidCaptured()
        
    }
    
    // video frame photo

    public func nextLevel(_ nextLevel: NextLevel, didCompletePhotoCaptureFromVideoFrame photoDict: [String : Any]?) {
        
    }
    
}

// MARK: - NextLevelPhotoDelegate

extension PCVisionPickerViewController: NextLevelPhotoDelegate {
    @available(iOS 11.0, *)
    public func nextLevel(_ nextLevel: NextLevel, didFinishProcessingPhoto photo: AVCapturePhoto) {
        if let photoData = photo.fileDataRepresentation() {
            photoDidCaptured(withData: photoData, metaData: photo.metadata)
        }
    }
    
    
    // photo
    public func nextLevel(_ nextLevel: NextLevel, willCapturePhotoWithConfiguration photoConfiguration: NextLevelPhotoConfiguration) {
    }
    
    public func nextLevel(_ nextLevel: NextLevel, didCapturePhotoWithConfiguration photoConfiguration: NextLevelPhotoConfiguration) {
        
        
    }
    
    public func nextLevel(_ nextLevel: NextLevel, didProcessPhotoCaptureWith photoDict: [String : Any]?, photoConfiguration: NextLevelPhotoConfiguration) {
        
        if let dictionary = photoDict,
            let photoData = dictionary[NextLevelPhotoJPEGKey] as? Data,
            let metaData = dictionary[NextLevelPhotoMetadataKey] as? [String: Any] {
            photoDidCaptured(withData: photoData, metaData: metaData)

        }
        
    }
    
    public func nextLevel(_ nextLevel: NextLevel, didProcessRawPhotoCaptureWith photoDict: [String : Any]?, photoConfiguration: NextLevelPhotoConfiguration) {
        
    }

    public func nextLevelDidCompletePhotoCapture(_ nextLevel: NextLevel) {
        
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
        } else if UIApplication.shared.statusBarFrame.height == 44 {
            return true
        }  else if #available(iOS 11.0, *), let bottom = UIApplication.shared.keyWindow?.safeAreaInsets.bottom, bottom > 0 {
            return true
        }
        
        return false
    }
}





