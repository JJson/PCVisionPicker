//
//  PCVisionPickerPreviewController.swift
//  PCVisionPicker
//
//  Created by linjj on 2017/12/27.
//  Copyright © 2017年 linjj. All rights reserved.
//

import UIKit
import AVKit

public class PCVisionPickerPreviewController: UIViewController {
    
    var videoUrl:URL?
    var image:UIImage?
    var handleDone:((UIImage?,URL?)->(Void))?
    var playerCtr = AVPlayerViewController()
    
    public override var prefersStatusBarHidden: Bool {
        get {
            return true
        }
    }
    
    @IBOutlet weak var playerControllerContainer: UIView!
    @IBOutlet weak var imageView: UIImageView!
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        if videoUrl != nil {
            playerCtr.showsPlaybackControls = true
            playerCtr.videoGravity = .resizeAspect
            let player = AVPlayer(url: videoUrl!)
            playerCtr.player = player
            playerCtr.view.frame = playerControllerContainer.bounds
            playerControllerContainer.addSubview(playerCtr.view)
            playerCtr.view.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin, .flexibleHeight, .flexibleWidth]
        }
        
        if image != nil {
            imageView.image = image
        }
    }
    
    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: Bundle(for: PCVisionPickerPreviewController.self))
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @IBAction func cancelAction(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }
    @IBAction func confirmAction(_ sender: Any) {
        self.playerCtr.player?.pause()
        handleDone?(image,videoUrl)
    }
    
}

