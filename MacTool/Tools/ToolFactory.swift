//
//  ToolFactory.swift
//  MacTool
//
//  Created by Garenge on 2025/11/1.
//

import Cocoa

class ToolFactory {
    
    /// 根据工具类型创建对应的视图控制器
    static func createViewController(for type: ToolType) -> NSViewController {
        switch type {
        case .power:
            return PowerViewController()
        case .theme:
            return ThemeViewController()
        }
    }
}

