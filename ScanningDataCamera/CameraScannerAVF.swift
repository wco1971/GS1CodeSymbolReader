//
//  CameraScannerAVF.swift
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

import AVFoundation
import SwiftUI

struct CameraScannerAVF: View {
    @ObservedObject var avFoundationSetup: AVFoundationSetup
    @Binding var notNetWorkConnection: Bool
    @EnvironmentObject var sceneDelegate: MySceneDelegate
    @State private var textCase:Mt_Inter_N = .singleUse
    
    var body: some View {
        if avFoundationSetup.isScanStart {
            if #available(iOS 17.0, *) {
                ZStack(alignment: .bottom){
                    ZStack(alignment: .top){
                        CALayerView(avFoundationSetup:avFoundationSetup)
                            .onAppear {
                                if !UIDevice.current.isGeneratingDeviceOrientationNotifications {
                                    UIDevice.current.beginGeneratingDeviceOrientationNotifications()
#if DEBUG
                                    print("begin notification of device orientation")
#endif
                                }
                                guard let window = sceneDelegate.window,
                                      let winScene = window.windowScene else {
#if DEBUG
                                    print("scenedelegate defeat")
#endif
                                    return}
                                let nowUIOrientation = winScene.interfaceOrientation
                                avFoundationSetup.orientation = nowUIOrientation
                                avFoundationSetup.convertDevicetoSessionOrientation()
                                avFoundationSetup.startSession()
                            }
                            .onReceive(NotificationCenter.default.publisher(for:UIDevice.orientationDidChangeNotification)) { _ in
                                guard let window = sceneDelegate.window,
                                      let winScene = window.windowScene else {
#if DEBUG
                                    print("scenedelegate defeat")
#endif
                                    return}
                                let nowUIOrientation = winScene.interfaceOrientation
#if DEBUG
                                print("gets device orientation")
#endif
                                avFoundationSetup.orientation = nowUIOrientation
                                avFoundationSetup.convertDevicetoSessionOrientation()
#if DEBUG
                                print("notification is captured!")
#endif
                            }
                            .onReceive(NotificationCenter.default.publisher(for:.AVCaptureSessionWasInterrupted)) { notification in
                                guard let userinfo = notification.userInfo,
                                      let reasonValue = userinfo[AVCaptureSessionInterruptionReasonKey] as? Int,
                                      let reason = AVCaptureSession.InterruptionReason(rawValue: reasonValue) else {
#if DEBUG
                                    print("Failed to parse the interruption reason.")
#endif
                                    return
                                }
                                guard let window = sceneDelegate.window else{
#if DEBUG
                                    print("ambitious is defeated")
#endif
                                    return
                                }
                                let sceneID = sceneDelegate.sceneID
                                #if DEBUG
                                print("SceneID: \(sceneID)")
                                #endif
                                let sublayers = window.layer.sublayers
                                let previewLayerID = sublayers?.last.hashValue
                                let interruptedTexualString : String = notification.description
#if DEBUG
                                print("userinfo description: \(notification.customMirror )")
                                print("interrupted notification contents: \(interruptedTexualString)")
                                print("previewLayerID: \(previewLayerID!)")
#endif
                                    switch reason {
                                    case .videoDeviceInUseByAnotherClient:
                                        textCase = .otherApp
                                    case .videoDeviceNotAvailableDueToSystemPressure:
                                        textCase = .systemPress
                                    case .videoDeviceNotAvailableWithMultipleForegroundApps:
                                        textCase = .notUseWithMultitask
                                    case .audioDeviceInUseByAnotherClient:
                                        textCase = .otherApp
                                    default:
                                        textCase = .otherReason
                                    }
                            }
                            .onReceive(NotificationCenter.default.publisher(for:.AVCaptureSessionInterruptionEnded)) { notification in
                                guard let window = sceneDelegate.window else
                                {print("ambitious is defeated");return}
                                let sublayers = window.layer.sublayers
                                let previewLayerID = sublayers?.last.hashValue
                                let interruptionEndedTexualString : String = notification.description
#if DEBUG
                                print("InterruptionEnd notification contents: \(interruptionEndedTexualString)")
                                print("previewLayerID: \(previewLayerID!)")
#endif
                                textCase = .singleUse
                            }
                            .onReceive(NotificationCenter.default.publisher(for: UIScene.didDisconnectNotification)) {notification in
                            }
                            .onDisappear {
                                if UIDevice.current.isGeneratingDeviceOrientationNotifications{
                                    UIDevice.current.endGeneratingDeviceOrientationNotifications()
#if DEBUG
                                    print("end notification of device orientation")
#endif
                                }
                                notNetWorkConnection = false
                                if textCase == .otherApp{
                                    textCase = .singleUse
                                }
                            }
                        
                        VStack{
                            switch textCase{
                            case .singleUse:
                                Text("SingleUse1Key").font(.title)
                                HStack{
                                    Image(systemName: "barcode").imageScale(.large)
                                    Text("SingleUse2Key").font(.title)
                                }
                                Text("SingleUse3Key").font(.title)
                                if UIDevice.current.userInterfaceIdiom == .pad{
                                    Text("SingleUse4Key").font(.title)
                                    Text("SingleUse5Key").font(.title)
                                }
                            case .otherApp:
                                Text("CameraNoUsewithOtherMultitaskingAppUsesKey").font(.title)
                            case .systemPress:
                                Text("CameraNoUsewithHighSystemPressKey").font(.title)
                            case .notUseWithMultitask:
                                Text("CameraNoUsewiththishardwareKey").font(.title)
                            default:
                                Text("CameranoUseOtherReasonsKey").font(.title)
                            }
                            
                        }
                        .foregroundStyle(.white).background(.black).opacity(0.5)
                    }
                    if UIDevice.current.userInterfaceIdiom == .pad {
                        Button(action:{
                            avFoundationSetup.switchCamera()
                        }) {
                            VStack{
                                Image(systemName: "arrow.triangle.2.circlepath.camera")
                                    .imageScale(.large)
                                Text("")
                            }
                        }
                    }
                }
            } else {
                ZStack(alignment: .top){
                    CALayerView(avFoundationSetup:avFoundationSetup)
                        .onAppear {
                            if UIDevice.current.model == "iPhone" {
                                if let window = sceneDelegate.window {
                                    OrientationController.shared.lockOrientation(to: .portrait,
                                                                                 onWindow: window)
                                }
#if DEBUG
                                print("view lock finished:227")
                                #endif
                            }else {
                                if !UIDevice.current.isGeneratingDeviceOrientationNotifications {
                                    UIDevice.current.beginGeneratingDeviceOrientationNotifications()
#if DEBUG
                                    print("begin notification of device orientation")
#endif
                                }
                                guard let window = sceneDelegate.window,
                                      let winScene = window.windowScene else {
#if DEBUG
                                    print("scenedelegate defeat")
#endif
                                    return}
                                let nowUIOrientation = winScene.interfaceOrientation
                                avFoundationSetup.orientation = nowUIOrientation
                                avFoundationSetup.convertDevicetoSessionOrientation()
                            }
                            avFoundationSetup.startSession()
                        }
                        .onReceive(NotificationCenter.default.publisher(for:UIDevice.orientationDidChangeNotification)) { _ in
                            guard let window = sceneDelegate.window,
                                  let winScene = window.windowScene else {
#if DEBUG
                                print("scenedelegate defeat")
#endif
                                return}
                            let nowUIOrientation = winScene.interfaceOrientation
#if DEBUG
                            print("gets device orientation")
#endif
                            avFoundationSetup.orientation = nowUIOrientation
                            avFoundationSetup.convertDevicetoSessionOrientation()
#if DEBUG
                            print("notification is captured!")
#endif
                        }
                        .onDisappear {
                            OrientationController.shared.unlockOrientation()
                            notNetWorkConnection = false
                        }
                        .onReceive(NotificationCenter.default.publisher(for:.AVCaptureSessionWasInterrupted)) { notification in
                            guard let userinfo = notification.userInfo,
                                  let reasonValue = userinfo[AVCaptureSessionInterruptionReasonKey] as? Int,
                                  let reason = AVCaptureSession.InterruptionReason(rawValue: reasonValue) else {
                                print("Failed to parse the interruption reason.")
                                return
                            }
                            switch reason {
                            case .videoDeviceInUseByAnotherClient:
                                textCase = .otherApp
                            case .videoDeviceNotAvailableDueToSystemPressure:
                                textCase = .systemPress
                            case .videoDeviceNotAvailableWithMultipleForegroundApps:
                                textCase = .notUseWithMultitask
                            case .audioDeviceInUseByAnotherClient:
                                textCase = .otherApp
                            default:
                                textCase = .otherReason
                            }
                        }
                        .onReceive(NotificationCenter.default.publisher(for:.AVCaptureSessionInterruptionEnded)) { _ in
                            textCase = .singleUse
                        }
                    VStack{
                        switch textCase{
                        case .singleUse:
                            Text("SingleUse1Key").font(.title)
                            HStack{
                                Image(systemName: "barcode").imageScale(.large)
                                Text("SingleUse2Key").font(.title)
                            }
                            Text("SingleUse3Key").font(.title)
                        case .otherApp:
                            Text("CameraNoUsewithOtherMultitaskingAppUsesKey").font(.title)
                        case .systemPress:
                            Text("CameraNoUsewithHighSystemPressKey").font(.title)
                        case .notUseWithMultitask:
                            Text("CameraNoUsewiththishardwareKey").font(.title)
                        default:
                            Text("CameranoUseOtherReasonsKey").font(.title)
                        }
                    }
                    .foregroundColor(.white).background(.black).opacity(0.5)
                }
            }
        }
    }
}

struct CameraScannerAVF_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CameraScannerAVF(avFoundationSetup:AVFoundationSetup(),notNetWorkConnection:.constant(true)).environment(\.locale, .init(identifier: "Ja"))
            CameraScannerAVF(avFoundationSetup:AVFoundationSetup(),notNetWorkConnection:.constant(true))
        }
    }
}
