//
//  webPDFViewSelector.swift
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
import AudioToolbox

struct webPDFViewSelector: View {
    @ObservedObject var avFoundationSetup: AVFoundationSetup
    @Binding var notNetWorkConnection: Bool
    @Binding var remoteInfo:String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.isPresented) private var isPresented
    
    @State var infoshow: Bool = false
    @State var allSite: Bool = false
    @State var nonMedicalSite: Bool = false

    let allSiteString: String = "?user=1"
    let soundID:SystemSoundID = 1108

    var body: some View {
        if avFoundationSetup.isAIData && avFoundationSetup.scanResult.count == 14 && avFoundationSetup.symbolType != .other{
            if !notNetWorkConnection{
                    NavigationStack{
                        PackageInsertsViewer(avFoundationSetup:avFoundationSetup, notNetWorkConnection: $notNetWorkConnection, remoteInfo:$remoteInfo)
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Menu{
                                        Button{
                                            infoshow = true
                                        } label:{Text("ReadInfoFromAI"); Image(systemName: "info.circle")
                                        }
                                        Button{
                                            allSite = true
                                        } label:{Text("ForMedical");Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                                        }
                                    } label:{
                                        Text("RelatedInfo");
                                    }
                                }
                            }
                    }
                    .interactiveDismissDisabled(true)
                    .sheet(isPresented: $infoshow){
                        InfoUIView(avFoundationSetup:avFoundationSetup)
                    }
                    .fullScreenCover(isPresented: $allSite){
                        RelationInfoViewer(remoteInfo:$remoteInfo, siteorder: allSiteString)
                    }
                    .onAppear{
                        AudioServicesPlaySystemSound(soundID)
                        if UIDevice.current.model == "iPhone" {
                            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                        }
                    }
            } else{
                NavigationStack{
                    Text("errorNetWorkKey")
                        .font(.headline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button {
                                    if isPresented{
                                        avFoundationSetup.viewStopscanStart()
                                        dismiss()
                                    }
                                    else {
                                        avFoundationSetup.viewStopscanStart()
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle")
                                }
                            }
                        }
                }
                .onAppear{
                    AudioServicesPlaySystemSound(soundID)
                    if UIDevice.current.userInterfaceIdiom == .phone {
                        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                    }
                }
            }
        }else {
            NavigationStack{
                VStack{
                    Text("SymbolTypeErrorKey")
                        .font(.headline)
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
                }
                .onAppear{
                    AudioServicesPlaySystemSound(soundID)
                    if UIDevice.current.userInterfaceIdiom == .phone {
                        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            if isPresented{
                                avFoundationSetup.viewStopscanStart()
                                dismiss()
                            }
                            else {
                                avFoundationSetup.viewStopscanStart()
                            }
                        } label: {
                            Image(systemName: "xmark.circle")
                        }
                    }
                }
            }
        }
    }
}

struct webPDFViewSelector_Previews: PreviewProvider {
    static var previews: some View {
        Group{
            webPDFViewSelector(avFoundationSetup:AVFoundationSetup(), notNetWorkConnection: .constant(true),remoteInfo:.constant("")).environment(\.locale, .init(identifier: "Ja"))
            webPDFViewSelector(avFoundationSetup:AVFoundationSetup(), notNetWorkConnection: .constant(true),remoteInfo:.constant(""))
        }
    }
}
