//
//  MenuView.swift
//  PageControllerExample
//
//  Created by 郑小燕 on 2018/3/9.
//  Copyright © 2018年 郑小燕. All rights reserved.
//

import UIKit

public enum MenuViewStyle {
    case `default`// 默认
    case  line// 带下划线 (若要选中字体大小不变，设置选中和非选中大小一样即可)
    case  triangle // 三角形 (progressHeight 为三角形的高, progressWidths 为底边长)
    case  flood // 涌入效果 (填充)
    case  floodHollow // 涌入效果 (空心的)
    case  segmented // 涌入带边框,即网易新闻选项卡
    
}

public enum MenuViewLayoutMode {
    case scatter      // 默认的布局模式, item 会均匀分布在屏幕上，呈分散状
    case left        // Item 紧靠屏幕左侧
    case right       // Item 紧靠屏幕右侧
    case center      // Item 紧挨且居中分布
}

@objc protocol MenuViewDelegate: NSObjectProtocol {
    @objc optional func menuView(_ menu: MenuView, shouldSelesctedIndex index: Int ) -> Bool
    @objc optional func menuView(_ menu: MenuView, didSelectedIndex index: Int, _ currentIndex: Int)
    @objc optional func menuView(_ menu: MenuView, widthForItemAtIndex index: Int) -> CGFloat
    @objc optional func menuView(_ menu: MenuView, itemMarginAtIndex index: Int) -> CGFloat
    @objc optional func menuView(_ menu: MenuView, titleSizeForState state: MenuItemState, atIndex index: Int) -> CGFloat
    @objc optional func menuView(_ menu: MenuView, titleColorForState state: MenuItemState, atIndex index: Int) -> UIColor
    @objc optional func menuView(_ menu: MenuView, didLayoutItemFrame menuItem: MenuItem, atIndex index: Int)
}

@objc protocol MenuViewDataSource: NSObjectProtocol {
    func numbersOfTitlesInMenuView(_ menuView: MenuView) -> Int
    func menuView(_ menuView: MenuView, titleAtIndex index: Int) -> String
    
    /// 角标 (例如消息提醒的小红点) 的数据源方法，在 WMPageController 中实现这个方法来为 menuView 提供一个 badgeView  需要在返回的时候同时设置角标的 frame 属性，该 frame 为相对于 menuItem 的位置
    ///
    /// - Parameters:
    ///   - menu: menuView
    ///   - index: 角标的序号
    /// - Returns: 返回一个设置好 frame 的角标视图
    @objc optional func menuView(_ menu: MenuView, badgeViewAtIndex index: Int) -> UIView?
    
    
    /// 用于定制 MenuItem，可以对传出的 initialMenuItem 进行修改定制，也可以返回自己创建的子类，需要注意的是，此时的 item 的 frame 是不确定的，所以请勿根据此时的 frame 做计算！如需根据 frame 修改，请使用代理
    ///
    /// - Parameters:
    ///   - menu: 当前的 menuView,frame 也是不确定的
    ///   - item: 初始化完成的 menuItem
    ///   - index: Item 所属的位置
    /// - Returns: 定制完成的 MenuItem
    @objc optional func menuView(_ menu: MenuView, initialMenuItem item: MenuItem, atIndex index: Int) -> MenuItem
}

open class MenuView: UIView, MenuItemDelegate {
    
    
    open override var frame: CGRect {
        didSet {
            guard self.scrollView != nil else {
                return
            }
            let leftMargin: CGFloat = self.contentMargin
            let rightMargin: CGFloat = self.contentMargin
            let contentWidth: CGFloat = self.scrollView.frame.width + leftMargin + rightMargin
            let startX: CGFloat = (self.leftView != nil) ? self.leftView!.frame.origin.x : self.scrollView.frame.origin.x - self.contentMargin
            // Make the contentView center, because system will change menuView's frame if it's a titleView.
            if startX + contentWidth / 2 != self.bounds.size.width / 2 {
                let xOffset: CGFloat = (self.bounds.size.width - contentWidth) / 2
                self.leftView?.frame = {
                    var frame = self.leftView?.frame
                    frame?.origin.x = xOffset
                    return frame ?? CGRect.zero
                }()
                
                self.scrollView.frame = {
                    var frame = self.scrollView.frame
                    frame.origin.x = (self.leftView != nil) ? (self.leftView?.frame.maxX)! + self.contentMargin : xOffset
                    return frame
                }()
                self.rightView?.frame = {
                    var frame = self.rightView?.frame
                    frame?.origin.x = self.scrollView.frame.maxX + self.contentMargin
                    return frame!
                }()
                
            }
        }
    }
    public var progressWidths: [CGFloat] = [] {
        didSet {
            guard self.progressView.superview != nil else {
                return
            }
            self.resetFramesFromIndex(inde: 0)
        }
    }
    public var progressView: ProgressView!
    public var progressHeight: CGFloat {
        get{
            switch self.style {
            case .line:
                return getHeight(self.progressHeight)
            case .triangle:
                return getHeight(self.progressHeight)
            case .flood:
                return getHeight(self.progressHeight, CGFloat(ceil(self.frame.height * 0.8)))
            case .segmented:
                return getHeight(self.progressHeight, CGFloat(ceil(self.frame.height * 0.8)))
            case .floodHollow:
                return getHeight(self.progressHeight, CGFloat(ceil(self.frame.height * 0.8)))
            default:
                return self.progressHeight
            }
        }
        set {
            
        }
    }
    func getHeight(_ newHeight: CGFloat, _ defaultHeight: CGFloat = 2) -> CGFloat {
        return (newHeight != defaultHeight) ? newHeight : defaultHeight
    }
    public var style: MenuViewStyle!
    public var layoutMode: MenuViewLayoutMode = .left {
        didSet {
            guard self.superview != nil else {
                return
            }
            self.reload()
        }
    }
    
    public var contentMargin: CGFloat = 0.0 {
        didSet {
            guard self.scrollView != nil else {
                return
            }
            self.resetFrames()
        }
//        get {
//            return self.contentMargin
//        }
    }
    
    lazy var lineColor: UIColor? = {
        if self.lineColor == nil {
            self.lineColor = self.colorForState(state: .selected, atIndex: 0)
        }
        return self.lineColor
    }()
    
    func colorForState(state: MenuItemState, atIndex index: Int) -> UIColor? {
        if let color = self.delegate?.menuView?(self, titleColorForState: state, atIndex: index) {
            return color
        }
        return UIColor.black
    }
    
    public var progressViewBottomSpace: CGFloat!
    var delegate: MenuViewDelegate?
    var dataSource: MenuViewDataSource!
    public var leftView: UIView? {
        willSet {
            leftView?.removeFromSuperview()
        }
        didSet {
            if let lView = leftView {
                self.addSubview(lView)
            }
            self.resetFrames()
        }
    }
    
    public var rightView: UIView? {
        willSet {
            rightView?.removeFromSuperview()
        }
        didSet {
            if let rView = rightView {
                self.addSubview(rView)
            }
            self.resetFrames()
        }
    }
    public var fontName: String!
    public var scrollView: UIScrollView!
    /// 进度条的速度因数，默认为 15，越小越快， 大于 0
    public var speedFactor: CGFloat = 0.0 {
        didSet {
            if self.progressView != nil {
                self.progressView.speedFactor = speedFactor
            }
            for (_, view) in self.scrollView.subviews.enumerated() {
                if view is MenuItem {
                    let itemView = view as! MenuItem
                    itemView.speedFactor = speedFactor
                }
            }
        }
    }
    
    public var progressViewCornerRadius: CGFloat? {
        set {
            if self.progressView != nil {
                self.progressView.cornerRadius = progressViewCornerRadius!
            }
        }
        get {
            return getHeight(self.progressViewCornerRadius!, self.progressHeight / 2.0)
        }
    }
    public var progressViewIsNaughty: Bool = false {
        didSet {
            guard self.progressView != nil else {
                return
            }
            self.progressView.naughty = progressViewIsNaughty
        }
    }
    public var showOnNavigationBar: Bool!
    
    //filePrivate
    fileprivate var selItem: MenuItem!
    lazy var frames: [CGRect] = {
        return [CGRect]()
    }()
    fileprivate var selectIndex: Int!
    //MARK: - Data Source
    lazy var titlesCount: Int = {
        return self.dataSource.numbersOfTitlesInMenuView(self)
    }()
    fileprivate let WMMENUITEM_TAG_OFFSET = 6250
    fileprivate let WMBADGEVIEW_TAG_OFFSET = 1212
    fileprivate let WMUNDEFINED_VALUE: CGFloat = -1
    
    
    //MARK: Init
    public override init(frame: CGRect) {
        super.init(frame: self.frame)
        self.progressViewCornerRadius = WMUNDEFINED_VALUE
        self.progressHeight = WMUNDEFINED_VALUE
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //MARK: - Method
    public func slideMenuAtProgress(_ progress: CGFloat) {
        if self.progressView != nil {
            self.progressView.progress = progress
        }
        let tag = Int(progress) + WMMENUITEM_TAG_OFFSET
        let rate: CGFloat = progress - CGFloat(tag) + CGFloat(WMMENUITEM_TAG_OFFSET)
        let currentItem = self.viewWithTag(tag) as? MenuItem
        let nextItem = self.viewWithTag(tag + 1) as? MenuItem
        if rate == 0.0 {
            self.selItem.setSelected(false, animation: false)
            self.selItem = currentItem
            selItem.setSelected(true, animation: false)
            self.refreshContenOffset()
            return
        }
        currentItem?.rate = 1.0 - rate
        nextItem?.rate = rate
        
        
        
        
    }
    
    public func selectItemAtIndex(_ index: Int) {
        let tag = index + WMMENUITEM_TAG_OFFSET
        let currentIndex = self.selItem.tag - WMMENUITEM_TAG_OFFSET
        self.selectIndex = index
        guard index != currentIndex && self.selItem != nil else {
            return
        }
        let item = self.viewWithTag(tag) as? MenuItem
        self.selItem.setSelected(false, animation: false)
        self.selItem = item
        self.selItem.setSelected(true, animation: false)
        self.progressView.setProgressWithOutAnimate(CGFloat(index))
        delegate?.menuView?(self, didSelectedIndex: index, currentIndex)
        self.refreshContenOffset()
    }
    
    public func resetFrames() {
        var frame = self.bounds
        if let rView = rightView {
            var rightFrame = rView.frame
            rightFrame.origin.x = frame.width - rightFrame.width
            rightView?.frame = rightFrame
            frame.size.width -= rightFrame.width
        }
        if let lView = leftView {
            var leftFrame = lView.frame
            leftFrame.origin.x = 0
            leftView?.frame = leftFrame
            frame.origin.x += leftFrame.width
            frame.size.width -= leftFrame.width
        }
        frame.origin.x += self.contentMargin
        frame.size.width -= self.contentMargin * 2
        self.scrollView.frame = frame
        self.resetFramesFromIndex(inde: 0)
    }
    
    public func reload() {
        self.frames.removeAll()
        self.progressView.removeFromSuperview()
        for (_, view) in self.scrollView.subviews.enumerated() {
            view.removeFromSuperview()
        }
        self.addItems()
        self.makeStyle()
        self.addBadgeViews()
    }
    
    public func updateTitle(title: String, atIndex index: Int, andWidth update: Bool) {
        guard index < titlesCount && titlesCount > 0 else {
            return
        }
        let item = self.viewWithTag(WMMENUITEM_TAG_OFFSET + index) as? MenuItem
        item?.text = title
        guard update else {
            return
        }
        self.resetFrames()
    }
    
    public func updateAttributeTitle(title: NSAttributedString, atIndex index: Int, andWidth update: Bool) {
        guard index < self.titlesCount && index > 0 else {
            return
        }
        let item = self.viewWithTag(WMMENUITEM_TAG_OFFSET + index) as? MenuItem
        item?.attributedText = title
        guard update else {
            return
        }
        self.resetFrames()
        
    }
    
    public func itemAtIndex(index: Int) -> MenuItem? {
        let view = self.viewWithTag(index + WMMENUITEM_TAG_OFFSET)
        if view is MenuItem{
            return (view as! MenuItem)
        } else {
            return nil
        }
    }
    
    /// 立即刷新 menuView 的 contentOffset，使 title 居中
    ///让选中的item位于中间
    public func refreshContenOffset() {
        let frame = self.selItem.frame
        let itemX = frame.origin.x
        let width = self.scrollView.frame.size.width
        let contentSize = self.scrollView.contentSize
        if itemX > width / 2 {
            var targetX : CGFloat = 0
            if (contentSize.width - itemX) <= width / 2 {
                targetX = contentSize.width - width
            } else {
                targetX = frame.origin.x - width / 2 + frame.size.width / 2
            }
            //应该有更好的解决办法
            if targetX + width > contentSize.width {
                targetX = contentSize.width - width
            }
            self.scrollView.setContentOffset(CGPoint(x: targetX, y: 0), animated: true)
            
        } else {
            self.scrollView.setContentOffset(CGPoint(x: 0, y: 0), animated: true)
        }
    }
    
    public func deselectedItemsIfNeeded() {
        for (_, view) in self.scrollView.subviews.enumerated() {
            guard view is MenuItem, view != self.selItem else {
                return
            }
            let subView = view as? MenuItem
            subView?.setSelected(false, animation: false)
        }
        
    }
    
    public func updateBadgeViewAtIndex(index: Int) {
        let oldBadgeView = self.scrollView.viewWithTag(WMBADGEVIEW_TAG_OFFSET + index)
        if oldBadgeView != nil {
            oldBadgeView?.removeFromSuperview()
        }
        self.addBadgeViewAtIndex(index)
        self.resetBadgeFrame(index)
    }
    
    //MARK: - filePrivateMethod
    fileprivate func resetFramesFromIndex(inde: Int) {
        self.frames.removeAll()
        self.calculateItemFrames()
        for i in 0..<self.titlesCount {
            self.resetItemFrame(i)
            self.resetBadgeFrame(i)
        }
        guard self.progressView.superview != nil else {
            return
        }
        self.progressView.frame = self.calculateProgressViewFrame()
        self.progressView.cornerRadius = self.progressViewCornerRadius!
        self.progressView.itemFrames = self.convertProgressWidthsToFrames()
        self.progressView.setNeedsDisplay()
        
    }
    
    func convertProgressWidthsToFrames() -> [CGRect] {
        if self.frames.count == 0  {
            assert(false, "BUUUUUUUG...SHOULDN'T COME HERE!!")
        }
        if self.progressWidths.count < self.titlesCount {
            return self.frames
        }
        
        var progressFrames: [CGRect] = [CGRect]()
        let count = (self.frames.count <= self.progressWidths.count) ? self.frames.count : self.progressWidths.count
        for i in 0..<count {
            let itemFrame = self.frames[i]
            let progressWidth = self.progressWidths[i]
            let x = itemFrame.origin.x + (itemFrame.size.width - progressWidth) / 2
            let progressFrame = CGRect(x: x, y: itemFrame.origin.y, width: progressWidth, height: 0)
            progressFrames.append(progressFrame)
            
        }
        return progressFrames
    }
    
    fileprivate func calculateProgressViewFrame() -> CGRect {
        switch self.style {
        case .triangle:
            return CGRect(x: 0, y: self.frame.height - self.progressHeight - self.progressViewBottomSpace, width: self.scrollView.contentSize.width, height: self.progressHeight)
        case .line:
            return CGRect(x: 0, y: self.frame.height - self.progressHeight - self.progressViewBottomSpace, width: self.scrollView.contentSize.width, height: self.progressHeight)
            
        case .floodHollow:
            return CGRect(x:0, y:(self.frame.size.height - self.progressHeight) / 2, width:self.scrollView.contentSize.width, height:self.progressHeight)
        case .flood:
            return CGRect(x:0, y:(self.frame.size.height - self.progressHeight) / 2, width:self.scrollView.contentSize.width, height:self.progressHeight)
        case .segmented:
            return CGRect(x:0, y:(self.frame.size.height - self.progressHeight) / 2, width:self.scrollView.contentSize.width, height:self.progressHeight)
        default:
            return CGRect.zero
        }
    }
    
    /// 计算所有item的frame值，主要是为了适配所有item的宽度之和小于屏幕宽的情况
    fileprivate func calculateItemFrames() {
        var contentWidth: CGFloat = self.itemMarginAtIndex(0)
        for i in 0..<self.titlesCount {
            var itemW: CGFloat = 60.0
            itemW = (self.delegate?.menuView?(self, widthForItemAtIndex: i)) ?? 0
            let frame = CGRect(x: contentWidth, y: 0, width: itemW, height: self.frame.size.height)
            //记录frame
            self.frames.append(frame)
            contentWidth += itemW + self.itemMarginAtIndex(i + 1)
        }
        // 如果总宽度小于屏幕宽,重新计算frame,为item间添加间距
        if contentWidth < self.scrollView.frame.width {
            let distance = self.scrollView.frame.width - contentWidth
            var shiftDis: (_ index: Int) -> CGFloat
            switch self.layoutMode {
            case .scatter:
                let gap = distance / CGFloat(self.titlesCount + 1)
                shiftDis = {(index: Int) in
                    return gap * CGFloat(index + 1)
                }
            case .left:
                shiftDis = {(index: Int) in
                    return 0.0
                }
            case .right:
                shiftDis = {(index: Int) in
                    return distance
                }
            case .center:
                shiftDis = {(index: Int) in
                    return distance / 2
                }
            }
            for i in 0..<self.frames.count {
                var frame = self.frames[i]
                frame.origin.x += shiftDis(i)
                self.frames[i] = frame
            }
            contentWidth = self.scrollView.frame.width
        }
        self.scrollView.contentSize = CGSize(width: contentWidth, height: self.frame.height)
        
    }
    
    fileprivate func itemMarginAtIndex(_ index: Int) -> CGFloat {
        if let itemMargin = self.delegate?.menuView?(self, itemMarginAtIndex: index) {
            return itemMargin
        }
        return 0.0
        
    }
    
    fileprivate func resetBadgeFrame(_ index: Int) {
        let frame = self.frames[index]
        let view = self.scrollView.viewWithTag(WMBADGEVIEW_TAG_OFFSET + index)
        if let badgeView = view {
            var badgeFrame = self.badgeViewAtIndex(index: index)?.frame
            badgeFrame?.origin.x += frame.origin.x
            badgeView.frame = badgeFrame ?? CGRect.zero
        }
    }
    
    fileprivate func badgeViewAtIndex(index: Int) -> UIView? {
        guard self.dataSource != nil else {
            return nil
        }
        
        let badgeView = self.dataSource.menuView!(self, badgeViewAtIndex: index) ?? nil
        guard badgeView != nil else {
            return nil
        }
        badgeView?.tag = index + WMBADGEVIEW_TAG_OFFSET
        return badgeView
    }
    
    fileprivate func resetItemFrame(_ index: Int) {
        let item = self.viewWithTag(WMMENUITEM_TAG_OFFSET + index)
        if item is  MenuItem {
            let menuItem = item as! MenuItem
            let frame = self.frames[index]
            menuItem.frame = frame
            self.delegate?.menuView?(self, didLayoutItemFrame: menuItem, atIndex: index)
        }
    }
    
    fileprivate func sizeForState(_ state: MenuItemState, atIndex index: Int) -> CGFloat {
        
        if let size = self.delegate?.menuView?(self, titleSizeForState: state, atIndex: index) {
            return size
        }
        return 15.0
    }
    
    func addItems() {
        self.calculateItemFrames()
        for i in 0..<self.titlesCount {
            let frame = self.frames[i]
            let item = MenuItem(frame: frame)
            item.tag = i + WMMENUITEM_TAG_OFFSET
            item.delegate = self
            item.text = self.dataSource.menuView(self, titleAtIndex: i)
            item.textAlignment = .center
            item.isUserInteractionEnabled = true
            item.backgroundColor = UIColor.clear
            item.normalSize = self.sizeForState(.normal, atIndex: i)
            item.selectedSize = self.sizeForState(.selected, atIndex: i)
            item.normalColor = self.colorForState(state: .normal, atIndex: i)
            item.selectedColor = self.colorForState(state: .selected, atIndex: i)
            item.speedFactor = self.speedFactor
            if let fontNameValue = self.fontName {
                item.font = UIFont(name: fontNameValue, size: item.selectedSize)
            } else {
                item.font = UIFont.systemFont(ofSize: item.selectedSize)
            }
            
            if let newItem = self.dataSource.menuView?(self, initialMenuItem: item, atIndex: i) {
                if i == 0 {
                    newItem.setSelected(true, animation: false)
                } else {
                    newItem.setSelected(false, animation: false)
                }
                self.scrollView.addSubview(newItem)
            }
            
        }
    }
    
    fileprivate func makeStyle(){
        let frame = self.calculateProgressViewFrame()
        guard frame != CGRect.zero else {
            return
        }
        self.addProgressViewWithFrame(frame, self.style == .triangle, self.style == .segmented, self.style == .floodHollow, self.progressViewCornerRadius ?? 0)
        
    }
    
    fileprivate func addBadgeViews() {
        for i in 0..<titlesCount {
            self.addBadgeViewAtIndex(i)
        }
    }
    
    fileprivate func addBadgeViewAtIndex(_ index: Int) {
        let badgeView = self.badgeViewAtIndex(index: index)
        if let bView = badgeView {
        self.scrollView.addSubview(bView)
        }
        
    }
    
    //MARK: - Progress View
    fileprivate func addProgressViewWithFrame(_ frame: CGRect, _ isTriangle: Bool = false, _ hasBorder: Bool = false, _ isHollow: Bool = false, _ cornerRadius: CGFloat = 0.0) {
        let pView = ProgressView(frame: frame)
        pView.itemFrames = self.convertProgressWidthsToFrames()
        pView.color = self.lineColor?.cgColor
        pView.isTriangle = isTriangle
        pView.hasBorder = hasBorder
        pView.hollow = isHollow
        pView.cornerRadius = cornerRadius
        pView.naughty = self.progressViewIsNaughty
        pView.speedFactor = self.speedFactor
        pView.backgroundColor = UIColor.clear
        self.progressView = pView
        self.scrollView.insertSubview(self.progressView, at: 0)
        
    }
    
    
    //MARK: - MenuItemDelegate
    public func didPressedMenuItem(_ menuItem: MenuItem) {
        if let should = self.delegate?.menuView?(self, shouldSelesctedIndex: menuItem.tag - WMMENUITEM_TAG_OFFSET) {
            guard should else {
                return
            }
        }
        let progress = menuItem.tag - WMMENUITEM_TAG_OFFSET
        self.progressView.moveToPostion(progress)
        let currentIndex = self.selItem.tag - WMMENUITEM_TAG_OFFSET
        self.delegate?.menuView?(self, didSelectedIndex: menuItem.tag - WMMENUITEM_TAG_OFFSET, currentIndex)
        self.selItem.setSelected(false, animation: true)
        self.selItem.setSelected(true, animation: true)
        let delay: TimeInterval = (self.style == .default) ? 0: 0.3
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + delay) {
            self.refreshContenOffset()
        }
        
        
        
        
    }
    
    open override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        guard self.scrollView != nil else {
            return
        }
        self.addScrollView()
        self.addItems()
        self.makeStyle()
        self.addBadgeViews()
        self.resetSelectionIfNeeded()
        
    }
    
   fileprivate func addScrollView() {
    let width = self.frame.width - (self.contentMargin ) * 2
        let height = self.frame.height
    let frameS = CGRect(x: self.contentMargin , y: 0, width: width, height: height)
        let scrollView = UIScrollView(frame: frameS)
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = UIColor.clear
        scrollView.scrollsToTop = false
        self.addSubview(scrollView)
        self.scrollView = scrollView
    }
    
    fileprivate func resetSelectionIfNeeded() {
        guard self.selectIndex > 0 else {
            return
        }
        self.selectItemAtIndex(self.selectIndex)
    }
    
    
    
    
    
    
    
    
    /*
     // Only override draw() if you perform custom drawing.
     // An empty implementation adversely affects performance during animation.
     override func draw(_ rect: CGRect) {
     // Drawing code
     }
     */
    
}