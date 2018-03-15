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
    func pageController(pageController: PageController, preferredFrameForContentView scrollView: WMScrollView) -> CGRect
    func pageController(pageController: PageController, preferredFrameForMenuView menuView: MenuView) -> CGRect
    
}

@objc public protocol PageControllerDelegate: NSObjectProtocol {
    @objc optional func pageController(_ pageController: PageController, lazyLoadViewController viewController: UIViewController, withInfo info: NSDictionary)
    @objc optional func pageController(_ pageController: PageController, willCachedViewController viewController: UIViewController, withInfo info: NSDictionary)
    @objc optional func pageController(_ pageController: PageController, willEnterViewController viewController: UIViewController, withInfo info: NSDictionary)
    @objc optional func pageController(_ pageController: PageController, didEnterViewController viewController: UIViewController, withInfo info: NSDictionary)
}

open class PageController: UIViewController, UIScrollViewDelegate, MenuViewDelegate, PageControllerDelegate, PageControllerDataSource {
    func numbersOfTitlesInMenuView(_ menuView: MenuView) -> Int {
     return 0
    }
    
    public func pageController(pageController: PageController, preferredFrameForContentView scrollView: WMScrollView) -> CGRect {
        return CGRect.zero
    }
    
    public func pageController(pageController: PageController, preferredFrameForMenuView menuView: MenuView) -> CGRect {
        return CGRect.zero
    }
    
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
    open var selectIndex: Int = 0
    /// 点击的 MenuItem 是否触发滚动动画
    open var pageAnimatable: Bool = false
    
    /// 是否自动通过字符串计算 MenuItem 的宽度，默认为 NO
    open var automaticallyCalculatesItemWidths: Bool = false
    
    /// Whether the controller can scroll. Default is YES
    open var scrollEnable: Bool = true
    
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
    open var menuViewLayoutMode = MenuViewLayoutMode.center
    //进度条的颜色，默认和选中颜色一致(如果 style 为 Default，则该属性无用)
    open var progressColor: UIColor?
    //定制进度条在各个 item 下的宽度
    var progressViewWidths: [CGFloat]?
    /// 定制进度条，若每个进度条长度相同，可设置该属性
    var progressWidth: CGFloat?
    /// 调皮效果
    var progressViewIsNaughty = true
    ///是否发送在创建控制器或者视图完全展现在用户眼前时通知观察者，默认为不开启，如需利用通知请开启
    open var postNotification = false
    ///是否记录 Controller 的位置，并在下次回来的时候回到相应位置，默认为 NO (若当前缓存中存在不会触发
    var rememberLocation: Bool = false
    ///缓存的机制，默认为无限制 (如果收到内存警告, 会自动切换)
    lazy fileprivate var memCache = NSCache<NSNumber, UIViewController>()
    open var cachePolicy: CachePolicy = .noLimit {
        didSet {
            memCache.countLimit = cachePolicy.rawValue }
    }
    ///预加载机制，在停止滑动的时候预加载 n 页
    open var preloadPolicy: PreloadPolicy = .never
    ///Whether ContentView bounces
    open var bounces = false
    /// 是否作为 NavigationBar 的 titleView 展示，默认 NO
    open var showOnNavigationBar = false
    ///用代码设置 contentView 的 contentOffset 之前，请设置 startDragging = YES
    open var startDragging = false
    ///下划线进度条的高度
    open var progressHeight: CGFloat = 2.0
    ///顶部菜单栏各个 item 的间隙，因为包括头尾两端，所以确保它的数量等于控制器数量 + 1, 默认间隙为 0
    open var itemsMargins: [CGFloat]?
    ///set itemMargin if all margins are the same, default is 0 如果各个间隙都想同，设置该属性，默认为 0
    open var itemMargin: CGFloat = 0.0
    ///progressView 到 menuView 底部的距离
    open var progressViewBottomSpace: CGFloat = 0
    ///progressView's cornerRadius
    open var progressViewCornerRadius: CGFloat = 0
    ///顶部导航栏
    open weak var menuView: MenuView?
    ///内部容器
    open weak var contentView: WMScrollView?
    ///MenuView 内部视图与左右的间距
    open var menuViewContentMargin: CGFloat = 0.0 {
        didSet {
            guard let menu = menuView else { return }
            menu.contentMargin = oldValue
        }
    }
    ///构造方法，请使用该方法创建控制器. 或者实现数据源方法
    public convenience init(vcClasses: [UIViewController.Type], theirTitles: [String]) {
        self.init()
        assert(vcClasses.count == theirTitles.count, "`vcClasses.count` must equal to `titles.count`")
        titles = theirTitles
        viewControllerClasses = vcClasses
    }
    
    open func reloadData() {
        
    }
    
//    open override func overrideTraitCollection(forChildViewController childViewController: UIViewController) -> UITraitCollection? {
//
//    }
    
    open override func viewDidLayoutSubviews() {
        
    }
    
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
    open func willResignActive(notification: Notification) {
        
    }
    ///当 app 即将回到前台接收到的通知
    open func willEnterForeground(notification: Notification){
        
    }
    

    override open func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override open func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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

open class WMScrollView: UIScrollView, UIGestureRecognizerDelegate {
    
    open func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        
        guard let wrapperView = NSClassFromString("UITableViewWrapperView"), let otherGestureView = otherGestureRecognizer.view else { return false }
        
        if otherGestureView.isKind(of: wrapperView) && (otherGestureRecognizer is UIPanGestureRecognizer) {
            return true
        }
        return false
    }
    
}
