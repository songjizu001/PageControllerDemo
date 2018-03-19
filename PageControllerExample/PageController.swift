//
//  PageControllerViewController.swift
//  PageControllerExample
//
//  Created by 郑小燕 on 2018/3/9.
//  Copyright © 2018年 郑小燕. All rights reserved.
//

import UIKit
public enum CachePolicy: Int {
    case noLimit    = 0
    case lowMemory  = 1
    case balanced   = 3
    case high       = 5
}

public enum PreloadPolicy: Int {
    case never      = 0
    case neighbour  = 1
    case near       = 2
}

public let WMPageControllerDidMovedToSuperViewNotification = "WMPageControllerDidMovedToSuperViewNotification"
public let WMPageControllerDidFullyDisplayedNotification = "WMPageControllerDidFullyDisplayedNotification"

@objc public protocol PageControllerDataSource: NSObjectProtocol {
    @objc optional func numbersOfChildControllersInPageController(_ pageController:PageController) -> Int
    @objc optional func pageController(_ pageController: PageController, viewControllerAtIndex index: Int) -> UIViewController
    @objc optional func pageController(_ pageController: PageController, titleAtIndex index: Int) -> String
    func pageController(pageController: PageController, preferredFrameForContentView scrollView: WMScrollView?) -> CGRect
    func pageController(pageController: PageController, preferredFrameForMenuView menuView: MenuView?) -> CGRect
    
}

@objc public protocol PageControllerDelegate: NSObjectProtocol {
    @objc optional func pageController(_ pageController: PageController, lazyLoadViewController viewController: UIViewController, withInfo info: Dictionary<String, String>)
    @objc optional func pageController(_ pageController: PageController, willCachedViewController viewController: UIViewController, withInfo info: Dictionary<String, String>)
    @objc optional func pageController(_ pageController: PageController, willEnterViewController viewController: UIViewController, withInfo info: Dictionary<String, String>)
    @objc optional func pageController(_ pageController: PageController, didEnterViewController viewController: UIViewController, withInfo info: Dictionary<String, String>)
}

open class PageController: UIViewController {
    // MARK: - Public vars
    open weak var dataSource: PageControllerDataSource?
    open weak var delegate: PageControllerDelegate?
    open var values: NSArray?
    open var keys: [String]?
    
    /// 各个控制器的 class
    open var viewControllerClasses: [UIViewController.Type]?
    
    ///  各个控制器标题
    open var titles: [String]?
    open fileprivate(set) var currentViewController: UIViewController?
    
    /// 设置选中几号 item
    open var selectIndex: Int = 0 {
        didSet {
            if self.menuView != nil && hasInited {
                self.menuView?.selectItemAtIndex(selectIndex)
            } else {
                markedSelectIndex = selectIndex
                var vc: UIViewController!
                vc = self.memCache.object(forKey: NSNumber(integerLiteral: selectIndex))
                if vc == nil {
                    vc = self.initializeViewControllerAtIndex(selectIndex)
                    self.memCache.setObject(vc, forKey: NSNumber(integerLiteral: selectIndex))
                    
                }
                self.currentViewController = vc
            }
        }
    }
    /// 点击的 MenuItem 是否触发滚动动画
    open var pageAnimatable: Bool = false
    
    /// 是否自动通过字符串计算 MenuItem 的宽度，默认为 NO
    open var automaticallyCalculatesItemWidths: Bool = false
    
    /// Whether the controller can scroll. Default is YES
    open var scrollEnable: Bool = true {
        didSet {
            guard scrollView != nil else {
                return
            }
            self.scrollView.isScrollEnabled = scrollEnable
        }
    }
    
    /// 选中时的标题尺寸
    open var titleSizeSelected: CGFloat = 18.0
    /// 非选中时的标题尺寸
    open var titleSizeNormal: CGFloat = 15.0
    ///标题选中时的颜色, 颜色是可动画的.
    open lazy var titleColorSelected = UIColor(red: 168.0/255.0, green: 20.0/255.0, blue: 4/255.0, alpha: 1.0)
    ///标题非选择时的颜色, 颜色是可动画的.
    open lazy var titleColorNormal = UIColor.black
    ///标题的字体名字
    open var titleFontName: String?
    ///每个 MenuItem 的宽度
    open var menuItemWidth: CGFloat      = 65.0
    ///各个 MenuItem 的宽度，可不等，数组内为
    open var itemsWidths: [CGFloat]?
    //Menu view 的样式，默认为无下划线
    open var menuViewStyle = MenuViewStyle.default
    open var menuViewLayoutMode = MenuViewLayoutMode.center {
        didSet {
            guard self.menuView?.superview != nil else {
                return
            }
            self.resetMenuView()
        }
    }
    //进度条的颜色，默认和选中颜色一致(如果 style 为 Default，则该属性无用)
    open var progressColor: UIColor?
    //定制进度条在各个 item 下的宽度
    var progressViewWidths: [CGFloat]? {
        didSet {
            guard self.menuView != nil else {
                return
            }
            self.menuView?.progressWidths = progressViewWidths!
        }
    }
    /// 定制进度条，若每个进度条长度相同，可设置该属性
    var progressWidth: CGFloat? {
        didSet {
            self.progressViewWidths = {
                var tmp: [CGFloat] = [CGFloat]()
                for _ in 0..<self.childControllersCount {
                    tmp.append(progressWidth!)
                }
                return tmp
            }()
            
            
        }
    }
    ///内部容器
    open var scrollView: WMScrollView!
    /// 调皮效果
    var progressViewIsNaughty = true {
        didSet {
            guard self.menuView != nil else {
                return
            }
            self.menuView?.progressViewIsNaughty = progressViewIsNaughty
        }
    }
    ///是否发送在创建控制器或者视图完全展现在用户眼前时通知观察者，默认为不开启，如需利用通知请开启
    open var postNotification = false
    ///是否记录 Controller 的位置，并在下次回来的时候回到相应位置，默认为 NO (若当前缓存中存在不会触发
    var rememberLocation: Bool = false
    ///缓存的机制，默认为无限制 (如果收到内存警告, 会自动切换)
    lazy fileprivate var memCache = NSCache<NSNumber, UIViewController>()
    open var cachePolicy: CachePolicy = .noLimit {
        didSet {
            memCache.countLimit = cachePolicy.rawValue
        }
    }
    ///预加载机制，在停止滑动的时候预加载 n 页
    open var preloadPolicy: PreloadPolicy = .never
    ///Whether ContentView bounces
    open var bounces = false
    /// 是否作为 NavigationBar 的 titleView 展示，默认 NO
    open var showOnNavigationBar = false {
        didSet {
            guard showOnNavigationBar != oldValue else {
                return
            }
            if let _ = self.menuView {
                self.menuView?.removeFromSuperview()
                self.addMenuView()
                self.forceLayoutSubviews()
                self.menuView?.slideMenuAtProgress(CGFloat(self.selectIndex))
            }
        }
    }
    ///用代码设置 contentView 的 contentOffset 之前，请设置 startDragging = YES
    open var startDragging = false
    ///下划线进度条的高度
    open var progressHeight: CGFloat = -1
    ///顶部菜单栏各个 item 的间隙，因为包括头尾两端，所以确保它的数量等于控制器数量 + 1, 默认间隙为 0
    open var itemsMargins: [CGFloat]?
    ///set itemMargin if all margins are the same, default is 0 如果各个间隙都想同，设置该属性，默认为 0
    open var itemMargin: CGFloat = 0.0
    ///progressView 到 menuView 底部的距离
    open var progressViewBottomSpace: CGFloat = 0
    ///progressView's cornerRadius
    open var progressViewCornerRadius: CGFloat = -1 {
        didSet {
            guard self.menuView != nil else {
                return
            }
            self.menuView?.progressViewCornerRadius = progressViewCornerRadius
        }
    }
    ///顶部导航栏
    open weak var menuView: MenuView?
    ///内部容器
    open weak var contentView: WMScrollView?
    ///MenuView 内部视图与左右的间距
    open var menuViewContentMargin: CGFloat = 0.0 {
        didSet {
            guard let menu = menuView else { return }
            menu.contentMargin = menuViewContentMargin
        }
    }
    
    fileprivate var targetX: CGFloat = 0.0
    fileprivate var contentViewFrame: CGRect = CGRect.zero
    fileprivate var menuViewFrame: CGRect = CGRect.zero
    fileprivate var hasInited: Bool = false
    fileprivate var shouldNotScroll: Bool = false
    fileprivate var initializedIndex: Int = -1
    fileprivate var controllerCount: Int = -1
    fileprivate var markedSelectIndex: Int = -1
    /// 用于记录子控制器view的frame，用于 scrollView 上的展示的位置
    lazy fileprivate var childViewFrames = [CGRect]()
    /// 当前展示在屏幕上的控制器，方便在滚动的时候读取 (避免不必要计算)
    lazy fileprivate var displayVC: [String: UIViewController] = [:]
    ///用于记录销毁的viewController的位置 (如果它是某一种scrollView的Controller的话)
    lazy fileprivate var posRecords = [String: CGPoint]()
    lazy var backgroundCache = NSMutableDictionary()
    ///收到内存警告的次数
    fileprivate var memoryWarningCount = 0
    var childControllersCount: Int {
    if controllerCount == -1 {
        if let count = self.dataSource?.numbersOfChildControllersInPageController?(self) {
            controllerCount = count
        } else {
            controllerCount = viewControllerClasses?.count ?? 0
        }
    }
        return controllerCount
    }
   
    
    
    
    
    ///构造方法，请使用该方法创建控制器. 或者实现数据源方法
    public convenience init(vcClasses: [UIViewController.Type], theirTitles: [String]) {
        self.init()
        assert(vcClasses.count == theirTitles.count, "`vcClasses.count` must equal to `titles.count`")
        titles = theirTitles
        viewControllerClasses = vcClasses
    }
    
    open func reloadData() {
        self.clearDatas()
        guard self.childControllersCount != 0 else {
            return
        }
        
        
    }
    
    //    open override func overrideTraitCollection(forChildViewController childViewController: UIViewController) -> UITraitCollection? {
    //
    //    }
    
    
    
    /// 更新指定序号的控制器的标题
    ///
    /// - Parameters:
    ///   - title: 新的标题
    ///   - index: 目标序号
    open func updateTitle(_ title: String, atIndex index: Int) {
        
    }
    
    ///  更新指定序号的控制器的标题以及他的宽度
    ///
    /// - Parameters:
    ///   - title: 新的标题
    ///   - index: 目标序号
    ///   - width: 对应item的新宽度
    open func updateTitle(_ title: String, atIndex index: Int, andWidth width: CGFloat) {
    }
    
    open func updateAttributeTitle(_ title: String, atIndex index: Int) {
        
    }
    ///当 app 即将进入后台接收到的通知
    @objc open func willResignActive(_ notification: Notification) {
        
    }
    ///当 app 即将回到前台接收到的通知
    @objc open func willEnterForeground(_ notification: Notification){
        
    }
    
    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        self.initSetup()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.white
        guard self.childControllersCount != 0 else {
            return
        }
        self.calculateSize()
        self.addScrollView()
        self.addMenuView()
        self.initializedControllerWithIndexIfNeeded(self.selectIndex)
        self.currentViewController = self.displayVC["\(self.selectIndex)"]
        self.didEnterController(self.currentViewController!, self.selectIndex)
        
    }
    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard self.childControllersCount != 0 else {
            return
        }
        self.forceLayoutSubviews()
        hasInited = true
        self.delaySelectIndexIfNeeded()
    }
    
    fileprivate func didEnterController(_ vc: UIViewController, _ index: Int) {
        guard self.childControllersCount != 0 else {
            return
        }
    self.postFullyDisplayedNotificationWithCurrentIndex(self.selectIndex)
        let info = self.infoWithIndex(index)
        self.delegate?.pageController?(self, didEnterViewController: vc, withInfo: info)
        if initializedIndex == index {
            self.delegate?.pageController?(self, lazyLoadViewController: vc, withInfo: info )
            initializedIndex = -1
        }
        guard self.preloadPolicy != .never else {
            return
        }
        let length = self.preloadPolicy.rawValue
        var start: Int = 0
        var end: Int = self.childControllersCount - 1
        if index > length {
            start = index - length
        }
        if self.childControllersCount - 1 > length + index {
            end = index + length
        }
        
        for i in start...end {
            if  self.memCache.object(forKey: NSNumber(integerLiteral: i)) == nil && self.displayVC["\(index)"] == nil {
                self.addViewControllerAtIndex(i)
                self.postAddToSuperViewNotificationWithIndex(i)
            }
        }
        selectIndex = index
    }
    
    //当控制器完全展示在user面前时发送通知
    fileprivate func postFullyDisplayedNotificationWithCurrentIndex(_ index: Int) {
        guard  self.postNotification else { return  }
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: WMPageControllerDidFullyDisplayedNotification), object: self, userInfo: ["index": index, "title": self.titleAtIndex(index)])
        
    }
    
    // 创建或从缓存中获取控制器并添加到视图上
    fileprivate func initializedControllerWithIndexIfNeeded(_ index: Int) {
        //先从中cache中取
        let vc = self.memCache.object(forKey: NSNumber(integerLiteral: index))
        if let _ = vc {
            self.addCachedViewController(vc!, index)
        } else {
            self.addViewControllerAtIndex(index)
        }

        self.postAddToSuperViewNotificationWithIndex(index)
        
    }
    
    fileprivate func addCachedViewController(_ viewController: UIViewController, _ index: Int) {
        self.addChildViewController(viewController)
        viewController.view.frame = self.childViewFrames[index]
        viewController.didMove(toParentViewController: self)
        self.scrollView.addSubview(viewController.view)
        self.willEnterController(viewController, index)
        self.displayVC["\(index)"] = viewController
        
    }
    
    fileprivate func postAddToSuperViewNotificationWithIndex(_ index: Int) {
        guard  self.postNotification else { return  }
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: WMPageControllerDidMovedToSuperViewNotification), object: self, userInfo: ["index": index, "title": self.titleAtIndex(index)])
        
    }
    
    func initSetup() {
       
       self.delegate = self
        self.dataSource = self
        NotificationCenter.default.addObserver(self, selector: #selector(willResignActive(_:)), name: Notification.Name.UIApplicationWillResignActive, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground(_:)), name: Notification.Name.UIApplicationWillEnterForeground, object: nil)
        
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func forceLayoutSubviews() {
        guard self.childControllersCount != 0 else {
            return
        }
        self.calculateSize()
        self.adjustScrollViewFrame()
        self.adjustMenuViewFrame()
    self.adjustDisplayingViewControllersFrame()
        
    }
    
    //MARK: - private method
    /// 包括宽高，子控制器视图 frame
    fileprivate func calculateSize() {
        if let mFrame = self.dataSource?.pageController(pageController: self, preferredFrameForMenuView: self.menuView ?? nil) {
            self.menuViewFrame = mFrame
            if let cFrame = dataSource?.pageController(pageController: self, preferredFrameForContentView: self.scrollView) {
                self.contentViewFrame = cFrame
                for i in 0..<self.childControllersCount {
                    let frame = CGRect(x: CGFloat(i) * contentViewFrame.size.width, y: 0, width: contentViewFrame.size.width, height: contentViewFrame.size.height)
                    childViewFrames.append(frame)
                }
                
            }
        }
    }
    
    fileprivate func adjustScrollViewFrame() {
        shouldNotScroll = true
        let oldContentOffsetX = self.scrollView.contentOffset.x
        let contentWidth = self.scrollView.contentSize.width
        self.scrollView.frame = contentViewFrame
        self.scrollView.contentSize = CGSize(width: CGFloat(self.childControllersCount) * contentViewFrame.width, height: 0)
        let xContentOffset = (contentWidth == 0) ? CGFloat(self.selectIndex) * contentViewFrame.size.width : oldContentOffsetX / contentWidth * CGFloat(childControllersCount) * contentViewFrame.size.width
        self.scrollView.setContentOffset(CGPoint(x: xContentOffset, y: 0), animated: false)
        shouldNotScroll = false
        
    }
    
    fileprivate func adjustMenuViewFrame() {
        let oriWidth = self.menuView?.frame.width
        menuView?.frame = menuViewFrame
        self.menuView?.resetFrames()
        if oriWidth != menuView?.frame.width {
            self.menuView?.refreshContenOffset()
        }
    }
    
    func adjustDisplayingViewControllersFrame() {
        for (index, key) in self.displayVC.keys.enumerated() {
            let vcFrame = self.childViewFrames[index]
            let vc = displayVC[key]!
            vc.view.frame = vcFrame
        }
    }
    
    func resetMenuView() {
        if let _ = self.menuView {
            self.menuView?.reload()
            if !(self.menuView?.isUserInteractionEnabled)! {
                self.menuView?.isUserInteractionEnabled = true
            }
            if self.selectIndex != 0 {
                self.menuView?.selectItemAtIndex(self.selectIndex)
            }
            self.view.bringSubview(toFront: self.menuView!)
        } else {
            self.addMenuView()
        }
    }
    
    func addMenuView() {
        let menuView = MenuView(frame: CGRect.zero)
        menuView.delegate = self
        menuView.dataSource = self
        menuView.style = self.menuViewStyle
        menuView.layoutMode = self.menuViewLayoutMode
        menuView.progressHeight = self.progressHeight
        menuView.contentMargin = menuViewContentMargin
        menuView.progressViewBottomSpace = self.progressViewBottomSpace
        menuView.progressWidths = self.progressViewWidths ?? [0]
        menuView.progressViewIsNaughty = self.progressViewIsNaughty
        menuView.progressViewCornerRadius = self.progressViewCornerRadius
        menuView.showOnNavigationBar = self.showOnNavigationBar
        if let fontName = self.titleFontName {
            menuView.fontName = fontName
        }
        
        if let pColor = progressColor {
            self.menuView?.lineColor = pColor
        }
        if self.showOnNavigationBar && self.navigationController?.navigationBar != nil {
            self.navigationItem.titleView = menuView
        } else {
            self.view.addSubview(menuView)
        }
        self.menuView = menuView
    }
    
    func initializeViewControllerAtIndex(_ index: Int) -> UIViewController {
        if let vc: UIViewController = self.dataSource?.pageController?(self, viewControllerAtIndex: index) {
            return vc
        } else {
            return self.viewControllerClasses![index].init()
        }
    }
    
    fileprivate func clearDatas() {
        controllerCount = -1
        hasInited = false
        let maxIndex = (self.childControllersCount - 1 > 0) ? (childControllersCount - 1) : 0
        selectIndex = self.selectIndex < self.childControllersCount ? self.selectIndex : maxIndex
        for vc in self.displayVC.values {
            vc.view.removeFromSuperview()
            vc.willMove(toParentViewController: nil)
            vc.removeFromParentViewController()
        }
        self.memoryWarningCount = 0
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(growCachePolicyAfterMemoryWarning), object: nil)
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(growCachePolicyToHigh), object: nil)
        self.currentViewController = nil
        self.posRecords.removeAll()
        self.displayVC.removeAll()
        
        
    }
    
    @objc fileprivate func growCachePolicyAfterMemoryWarning() {
        self.cachePolicy = .balanced
        self.perform(#selector(growCachePolicyToHigh), with: nil, afterDelay: 2.0, inModes: [RunLoopMode.commonModes])
    }
    
    @objc func growCachePolicyToHigh() {
        self.cachePolicy = .high
    }
    
    func resetScrollView() {
        if scrollView != nil {
            scrollView.removeFromSuperview()
        }
        self.addScrollView()
        self.addViewControllerAtIndex(self.selectIndex)
        self.currentViewController = self.displayVC["\(self.selectIndex)"]
        
    }
    
    fileprivate func addScrollView() {
        let scrollView = WMScrollView()
        scrollView.scrollsToTop = false
        scrollView.isPagingEnabled = true
        scrollView.backgroundColor = UIColor.white
        scrollView.delegate = self
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bounces = bounces
        scrollView.isScrollEnabled = scrollEnable
        self.view.addSubview(scrollView
        )
        self.scrollView = scrollView
        for gesture in scrollView.gestureRecognizers! {
            gesture.require(toFail: (self.navigationController?.interactivePopGestureRecognizer)!)
        }
        
    }
    
    fileprivate func addViewControllerAtIndex(_ index: Int) {
        initializedIndex = index
        let viewController = self.initializeViewControllerAtIndex(index)
        if self.values?.count == self.childControllersCount && self.keys?.count == self.childControllersCount {
            viewController.setValue(self.values?[index], forKey: self.keys![index])
        }
        self.addChildViewController(viewController)
        let frame = self.childViewFrames.count == 0 ? self.childViewFrames[index] : self.view.frame
        viewController.view.frame = frame
        viewController.didMove(toParentViewController: self)
        self.scrollView.addSubview(viewController.view)
        self.willEnterController(viewController, index)
        self.displayVC["\(index)"] = viewController
        self.backToPositionIfNeeded(controller: viewController, index: index)
        
        
        
    }
    
    ///移除控制器,且从display中移除
    func removeViewController(_ viewController: UIViewController, _ index: Int) {
        self.rememberPositionIfNeeded(viewController, index: index)
        viewController.view.removeFromSuperview()
        viewController.willMove(toParentViewController: nil)
        viewController.removeFromParentViewController()
        self.displayVC["\(index)"] = nil
        //放入缓存
        if let _ = self.memCache.object(forKey: NSNumber(integerLiteral: index)) {
        } else {
            self.willCachedController(viewController, index)
            self.memCache.setObject(viewController, forKey: NSNumber(integerLiteral: index))
            
        }
    }
    
    func willEnterController(_ vc: UIViewController, _ index: Int) {
        self.selectIndex = index
        if self.childControllersCount != 0 {
            let info = self.infoWithIndex(index)
            self.delegate?.pageController?(self, didEnterViewController: vc, withInfo: info)
        }
    }
    
    func infoWithIndex(_ index: Int) -> Dictionary<String, String> {
        let title = self.titleAtIndex(index)
        return ["title": title, "index": "\(index)"]
    }
    
    fileprivate func titleAtIndex(_ index: Int) -> String {
        var title = ""
        if let tit = self.dataSource?.pageController?(self, titleAtIndex: index) {
            title = tit
        } else {
            title = self.titles?[index] ?? ""
        }
        return title
    }
    
    fileprivate func backToPositionIfNeeded(controller: UIViewController, index: Int) {
        guard self.rememberLocation == false else {
            return
        }
        
        guard let _ = self.memCache.object(forKey: NSNumber(integerLiteral: index)) else { return  }
        let scroll = self.isKindOfScrollViewController(controller)
        guard let _ = scroll else { return
        }
        
        if let point = posRecords["\(index)"] {
            scroll?.setContentOffset(point, animated: true)
        }
    }
    
    func isKindOfScrollViewController(_ controller: UIViewController) -> WMScrollView? {
        var scroll: WMScrollView?
        
        if controller.view is WMScrollView {
            scroll = controller.view as? WMScrollView
        } else if controller.view.subviews.count >= 1 {
            let view = controller.view.subviews[0]
            if view is WMScrollView {
                scroll = view as? WMScrollView
            }
        }
        return scroll
    }
    
    fileprivate func rememberPositionIfNeeded(_ controller: UIViewController, index: Int) {
        guard self.rememberLocation else {
            return
        }
        if let scrollView = isKindOfScrollViewController(controller) {
            let pos = scrollView.contentOffset
            self.posRecords["\(index)"] = pos
            
        }
    }
    
    fileprivate func willCachedController(_ vc: UIViewController, _ index: Int) {
        let info = self.infoWithIndex(index)
        self.delegate?.pageController?(self, willCachedViewController: vc, withInfo: info)
        
    }
    fileprivate func isInScreen(_ frame: CGRect) -> Bool{
        let x = frame.origin.x
        let screenWidth = self.scrollView.frame.width
        let contentOffsetX = self.scrollView.contentOffset.x
        if frame.maxX > contentOffsetX && x - contentOffsetX < screenWidth {
            return true
        } else {
            return false
        }
    }
    
    fileprivate func calculateItemWithAtIndex(_ index: Int) -> CGFloat {
        let title = self.titleAtIndex(index)
        let titleFont = self.titleFontName != nil ? UIFont(name: self.titleFontName!, size: self.titleSizeSelected) : UIFont.systemFont(ofSize: self.titleSizeSelected)
        
        let itemWidth = NSString(string: title).boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [NSAttributedStringKey.font : titleFont ?? ""], context: nil).size.width
        
        return CGFloat(ceil(itemWidth))
    }
    
    func delaySelectIndexIfNeeded() {
        if self.markedSelectIndex != -1 {
            self.selectIndex = self.markedSelectIndex
        }
    }
    
    
    
    
    
    
    override open func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        self.memoryWarningCount += 1
        self.cachePolicy = .lowMemory
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(growCachePolicyAfterMemoryWarning), object: nil)
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(growCachePolicyToHigh), object: nil)
        self.memCache.removeAllObjects()
        self.posRecords.removeAll()
       // 如果收到内存警告次数小于 3，一段时间后切换到模式 Balanced
        if self.memoryWarningCount < 3 {
            self.perform(#selector(growCachePolicyAfterMemoryWarning), with: nil, afterDelay: 3.0, inModes:[RunLoopMode.commonModes])
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
    
}

extension PageController: MenuViewDataSource, MenuViewDelegate {
    func menuView(_ menu: MenuView, didSelectedIndex index: Int, _ currentIndex: Int) {
        guard hasInited else {
            return
        }
        selectIndex = index
        let targetP = CGPoint(x: contentViewFrame.width * CGFloat(index), y: 0)
        self.scrollView.setContentOffset(targetP, animated: self.pageAnimatable)
        guard !self.pageAnimatable else {
            return
        }
         // 由于不触发 -scrollViewDidScroll: 手动处理控制器
        let currentVC = self.displayVC["\(currentIndex)"]
        if let _ = currentVC {
            self.removeViewController(currentVC!, currentIndex)
        }
        self.layoutChildViewControllers()
        self.currentViewController = self.displayVC["\(selectIndex)"]
        self.didEnterController(currentViewController!, index)
        
    }
    
    func menuView(_ menu: MenuView, widthForItemAtIndex index: Int) -> CGFloat {
        if automaticallyCalculatesItemWidths {
            return self.calculateItemWithAtIndex(index)
        }
        if self.itemsWidths?.count == self.childControllersCount {
            return self.itemsWidths![index]
        }
        return self.menuItemWidth
    }
    
    func menuView(_ menu: MenuView, itemMarginAtIndex index: Int) -> CGFloat {
        if self.itemsMargins?.count == self.childControllersCount + 1 {
            return self.itemsMargins![index]
        }
        return self.itemMargin
    }
    
    func menuView(_ menu: MenuView, titleSizeForState state: MenuItemState, atIndex index: Int) -> CGFloat {
        switch state {
        case .normal:
            return self.titleSizeNormal
        default:
            return self.titleSizeSelected
        }
    }
    
    func menuView(_ menu: MenuView, titleColorForState state: MenuItemState, atIndex index: Int) -> UIColor {
        switch state {
        case .selected:
            return titleColorSelected
        default:
            return titleColorNormal
        }
    }
    
    //data Source
    func numbersOfTitlesInMenuView(_ menuView: MenuView) -> Int {
        return childControllersCount
    }
    func menuView(_ menuView: MenuView, titleAtIndex index: Int) -> String {
        return self.titleAtIndex(index)
    }
    
    
}

//MARK: - PageControllerDelegate dataSource
extension PageController: PageControllerDelegate, PageControllerDataSource {
    public func pageController(pageController: PageController, preferredFrameForContentView scrollView: WMScrollView?) -> CGRect {
        return CGRect.zero
    }
    
    public func pageController(pageController: PageController, preferredFrameForMenuView menuView: MenuView?) -> CGRect {
       return CGRect.zero
    }
    
    
    
}

extension PageController: UIScrollViewDelegate {
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView is WMScrollView else {
           return
        }
        guard shouldNotScroll
         || !hasInited  else {
            return
        }
        self.layoutChildViewControllers()
        if (startDragging) {
            var contentOffsetX = scrollView.contentOffset.x
            if contentOffsetX < 0 {
                contentOffsetX = 0
            }
            if (contentOffsetX > scrollView.contentSize.width - contentViewFrame.size.width) {
                contentOffsetX = scrollView.contentSize.width - contentViewFrame.size.width
            }
            let rate = contentOffsetX / contentViewFrame.size.width
            self.menuView?.slideMenuAtProgress(rate)
        }
        // Fix scrollView.contentOffset.y -> (-20) unexpectedly.
        guard scrollView.contentOffset.y != 0 else {
            return
        }
        var contentOffset = scrollView.contentOffset
        contentOffset.y = 0.0
        scrollView.contentOffset = contentOffset
        
    }
    
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard scrollView is WMScrollView  else {
            return
        }
        startDragging = true
        menuView?.isUserInteractionEnabled = false
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView is WMScrollView else {
            return
        }
        menuView?.isUserInteractionEnabled = true
        self.selectIndex = Int(scrollView.contentOffset.x / contentViewFrame.size.width)
        self.currentViewController = self.displayVC["\(selectIndex)"]
        guard let _ = self.currentViewController else { return  }

        self.didEnterController(self.currentViewController!, self.selectIndex)
        self.menuView?.deselectedItemsIfNeeded()
    }
    
    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
       
        self.currentViewController = self.displayVC["\(selectIndex)"]
        self.didEnterController(self.currentViewController!, self.selectIndex)
        self.menuView?.deselectedItemsIfNeeded()
        
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard scrollView is WMScrollView else {
            return
        }
        if !decelerate {
            self.menuView?.isUserInteractionEnabled = true
            let rate = targetX / contentViewFrame.width
            self.menuView?.slideMenuAtProgress(rate)
            self.menuView?.deselectedItemsIfNeeded()
            
        }
    }
    
    public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        guard scrollView is WMScrollView else {
            return
        }
        targetX = targetContentOffset.pointee.x
    }
    
    
    
    func layoutChildViewControllers() {
        let currentPage = self.scrollView.contentOffset.x / contentViewFrame.size.width
        let length = self.preloadPolicy.rawValue
        let left = currentPage - CGFloat(length) - 1
        let right = currentPage + CGFloat(length) + 1
        for i in 0..<childControllersCount {
            let vc = self.displayVC["\(i)"]
            let frame = self.childViewFrames[i]
            if vc == nil {
                if self.isInScreen(frame) {
                    self.initializedControllerWithIndexIfNeeded(i)
                }
            } else if (CGFloat(i) <= left || CGFloat(i) >= right) {
                if !self.isInScreen(frame) {
                    self.removeViewController(vc!, i)
                }
            }
            
            
        }
    }
}

open class WMScrollView: UIScrollView, UIGestureRecognizerDelegate {
    
    open func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        
        guard let wrapperView = NSClassFromString("UITableViewWrapperView"), let otherGestureView = otherGestureRecognizer.view else { return false }
        
        if otherGestureView.isKind(of: wrapperView) && (otherGestureRecognizer is UIPanGestureRecognizer) {
            return true
        }
        return false
    }
    
}
