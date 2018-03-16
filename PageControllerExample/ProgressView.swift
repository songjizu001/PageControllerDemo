//
//  ProgressView.swift
//  PageControllerExample
//
//  Created by 郑小燕 on 2018/3/9.
//  Copyright © 2018年 郑小燕. All rights reserved.
//

import UIKit

class ProgressView: UIView {
     var itemFrames: [CGRect] = [CGRect]()
     var color: CGColor!
     var progress: CGFloat = 0.0 {
        willSet{
            if progress == newValue {
                return
            }
            self.setNeedsDisplay()
        }
    }
    ///进度条的速度因数，默认为 15，越小越快， 大于 0
     lazy var speedFactor: CGFloat = 15.0
    
     var cornerRadius: CGFloat = 0.0 {
        didSet {
            self.setNeedsDisplay()
        }
    }
    ///调皮属性，用于实现新腾讯视频效果
     var naughty: Bool = false {
        willSet {
            self.naughty = newValue
            self.setNeedsDisplay()
        }
    }
     var isTriangle: Bool = false
     var hollow: Bool = false
     var hasBorder: Bool = false
    
    fileprivate var _sign: Int = 0
    fileprivate var _gap: CGFloat = 0
    fileprivate var _step: CGFloat = 0
    weak fileprivate var _link: CADisplayLink!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required  init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setProgressWithOutAnimate(_ progress: CGFloat) {
        guard self.progress != progress else {
            return
        }
        self.progress = progress
        self.setNeedsDisplay()
    }
    
    func moveToPostion(_ pos: Int) {
        _gap = CGFloat(fabs(Double(self.progress - CGFloat(pos))))
        _sign = self.progress > CGFloat(pos) ? -1 : 1
        _step = _gap / self.speedFactor
        if _link != nil {
            _link.invalidate()
        }
        let link = CADisplayLink(target: self, selector: #selector(progressChanged))
        link.add(to: RunLoop.main, forMode: .commonModes)
        _link = link
        
    }
    
    @objc func progressChanged() {
        if _gap > 0.000001 {
            _gap -= _step
            if _gap < 0.0 {
                self.progress = self.progress + CGFloat(_sign) * _step + 0.5
                return
            }
            self.progress += CGFloat(_sign) * _step
        } else {
            self.progress = self.progress + 0.5
            _link.invalidate()
            _link = nil
        }
    }
    
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override public func draw(_ rect: CGRect) {
        super.draw(rect)
        let ctx = UIGraphicsGetCurrentContext()
        let height = self.frame.height
        var index = Int(self.progress)
        index = (index <= self.itemFrames.count - 1) ? index : self.itemFrames.count - 1
        let rate = self.progress - CGFloat(index)
        guard index < itemFrames.count && index > 0 else {
            return
        }
        let currentFrame = self.itemFrames[index]
        let currentWidth = currentFrame.width
        let nextIndex: Int = index + 1 < self.itemFrames.count ? index + 1 : index
        let nextWidth = self.itemFrames[nextIndex].width
        let currentX = currentFrame.origin.x
        let nextX = self.itemFrames[nextIndex].origin.x
        var startX = currentX + (nextX - currentX) * rate
        var width = currentWidth + (nextWidth - currentWidth)*rate
        var endX = startX + width
        if self.naughty {
            let currentMidX = currentX + currentWidth / 2.0
            let nextMidX = nextX + nextWidth / 2.0
            if rate <= 0.5 {
                startX = currentX + (currentMidX - currentX) * rate * 2.0
                let currentMaxX = currentX + currentWidth
                endX = currentMaxX + (nextMidX - currentMaxX) * rate * 2.0
            } else {
                startX = currentMidX + (nextX - currentMidX) * (rate - 0.5) * 2.0;
                let nextMaxX = nextX + nextWidth;
                endX = nextMidX + (nextMaxX - nextMidX) * (rate - 0.5) * 2.0;
            }
            width = endX - startX
        }
        
        let lineWidth: CGFloat = (self.hollow || self.hasBorder) ? 1.0 : 0.0
        if self.isTriangle {
            ctx?.move(to: CGPoint(x: startX, y: height))
            ctx?.addLine(to: CGPoint(x: endX, y: height))
            ctx?.addLine(to: CGPoint(x: startX + width / 2.0, y: 0))
            ctx?.closePath()
            ctx?.setFillColor(self.color)
            ctx?.fillPath()
            return
        }
        
        let path = UIBezierPath(roundedRect: CGRect(x: startX, y: lineWidth / 2.0, width: width, height: height - lineWidth), cornerRadius: self.cornerRadius)
        ctx?.addPath(path.cgPath)
        if self.hollow {
            ctx?.setStrokeColor(self.color)
            ctx?.strokePath()
            return
        }
        ctx?.setFillColor(self.color)
        if self.hasBorder {
            let startX = self.itemFrames.first?.minX
            let endX = self.itemFrames.last?.maxX
            let path = UIBezierPath(roundedRect: CGRect(x: startX ?? 0, y: lineWidth / 2.0, width: (endX ?? 0 - (startX ?? 0)), height: height - lineWidth), cornerRadius: self.cornerRadius)
            ctx?.setLineWidth(lineWidth)
            ctx?.addPath(path.cgPath)
            ctx?.setStrokeColor(self.color)
            ctx?.strokePath()
        }
    }
    
}
