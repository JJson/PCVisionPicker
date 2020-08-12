//
//  NextLevelExtension.swift
//  NextLevel
//
//  Created by linjj on 2020/8/12.
//

import NextLevel

extension NextLevelSession {
    var lastClipThumbnailImage: UIImage? {
        get {
            if !self.clips.isEmpty,
                let lastClip = self.clips.last,
                let thumbnailImage = lastClip.thumbnailImage {
                return thumbnailImage
            } else {
                return nil
            }
        }
    }
}
