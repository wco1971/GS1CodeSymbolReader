//
//  RelationInfoViewer.swift
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
import SafariServices

struct RelationInfoViewer: UIViewControllerRepresentable {
    @Binding var remoteInfo: String
    let siteorder: String
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let relationInfoView = SFSafariViewController(url: URL(string:remoteInfo + siteorder)!)
        relationInfoView.dismissButtonStyle = .close
        return relationInfoView
    }
    
    func updateUIViewController(_ uiView: SFSafariViewController, context: Context) {
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, SFSafariViewControllerDelegate{
        let parent:RelationInfoViewer
        
        init(_ parent: RelationInfoViewer){
            self.parent = parent
        }
        
    }

}
