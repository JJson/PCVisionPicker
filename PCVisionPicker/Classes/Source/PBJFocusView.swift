//
//  PBJFocusView.swift
//  PCVisionPicker
//
//  Created by linjj on 2017/12/27.
//  Copyright © 2017年 linjj. All rights reserved.
//

import UIKit

class PBJFocusView: UIView {
    
    var focusRingView = UIImageView()
    var bundle = Bundle(for: PCVisionPickerViewController.self)
    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        focusRingView = UIImageView(image: UIImage(named: "capture_focus", in: bundle, compatibleWith: nil))
        backgroundColor = UIColor.clear
        contentMode = .scaleToFill
        addSubview(focusRingView)
        self.frame = focusRingView.frame
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        layer.removeAllAnimations()
    }
    
    //MARK: - functions
    func startAnimation () {
        layer.removeAllAnimations()
        transform = CGAffineTransform(scaleX: 1.4, y: 1.4)
        alpha = 0
        
        UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseIn, animations: {
            self.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            self.alpha = 1
        }, completion: { _ in
            
        })
    }
    
    func stopAnimation () {
        layer.removeAllAnimations()
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut, animations: {
            self.transform = CGAffineTransform(scaleX: 0.001, y: 0.001)
        }, completion: { _ in
            self.removeFromSuperview()
        })
    }
}
