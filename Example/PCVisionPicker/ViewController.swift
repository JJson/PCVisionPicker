//
//  ViewController.swift
//  PCVisionPicker
//
//  Created by JJSon on 01/05/2018.
//  Copyright (c) 2018 JJSon. All rights reserved.
//

import UIKit
import PCVisionPicker
class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func buttonAction(_ sender: Any) {
        let ctr = PCVisionPickerViewController(nibName: "PCVisionPickerViewController", bundle: nil)
        ctr.cameraMode = .video
        ctr.skipPreview = true
//        ctr.maxDuration = 5
        
        ctr.handleForSpaceListner = { (space) in
            print("space: \(space)")
            if space < 80 * 1024 * 1024 {
                ctr.stopVideoCapture()
            }
        }
        ctr.handleDone = {image,videoUrl in
            if image != nil {
                let path = NSHomeDirectory() + "/Documents/image.jpg"
                let imageData = image!.jpegData(compressionQuality: 1)
                try? imageData?.write(to: URL(fileURLWithPath: path))
            }
            if videoUrl != nil {
                let path = NSHomeDirectory() + "/Documents/video\(arc4random()%100000).mp4"
                try? FileManager.default.moveItem(at: videoUrl!, to: URL(fileURLWithPath: path))
            }
        }
        let navCtr = UINavigationController(rootViewController: ctr)
        present(navCtr, animated: true) {
            
        }
    }
}

