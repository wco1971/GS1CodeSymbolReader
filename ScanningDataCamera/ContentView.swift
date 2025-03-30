//
//  ContentView.swift
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

import SwiftUI
import AVFoundation

struct ContentView: View {
    @State private var showDeviceNotCapacityAlert = false
    @State private var canAuthorized = false
    @State private var isConfigurationFailed = false
    @State private var setupResult: SessionSetupResult = .success
    @State private var notNetWorkConnection = false
    @State var remoteInfo: String = "/"
    @StateObject var avFoundationSetup = AVFoundationSetup()

    var body: some View {
        CameraScannerAVF(avFoundationSetup:avFoundationSetup, notNetWorkConnection: $notNetWorkConnection)
            .fullScreenCover(isPresented: $avFoundationSetup.isWebPDFView){
                webPDFViewSelector(avFoundationSetup:avFoundationSetup, notNetWorkConnection: $notNetWorkConnection, remoteInfo:$remoteInfo)}
            .alert("Permission denied", isPresented: $canAuthorized, actions: { Button(action: {
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)}, label: {Text("OK")})}, message: { Text("changePrivatySettingKey")})
            .alert("Configuration failed", isPresented: $isConfigurationFailed, actions: {}, message: { Text("errorConfigurationMediaKey")})
            .onAppear {
                switch AVCaptureDevice.authorizationStatus(for: .video) {
                case .authorized:
                    break
                    
                case .notDetermined:
                    AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
                        if !granted {
                            setupResult = .notAuthorized
                        }
                    })
                    
                default:
                    setupResult = .configurationFailed
                    
                }
                
                switch setupResult {
                case .success:
                    avFoundationSetup.isScanStart = true
                    
                case .notAuthorized:
                    canAuthorized = true
                case .configurationFailed:
                    isConfigurationFailed = true
                }
            }
            .onDisappear {
                avFoundationSetup.image = nil
                avFoundationSetup.endSession()
                avFoundationSetup.scanStopViewStart()
            }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group{
            ContentView().environment(\.locale, .init(identifier: "Ja"))
            ContentView()
        }
    }
}
