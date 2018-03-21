//
//  CustomViewController.swift
//  PageControllerExample
//
//  Created by 郑小燕 on 2018/3/19.
//  Copyright © 2018年 郑小燕. All rights reserved.
//

import UIKit

class CustomViewController: PageController {

    override func viewDidLoad() {
        super.viewDidLoad()
        self.delegate = self
        self.dataSource = self
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func numbersOfChildControllersInPageController(_ pageController: PageController) -> Int {
        return 20
    }
    
    func pageController(_ pageController: PageController, titleAtIndex index: Int) -> String {
        switch index % 3 {
        case 0:return "First"
        case 1:return "View"
        default:return "NewView"
    }
    }
    
    func pageController(_ pageController: PageController, viewControllerAtIndex index: Int) -> UIViewController {
        switch index % 3 {
        case 0:
            return FirstViewController()
            
        case 1:
            return ViewController()
        default:
            return UIViewController()
        }
    }
    
    override func menuView(_ menu: MenuView, widthForItemAtIndex index: Int) -> CGFloat {
        let width = super.menuView(menu, widthForItemAtIndex: index)
        
        return width + 10
    }
    
    override func pageController(pageController: PageController, preferredFrameForMenuView menuView: MenuView?) -> CGRect {
        return CGRect(x: 0, y: (self.navigationController?.navigationBar.frame.maxY)!, width: self.view.frame.width, height: 44)
    }
    
    override func pageController(pageController: PageController, preferredFrameForContentView scrollView: WMScrollView?) -> CGRect {
        let originY = self.pageController(pageController: pageController, preferredFrameForMenuView: self.menuView ?? nil).maxY
        
        return CGRect(x: 0, y: originY , width: self.view.frame.width, height: self.view.frame.height - originY)
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
