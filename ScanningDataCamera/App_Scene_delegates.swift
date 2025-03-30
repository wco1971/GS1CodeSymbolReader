//
//  App_Scene_delegates.swift
//  ScanningDataCamera
//
//  Created by washio.t@aist.go.jp on 2025/03/10.
//

//The MIT License
//
//Copyright 2025 Toshikatsu Washio.
//
//Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import Foundation
import UIKit

final class MyAppDelegate: NSObject, UIApplicationDelegate, ObservableObject {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        if connectingSceneSession.role == .windowApplication{
            configuration.delegateClass = MySceneDelegate.self
        }
        return configuration
    }
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        if #available(iOS 17.0, *) {
            let allowedInterfaceOrientationMask: UIInterfaceOrientationMask = .all
            return allowedInterfaceOrientationMask
        } else {
            if UIDevice.current.model == "iPhone" {
                return OrientationController.shared.currentOrientation
            } else{
                let allowedInterfaceOrientationMask: UIInterfaceOrientationMask = .all
                return allowedInterfaceOrientationMask
            }
        }
    }
}

final class MySceneDelegate: NSObject, UIWindowSceneDelegate, ObservableObject {
//    var window: UIWindowScene?
    var sceneID: String = ""
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else {return}
        window = windowScene.keyWindow
        sceneID = session.persistentIdentifier
    }
    func sceneDidDisconnect(_ scene: UIScene) {
    }
}

final class OrientationController {
    
    private init() {}
    
    static let shared = OrientationController()
    
    var currentOrientation: UIInterfaceOrientationMask = .portrait
    
    func unlockOrientation() {
        currentOrientation = .all
    }
    
    func lockOrientation(to orientation: UIInterfaceOrientationMask, onWindow window: UIWindow) {
        
        currentOrientation = orientation
        
        guard var topController = window.rootViewController else {
#if DEBUG
            print("topcontroller does not get:73")
            #endif
            return
        }
        while let presentedViewController = topController.presentedViewController {
            topController = presentedViewController
        }
        topController.setNeedsUpdateOfSupportedInterfaceOrientations()
    }
}
