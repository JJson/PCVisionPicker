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
    
    @IBOutlet weak var imageView: UIImageView!
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        if videoUrl != nil {
            playerCtr.showsPlaybackControls = true
            playerCtr.videoGravity = AVLayerVideoGravity.resizeAspect.rawValue
            let player = AVPlayer(url: videoUrl!)
            playerCtr.player = player
            view.addSubview(playerCtr.view)
        }
        if image != nil {
            imageView.image = image
        }
        // Do any additional setup after loading the view.
    }

    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: Bundle(for: PCVisionPickerPreviewController.self))
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerCtr.view.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height - 55)
    }
    
    @IBAction func cancelAction(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }
    @IBAction func confirmAction(_ sender: Any) {
        self.playerCtr.player?.pause()
        handleDone?(image,videoUrl)
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
