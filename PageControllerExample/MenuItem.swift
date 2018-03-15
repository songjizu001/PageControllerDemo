//
//  MenuItem.swift
//  PageControllerExample
//
//  Created by 郑小燕 on 2018/3/9.
//  Copyright © 2018年 郑小燕. All rights reserved.
//

import UIKit

@objc public enum MenuItemState: Int {
    case selected
    case normal
}

public protocol MenuItemDelegate: NSObjectProtocol {
    func didPressedMenuItem(_ menuItem: MenuItem)
}
public class MenuItem: UILabel {
    ///设置rate，并刷新标题状态
    public var rate: CGFloat = 0.0 {
        didSet {
            if self.rate < 0.0 || self.rate > 1.0 {
                return
            }
            let r: CGFloat = _normalRed + (_selectedRed - _normalRed) * rate
            let g = _normalGreen + (_selectedGreen - _normalGreen) * rate
            let b = _normalBlue + (_selectedBlue - _normalBlue) * rate
            let a = _normalAlpha + (_selectedAlpha - _normalAlpha) * rate
            self.textColor = UIColor(red: r, green: g, blue: b, alpha: a)
            let minScale: CGFloat = self.normalSize / self.selectedSize
            let trueScale = minScale + (1 - minScale) * rate
            self.transform = CGAffineTransform(scaleX: trueScale, y: trueScale)
        }
    }
    ///Normal状态的字体大小，默认大小为15
    public var normalSize: CGFloat = 15
    ///Selected状态的字体大小，默认大小为18
    public var selectedSize: CGFloat = 18
    ///Normal状态的字体颜色，默认为黑色
    public var normalColor: UIColor! {
        didSet {
            normalColor.getRed(&_normalRed, green: &_normalGreen, blue: &_normalBlue, alpha: &_normalAlpha)
        }
    }
    ///Selected状态的字体颜色，默认为红色 (可动画)
    public var selectedColor: UIColor! {
        didSet {
        self.selectedColor.getRed(&_selectedRed, green: &_selectedGreen, blue: &_selectedBlue, alpha: &_selectedAlpha)
        }
        
    }
    ///进度条的速度因数，默认 15，越小越快, 必须大于0
    public var speedFactor: CGFloat! {
        didSet {
            if speedFactor <= 0.0 {
                self.speedFactor = 15.0
            }
        }
    }
    
    public var delegate: MenuItemDelegate?
    
    public var selected: Bool = false
    
    fileprivate var _selectedRed: CGFloat = 0
    fileprivate var _selectedGreen: CGFloat = 0
    fileprivate var _selectedBlue: CGFloat = 0
    fileprivate var _selectedAlpha: CGFloat = 0
    fileprivate var _normalRed: CGFloat = 0
    fileprivate var _normalGreen: CGFloat = 0
    fileprivate var _normalBlue: CGFloat = 0
    fileprivate var _normalAlpha: CGFloat = 0
    fileprivate var _sign: Int = 0
    fileprivate var _gap: CGFloat = 0
    fileprivate var _step: CGFloat = 0
    fileprivate var _link: CADisplayLink!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.normalColor =  UIColor.black
        self.selectedColor = UIColor.black
        self.normalSize = 15
        self.selectedSize = 18
        self.numberOfLines = 0
        self.setupGestureRecognizer()
    }
    
    func setupGestureRecognizer() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(touchUpInside(_:)))
        self.addGestureRecognizer(tap)
        
    }
    
    @objc func touchUpInside(_ sender: UITapGestureRecognizer)  {
        guard self.delegate != nil else {
            return
        }
        self.delegate?.didPressedMenuItem(self)
        
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setSelected(_ selected: Bool, animation: Bool) {
        self.selected = selected
        if !animation {
            self.rate = selected ? 1.0 : 0.0
            return
        }
        _sign = (selected == true) ? 1 : -1
        _gap = (selected == true) ? (1.0 - rate) : (rate - 0.0)
        _step = _gap / speedFactor
        
        if _link != nil {
            _link.invalidate()
        }
        let link = CADisplayLink(target: self, selector: #selector(rateChange))
        link.add(to: RunLoop.main, forMode: .commonModes)
        _link = link
        
    }
    
    @objc func rateChange() {
        if _gap > 0.000001 {
            _gap -= _step
            if _gap < 0.0 {
                self.rate = self.rate + CGFloat(_sign) * _step + 0.5
                return
            }
            self.rate += CGFloat(_sign) + _step
        } else {
            self.rate = self.rate + 0.5
            _link.invalidate()
            _link = nil
        }
    }
    
    
    
    
    
    
    
    
    
    
    /*
     // Only override draw() if you perform custom drawing.
     // An empty implementation adversely affects performance during animation.
     override func draw(_ rect: CGRect) {
     // Drawing code
     }
     */
    
}
