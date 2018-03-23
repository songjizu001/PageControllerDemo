//
//  EnumConfiguration.swift
//  PageControllerExample
//
//  Created by 郑小燕 on 2018/3/23.
//  Copyright © 2018年 郑小燕. All rights reserved.
//

import UIKit
@objc enum MenuItemState: Int {
    case selected
    case normal
}
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
