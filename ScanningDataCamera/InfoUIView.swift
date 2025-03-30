//
//  InfoUIView.swift
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

struct InfoUIView: View {
    @ObservedObject var avFoundationSetup: AVFoundationSetup
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack{
            VStack {
                if let showImage = avFoundationSetup.image{
                    Image(uiImage: showImage)
                        .resizable()
                        .scaledToFit()
                }
                List{
                    ForEach(avFoundationSetup.content_List){ content in
                        HStack(alignment:.top,spacing: 20){
                            Text(content.title)
                            Divider()
                            Spacer()
                            Text(content.content)
                        }
                    }
                }
                .navigationTitle("ReadInfoFromAI")
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle")
                    }
                }
            }
        }
    }
}

struct InfoUIView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            InfoUIView(avFoundationSetup:AVFoundationSetup()).environment(\.locale, .init(identifier: "Ja"))
            InfoUIView(avFoundationSetup:AVFoundationSetup())
        }
    }
}
