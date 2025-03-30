//
//  AVFoundationSetup.swift
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
import Vision

class AVFoundationSetup: NSObject,ObservableObject,AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var image: UIImage?
    @Published var scanResult: String = ""
    @Published var symbolType: BarcodeSymbol = .other
    @Published var isScanStart: Bool = false
    @Published var previewLayer:CALayer!
    @Published var content_List:[GS1_Code_Content] = []
    @Published var isWebPDFView: Bool = false
    @Published var isAIData: Bool = true
    @Published var orientation: UIInterfaceOrientation = .portrait
    private let captureSession = AVCaptureSession()
    private var capturepDevice:AVCaptureDevice!
    private var availableDevice:AVCaptureDevice!
    private var captureDeviceInput:AVCaptureDeviceInput!
    private var position:AVCaptureDevice.Position = .back
    private var rotation:CGFloat = CGFloat(0)
    private var requests: [VNRequest] = []
    
    override init() {
        super.init()
        
        capturepDevice = prepareCamera(for: .back)
        beginSession()
    }
    
    private func prepareCamera(for position: AVCaptureDevice.Position) -> AVCaptureDevice! {
        
        if let newDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInUltraWideCamera], mediaType: AVMediaType.video, position: position).devices.first {
            availableDevice = newDevice
            if availableDevice.isSmoothAutoFocusSupported == true{
                do {
                    try availableDevice.lockForConfiguration()
                    availableDevice.isSmoothAutoFocusEnabled = true
                    availableDevice.unlockForConfiguration()
                } catch {
#if DEBUG
                    print(error.localizedDescription)
#endif
                }
            }
        }
        return availableDevice
    }
    
    func switchCamera() {
        guard let currentInput = captureDeviceInput else {
            return
        }
        
        captureSession.beginConfiguration()
        captureSession.removeInput(currentInput)
        
        position = capturepDevice.position == .back ? .front : .back
        
        guard let newCamera = prepareCamera(for: position) else {
            captureSession.addInput(currentInput)
            captureSession.commitConfiguration()
            return
        }
        
        do {
            let newVideoDeviceInput = try AVCaptureDeviceInput(device: newCamera)
            if captureSession.canAddInput(newVideoDeviceInput) {
                captureSession.addInput(newVideoDeviceInput)
                self.captureDeviceInput = newVideoDeviceInput
                self.capturepDevice = newCamera
            } else {
                captureSession.addInput(currentInput)
            }
        } catch {
#if DEBUG
            print(error.localizedDescription)
#endif
        }
        captureSession.commitConfiguration()
    }
    
    private func beginSession() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo
        
        do {
            captureDeviceInput = try AVCaptureDeviceInput(device: capturepDevice)
            if captureSession.canAddInput(captureDeviceInput){
                captureSession.addInput(captureDeviceInput)
            }
        } catch {
#if DEBUG
            print(error.localizedDescription)
#endif
        }
        
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA]
        
        if captureSession.canAddOutput(dataOutput) {
            captureSession.addOutput(dataOutput)
        }
        
        let mypreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        mypreviewLayer.videoGravity = .resizeAspect
        previewLayer = mypreviewLayer
        
        if captureSession.isMultitaskingCameraAccessSupported {
            captureSession.isMultitaskingCameraAccessEnabled = true
#if DEBUG
            print("multitasking with camera is OK!")
#endif
        }
        captureSession.commitConfiguration()
        dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue.main)
    }
    
    func startSession() {
        if captureSession.isRunning { return }
        
        let capqueue = DispatchQueue.global(qos: .background)
        capqueue.async {
            self.captureSession.startRunning()
        }
    }
    
    func endSession() {
        if !captureSession.isRunning { return }
        captureSession.stopRunning()
        previewLayer = nil
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspect
        self.previewLayer = previewLayer
    }
    
    func scanStopViewStart() {
        isScanStart = false
        isWebPDFView = true
    }
    func viewStopscanStart() {
        isWebPDFView = false
        isScanStart = true
    }
    
    func convertDevicetoSessionOrientation() {
#if DEBUG
        print("AVF session orientation:\(orientation.rawValue)")
#endif
        if #available(iOS 17.0, *) {
            if position == .back {
                switch orientation.rawValue {
                case 1:
                    rotation = CGFloat(90)
                case 2:
                    rotation = CGFloat(270)
                case 3:
                    rotation = CGFloat(0)
                case 4:
                    rotation = CGFloat(180)
                default:
                    rotation = CGFloat(90)
                }
                if captureSession.connections.last!.isVideoRotationAngleSupported(rotation) {
                    captureSession.connections.last!.videoRotationAngle = rotation
#if DEBUG
                    print("captureSession videorotationangle is used")
#endif
                } else {
                    switch orientation.rawValue {
                    case 1:
                        rotation = CGFloat(0)
                    case 2:
                        rotation = CGFloat(180)
                    case 3:
                        rotation = CGFloat(270)
                    case 4:
                        rotation = CGFloat(90)
                    default:
                        rotation = CGFloat(0)
                    }
                    previewLayer?.transform = CATransform3DMakeRotation(rotation/180*CGFloat.pi,CGFloat(0),CGFloat(0),CGFloat(1))
#if DEBUG
                    print("previewLayer CATransform3DMakeRotation is used")
#endif
                }
#if DEBUG
                print("AVF session orientation iOS17+:\(captureSession.connections.last!.videoRotationAngle)")
#endif
            } else {
                switch orientation.rawValue {
                case 1:
                    rotation = CGFloat(90)
                case 2:
                    rotation = CGFloat(270)
                case 3:
                    rotation = CGFloat(180)
                case 4:
                    rotation = CGFloat(0)
                default:
                    rotation = CGFloat(90)
                }
                if captureSession.connections.last!.isVideoRotationAngleSupported(rotation) {
                    captureSession.connections.last!.videoRotationAngle = rotation
#if DEBUG
                    print("AVF videorotationangle is used")
#endif
                } else {
                    switch orientation.rawValue {
                    case 1:
                        rotation = CGFloat(0)
                    case 2:
                        rotation = CGFloat(180)
                    case 3:
                        rotation = CGFloat(90)
                    case 4:
                        rotation = CGFloat(270)
                    default:
                        rotation = CGFloat(0)
                    }
                    previewLayer?.transform = CATransform3DMakeRotation(rotation/180*CGFloat.pi,CGFloat(0),CGFloat(0),CGFloat(1))
#if DEBUG
                    print("previewLayer CATransform3DMakeRotation is used")
#endif
                }
#if DEBUG
                print("AVF session orientation iOS17+:\(captureSession.connections.last!.videoRotationAngle)")
#endif
            }
        }else {
                if captureSession.connections.last!.isVideoOrientationSupported{
#if DEBUG
                    print("capture_connection_videoOrientation:\(captureSession.connections.last!.videoOrientation.rawValue)")
#endif
                    captureSession.connections.last!.videoOrientation = device_session_Orientations[orientation]!
                    
#if DEBUG
                    print("capture_connection_videoOrientation:\(captureSession.connections.last!.videoOrientation.rawValue)")
                    print("videoOrientation is used")
#endif
                } else {
                    switch orientation.rawValue {
                    case 1:
                        rotation = CGFloat(0)
                    case 2:
                        rotation = CGFloat(0)
                    case 3:
                        rotation = CGFloat(270)
                    case 4:
                        rotation = CGFloat(90)
                    default:
                        rotation = CGFloat(0)
                    }
                    previewLayer?.transform = CATransform3DMakeRotation(rotation/180*CGFloat.pi,CGFloat(0),CGFloat(0),CGFloat(1))
#if DEBUG
                    print("previewLayer CATransform3DMakeRotation is used")
#endif
                }
#if DEBUG
                print("AVF session orientaiton iOS16:\(captureSession.connections.last!.videoOrientation.rawValue)")
#endif
        }
    }
    
    lazy var barcodeDetectionRequest: VNDetectBarcodesRequest = {
        let barcodeDetectRequest = VNDetectBarcodesRequest(completionHandler: self.handleDetectedBarcodes)
        barcodeDetectRequest.symbologies = [.code128, .dataMatrix, .gs1DataBarLimited]
        return barcodeDetectRequest
    }()
    
    private func handleDetectedBarcodes(request: VNRequest?, error: Error?) {
        if (error as NSError?) != nil {
            fatalError("Barcode Detection Error")
        }
        Task {@MainActor [weak self] in
            guard let results = request?.results as? [VNBarcodeObservation] else {
                fatalError(String(localized: "VNBarcodeDetectErrorKey"))
            }
            if let observation = results.first{
                self?.getMetadatafromObservation(observation: observation)
            }
        }
    }
    internal func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if position == .front {
            let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .upMirrored, options: [:])
            requests.append(barcodeDetectionRequest)
            DispatchQueue.main.async {
                do{
                    try handler.perform(self.requests)
                }catch{
                    
                }
                if let image = self.getImageFromSampleBuffer(buffer: sampleBuffer) {
                    self.image = image
                }
            }
        }else {
            let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer,  options: [:])
            requests.append(barcodeDetectionRequest)
            DispatchQueue.main.async {
                do{
                    try handler.perform(self.requests)
                }catch{
                    
                }
                if let image = self.getImageFromSampleBuffer(buffer: sampleBuffer) {
                    self.image = image
                }
            }
        }
    }
    
    private func getImageFromSampleBuffer (buffer: CMSampleBuffer) -> UIImage? {
        if let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) {
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let context = CIContext()
            
            let imageRect = CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
            
            if let image = context.createCGImage(ciImage, from: imageRect) {
                if position == .back {
                    return UIImage(cgImage: image, scale: UIScreen.main.scale, orientation: bdevice_image_Orientations[orientation]!)
                } else {
                    return UIImage(cgImage: image, scale: UIScreen.main.scale, orientation: fdevice_image_Orientations[orientation]!)
                }
            }
        }
        return nil
    }

    private func getMetadatafromObservation(observation: VNBarcodeObservation){
        if content_List.count > 0{
            content_List.removeAll()
        }
        guard let barcode_payload_text = observation.payloadStringValue else{
            content_List.append(GS1_Code_Content(title: String(localized: "ReadInformationKey"), content: String(localized: "VNBarcodeDetectErrorKey")))
            return
        }
        content_List.append(GS1_Code_Content(title: String(localized: "ReadInformationKey"), content: barcode_payload_text))
#if DEBUG
        print("symbol payload Text: \(barcode_payload_text)")
#endif
        if #available(iOS 17.0, *){
            let compositeType = observation.supplementalCompositeType
            #if DEBUG
            switch compositeType{
            case VNBarcodeCompositeType.gs1TypeA:
                print("This symbol is GS1CompositeTypeA")
            case VNBarcodeCompositeType.gs1TypeB:
                print("This symbol is GS1CompositeTypeB")
            case VNBarcodeCompositeType.gs1TypeC:
                print("This symbol is GS1CompositeTypeC")
            case VNBarcodeCompositeType.linked:
                print("This symbol is GS1CompositeLinked")
            case VNBarcodeCompositeType.none:
                print("This symbol is Unknown composite type")
            }
            #endif
            if let result = observation.payloadData {
#if DEBUG
                print("raw Data Size: \(result)")
                let hexMat = result.map{String(format:"%02x",$0)}
                print("raw Data Matrix: \(hexMat)")
#endif
                switch observation.symbology {
                case VNBarcodeSymbology.gs1DataBarLimited:
                    symbolType = .gsdatabarlimited
                    content_List.append(GS1_Code_Content(title:String(localized:"GS1CodeSymbolKey"),content:String(localized: "GS1DataBarLimitedKey")))
                    readAIandMakeInfoArray16(barcode_paylod_text: barcode_payload_text)
                case VNBarcodeSymbology.code128:
                    if observation.isGS1DataCarrier == true{
                        symbolType = .gs128
                        content_List.append(GS1_Code_Content(title:String(localized:"GS1CodeSymbolKey"),content:String(localized: "GS1-128Key")))
                        let resultString = readCodefromGS1_128(result:hexMat)
                        readAIandMakeInfoArray(barcode_paylod_text: resultString)
                    } else{
                        symbolType = .other
                        content_List.append(GS1_Code_Content(title:String(localized:"GS1CodeSymbolKey"),content:String(localized: barCodeSymbolType[observation.symbology]!)))
                        scanResult = ""
                    }
                case VNBarcodeSymbology.dataMatrix:
                    if observation.isGS1DataCarrier == true{
                        symbolType = .gsdatamatrix
                        #if DEBUG
                        if observation.supplementalPayloadString != nil{
                            print("2D data supplemental pay load: \(observation.supplementalPayloadString!)")
                        }
                        #endif
                        content_List.append(GS1_Code_Content(title:String(localized: "GS1CodeSymbolKey"),content:String(localized: "GS1DataMatrixKey")))
                        let resultString = readCodefromGS1_Data_Matrix(result:hexMat)
                        readAIandMakeInfoArray(barcode_paylod_text: resultString)
                    } else{
                        symbolType = .other
                        content_List.append(GS1_Code_Content(title:String(localized:"GS1CodeSymbolKey"),content:String(localized: barCodeSymbolType[observation.symbology]!)))
                        scanResult = ""
                    }
                default:
                    symbolType = .other
                }
            }else {
               distinguishBarcodeSymbol(description: observation.description, barcode_symbology: observation.symbology)
                if symbolType != .other {
                    readAIandMakeInfoArray16(barcode_paylod_text: barcode_payload_text)
                }
            }
        } else {
            distinguishBarcodeSymbol(description: observation.description, barcode_symbology: observation.symbology)
            if symbolType != .other {
                readAIandMakeInfoArray16(barcode_paylod_text: barcode_payload_text)
            }
        }
        endSession()
        scanStopViewStart()
    }
    
    private func distinguishBarcodeSymbol(description result:String, barcode_symbology symbol:VNBarcodeSymbology) {
#if DEBUG
        print("Full infomation from symbol: \(result)")
#endif
        let searchPhraseRange:Range<String.Index>? = result.range(of:"bytes = ")
        let locationbs : String.Index = result.index(searchPhraseRange!.upperBound, offsetBy: 0)
        let devidedResult : String = String(result[locationbs..<result.endIndex])
        let locationbe : String.Index = devidedResult.firstIndex(of: "}")!
        let bytesInfo : String = String(devidedResult[devidedResult.startIndex..<locationbe])
#if DEBUG
        print("resection of full infomation:\(bytesInfo)")
#endif
        let GS1Byte : String = bytesInfo.filter { !$0.isWhitespace }
#if DEBUG
        print("GS1 code raw data:\(GS1Byte)")
#endif
        let location : String.Index = GS1Byte.firstIndex(of: "x")!
        switch symbol {
        case VNBarcodeSymbology.gs1DataBarLimited:
            symbolType = .gsdatabarlimited
            content_List.append(GS1_Code_Content(title:String(localized: "GS1CodeSymbolKey"),content: String(localized: "GS1DataBarLimitedKey")))
        case VNBarcodeSymbology.code128:
            let indexs : String.Index = GS1Byte.index(location,offsetBy:3)
            let indexe : String.Index = GS1Byte.index(location,offsetBy:4)
            let isFNC1 : String = String(GS1Byte[indexs...indexe])
            if isFNC1 == "66"{
                symbolType = .gs128
                content_List.append(GS1_Code_Content(title:String(localized: "GS1CodeSymbolKey"),content:String(localized: "GS1-128Key")))
            } else{
                symbolType = .other
                content_List.append(GS1_Code_Content(title:String(localized:"GS1CodeSymbolKey"),content:String(localized: barCodeSymbolType[symbol]!)))
                scanResult = ""
            }
        case VNBarcodeSymbology.dataMatrix:
            let indexs : String.Index = GS1Byte.index(location,offsetBy:1)
            let indexe : String.Index = GS1Byte.index(location,offsetBy:2)
            let isFNC1 : String = String(GS1Byte[indexs...indexe])
            if isFNC1 == "e8"{
                symbolType = .gsdatamatrix
                content_List.append(GS1_Code_Content(title:String(localized: "GS1CodeSymbolKey"),content:String(localized: "GS1DataMatrixKey")))
            } else{
                symbolType = .other
                content_List.append(GS1_Code_Content(title:String(localized:"GS1CodeSymbolKey"),content:String(localized: barCodeSymbolType[symbol]!)))
                scanResult = ""
            }
        default:
            symbolType = .other
            scanResult = ""
        }
#if DEBUG
        print("symbol type from distinguishBarcodeSymbol: \(symbolType)")
#endif
    }
    
    private func readAIandMakeInfoArray16(barcode_paylod_text text:String) {
        var leftText : String = text
        var tempText : String = ""
        var AI : String = ""
        var checkCounter : Int = 0
        var counter : Int = 0//debug用
        var AIType : AI_Type = .other
        var AICounter : Int = 0

        let aiArrayCount : Int = fixLengthwithoutFNC1_AI.count
        let idxAIs : String.Index = leftText.startIndex
        let idxAIn : String.Index = leftText.index(after:idxAIs)
        let idxAInn : String.Index = leftText.index(after:idxAIn)
        let idxAInnn : String.Index = leftText.index(after:idxAInn)
        
        isAIData = true
        
        repeat {
            AIType = .other
            counter = counter + 1
            if leftText.count >= 2 {
                checkCounter = 0
                AI = String(leftText[idxAIs...idxAIn])
#if DEBUG
                print("AI type:\(AI)")
#endif
                while aiArrayCount > checkCounter {
                    if fixLengthwithoutFNC1_AI[checkCounter].count != 2{
                        checkCounter = checkCounter + 1
                        continue
                    }else {
                        if AI == fixLengthwithoutFNC1_AI[checkCounter]{
                            AIType = .ai2fix
                            AICounter = AICounter + 1
                            break
                        }
                        checkCounter = checkCounter + 1
                    }
                }
            }
            
            if AIType == .other{
                if leftText.count >= 3 {
                    checkCounter = 0
                    AI = String(leftText[idxAIs...idxAInn])
                    while aiArrayCount > checkCounter {
                        if fixLengthwithoutFNC1_AI[checkCounter].count != 3{
                            checkCounter = checkCounter + 1
                            continue
                        }else {
                            if AI == fixLengthwithoutFNC1_AI[checkCounter]{
                                AIType = .ai3fix
                                AICounter = AICounter + 1
                                break
                            }
                            checkCounter = checkCounter + 1
                        }
                    }
                }
            }
            
            if AIType == .other{
                if leftText.count >= 4 {
                    checkCounter = 0
                    AI = String(leftText[idxAIs...idxAInnn])
                    while aiArrayCount > checkCounter {
                        if fixLengthwithoutFNC1_AI[checkCounter].count != 4{
                            checkCounter = checkCounter + 1
                            continue
                        }else {
                            if AI == fixLengthwithoutFNC1_AI[checkCounter]{
                                AIType = .ai4fix
                                AICounter = AICounter + 1
                                break
                            }
                            checkCounter = checkCounter + 1
                        }
                    }
                }
            }
            
            switch AIType{
            case .ai2fix:
                tempText = readfromAI2fix(text: leftText, AI: AI)
                leftText = tempText
#if DEBUG
                print("remain of GS1 code payload text:\(leftText)")
#endif
            case .ai3fix:
                tempText = readfromAI3fix(text: leftText, AI: AI)
                leftText = tempText
            case .ai4fix:
                tempText = readfromAI4fix(text: leftText, AI: AI)
                leftText = tempText
            default:
                content_List.append(GS1_Code_Content(title: String(localized: "noMoreReadAIKey"), content: leftText))
            }
#if DEBUG
            print("# of iteration:\(counter)")
#endif
            if AIType == .other{
                if AICounter == 0{
                    isAIData = false
                }
                break
            }
        }while leftText.count > 0
    }
    
    private func readAIandMakeInfoArray(barcode_paylod_text text:String) {
        var leftText : String = String(text.dropFirst(1))
        var AI : String = ""
        var checkCounter : Int = 0
        var counter : Int = 0
        var AIType : AI_Type = .other
        var AICounter : Int = 0

        let idxAIs : String.Index = leftText.startIndex
        let idxAIn : String.Index = leftText.index(after:idxAIs)
        let idxAInn : String.Index = leftText.index(after:idxAIn)
        let idxAInnn : String.Index = leftText.index(after:idxAInn)
        let aiArray2fixCount : Int = ai2fix.count
        let aiArray2nonCount : Int = ai2non.count
        let aiArray3fixCount : Int = ai3fix.count
        let aiArray3nonCount : Int = ai3non.count
        let aiArray4fixCount : Int = ai4fix.count
        let aiArray4nonCount : Int = ai4non.count
        
        isAIData = true
        
        repeat {
            AIType = .other
            counter = counter + 1
            if leftText.count >= 2 {
                checkCounter = 0
                AI = String(leftText[idxAIs...idxAIn])
#if DEBUG
                print("AI type:\(AI)")
#endif
                while aiArray2fixCount > checkCounter {
                    if AI == ai2fix[checkCounter]{
                        AIType = .ai2fix
                        AICounter = AICounter + 1
                        break
                    }
                    checkCounter = checkCounter + 1
                }
                if AIType == .other {
                    checkCounter = 0
                    while aiArray2nonCount > checkCounter {
                        if AI == ai2non[checkCounter]{
                            AIType = .ai2non
                            AICounter = AICounter + 1
                            break
                        }
                        checkCounter = checkCounter + 1
                    }
                }
            }
            
            if AIType == .other{
                if leftText.count >= 3 {
                    checkCounter = 0
                    AI = String(leftText[idxAIs...idxAInn])
                    while aiArray3fixCount > checkCounter {
                        if AI == ai3fix[checkCounter]{
                            AIType = .ai3fix
                            AICounter = AICounter + 1
                            break
                        }
                        checkCounter = checkCounter + 1
                    }
                    if AIType == .other{
                        checkCounter = 0
                        while aiArray3nonCount > checkCounter {
                            if AI == ai3non[checkCounter]{
                                AIType = .ai3non
                                AICounter = AICounter + 1
                                break
                            }
                            checkCounter = checkCounter + 1
                        }

                    }
                }
            }
            
            if AIType == .other{
                if leftText.count >= 4 {
                    checkCounter = 0
                    AI = String(leftText[idxAIs...idxAInnn])
                    while aiArray4fixCount > checkCounter {
                        if AI == ai4fix[checkCounter]{
                            AIType = .ai4fix
                            AICounter = AICounter + 1
                            break
                        }
                        checkCounter = checkCounter + 1
                    }
                    if AIType == .other{
                        checkCounter = 0
                        while aiArray4nonCount > checkCounter {
                            if AI == ai4non[checkCounter]{
                                AIType = .ai4non
                                AICounter = AICounter + 1
                                break
                            }
                            checkCounter = checkCounter + 1
                        }

                    }

                }
            }
            
            switch AIType{
            case .ai2fix:
                leftText = readfromAI2fix(text: leftText, AI: AI)
#if DEBUG
                print("remain of GS1 code payload text:\(leftText)")
#endif
            case .ai2non:
                leftText = readfromAI2non(text: leftText, AI: AI)
            case .ai3fix:
                leftText = readfromAI3fix(text: leftText, AI: AI)
            case .ai3non:
                leftText = readfromAI3non(text: leftText, AI: AI)
            case .ai4fix:
                leftText = readfromAI4fix(text: leftText, AI: AI)
            case .ai4non:
                leftText = readfromAI4non(text: leftText, AI: AI)
            default:
                content_List.append(GS1_Code_Content(title: String(localized: "noMoreReadAIKey"), content: leftText))
            }
#if DEBUG
            print("# of iteration:\(counter)")
#endif
            if AIType == .other{
                if AICounter == 0{
                    isAIData = false
                }
                break
            }
        }while leftText.count > 0
    }

    
    private func readCodefromGS1_128(result data:[String])->String{
        var first_list:[String] = []
        var second_list:[String] = []
        var count:Int = 0
        let stringData = data.map({$0.description.lowercased()})
        repeat{
            if count == 0{
                first_list.append("")
                second_list.append(gs128_A_Code[stringData[count]]!)
            }else if count != 0, first_list.count == count {
                if first_list[count-1] == ""{
                    switch second_list[count-1]{
                    case "STARTA":
                        first_list.append("CODEA")
                        second_list.append(gs128_A_Code[stringData[count]]!)
                    case "STARTB":
                        first_list.append("CODEB")
                        second_list.append(gs128_B_Code[stringData[count]]!)
                    case "STARTC":
                        first_list.append("CODEC")
                        second_list.append(gs128_C_Code[stringData[count]]!)
                    default:
                        break
                    }
                }else if first_list[count-1] == "CODEA"{
                    if second_list[count-1] == "SHIFT"{
                        first_list.append("CODEB")
                        second_list.append(gs128_B_Code[stringData[count]]!)
                        first_list.append("CODEA")
                    }else if second_list[count-1] == "CODEB"{
                        first_list.append("CODEB")
                        second_list.append(gs128_B_Code[stringData[count]]!)
                    }else if second_list[count-1] == "CODEC"{
                        first_list.append("CODEC")
                        second_list.append(gs128_C_Code[stringData[count]]!)
                    }else{
                        first_list.append("CODEA")
                        second_list.append(gs128_A_Code[stringData[count]]!)
                    }
                }else if first_list[count-1] == "CODEB"{
                    if second_list[count-1] == "SHIFT"{
                        first_list.append("CODEC")
                        second_list.append(gs128_C_Code[stringData[count]]!)
                        first_list.append("CODEB")
                    }else if second_list[count-1] == "CODEA"{
                        first_list.append("CODEA")
                        second_list.append(gs128_A_Code[stringData[count]]!)
                    }else if second_list[count-1] == "CODEC"{
                        first_list.append("CODEC")
                        second_list.append(gs128_C_Code[stringData[count]]!)
                    }else{
                        first_list.append("CODEB")
                        second_list.append(gs128_B_Code[stringData[count]]!)
                    }
                }else if first_list[count-1] == "CODEC"{
                    if second_list[count-1] == "CODEA"{
                        first_list.append("CODEA")
                        second_list.append(gs128_A_Code[stringData[count]]!)
                    }else if second_list[count-1] == "CODEB"{
                        first_list.append("CODEB")
                        second_list.append(gs128_B_Code[stringData[count]]!)
                    }else {
                        first_list.append("CODEC")
                        second_list.append(gs128_C_Code[stringData[count]]!)
                    }
                }
            }else if count != 0, first_list.count == count + 1{
                if first_list[count] == "CODEA"{
                    second_list.append(gs128_A_Code[stringData[count]]!)
                }else if first_list[count] == "CODEB"{
                    second_list.append(gs128_B_Code[stringData[count]]!)
                }else {
                    second_list.append(gs128_C_Code[stringData[count]]!)
                }
            }
            count = count + 1
        }while count < stringData.count-2
        
        if second_list.count == 1{
            content_List.append(GS1_Code_Content(title: String(localized: "noMreReadGS1-128CodeKey"), content: stringData.joined()))
        }
        
        let readstring = second_list.map{$0 == "FNC1" ? "@" : $0}.map{$0 == "STARTA" ? "" : $0}.map{$0 == "STARTB" ? "" : $0}.map{$0 == "STARTC" ? "" : $0}.map{$0 == "CODEA" ? "" : $0}.map{$0 == "CODEB" ? "" : $0}.map{$0 == "CODEC" ? "" : $0}.map{$0 == "SHIFT" ? "" : $0}
        return readstring.joined()
    }

    private func readCodefromGS1_Data_Matrix(result data:[String])->String{
        var first_list:[String] = []
        var second_list:[String] = []
        var count:Int = 0
        let stringData = data.map({$0.description.lowercased()})
        var C40_decode_base_mat:[String: String] = [:]
        var C40_decode_shift2_mat:[String: String] = [:]
        var C40_decode_shift3_mat:[String: String] = [:]
        var Text_decode_base_mat:[String: String] = [:]
        var Text_decode_shift2_mat:[String: String] = [:]
        var Text_decode_shift3_mat:[String: String] = [:]
        var X12_decode_mat:[String: String] = [:]
        var base256_decode_mat:[String: String] = [:]
        var edifact_decode_mat:[String: String] = [:]
        
        for num in gs1_dataMatrix_40.indices{
            C40_decode_base_mat.updateValue(C40_decode_base[num], forKey : gs1_dataMatrix_40[num])
            C40_decode_shift2_mat.updateValue(C40_decode_shift2[num], forKey : gs1_dataMatrix_40[num])
            C40_decode_shift3_mat.updateValue(C40_decode_shift3[num], forKey : gs1_dataMatrix_40[num])
            Text_decode_base_mat.updateValue(Text_decode_base[num], forKey : gs1_dataMatrix_40[num])
            Text_decode_shift2_mat.updateValue(Text_decode_shift2[num], forKey : gs1_dataMatrix_40[num])
            Text_decode_shift3_mat.updateValue(C40_decode_shift3[num], forKey : gs1_dataMatrix_40[num])
            X12_decode_mat.updateValue(X12_decode[num], forKey : gs1_dataMatrix_40[num])
        }
        
        for num in gs1_dataMatrix_256.indices{
            base256_decode_mat.updateValue(gs1_dataMatrix_256[num], forKey : gs1_dataMatrix_256[num])
            edifact_decode_mat.updateValue(edifact_decode[num], forKey : gs1_dataMatrix_256[num])
        }
        
        repeat {
            if count == 0 {
                first_list.append("ASCII")
                second_list.append(gs1_dataMatrix_Ascii_Code[stringData[count]]!)
                count = count + 1
            }else{
                if count + 1 < stringData.count{
                    if stringData[count] != "fe"{
                        switch second_list.last {
                        case "C40":
                            let Cs = decalculator_40(first: stringData[count], second: stringData[count+1])
                            for _ in 1...3{
                                first_list.append("C40")
                            }
                            if Cs.0 == "Shift2"{
                                second_list.append("Shift2")
                            }else if Cs.0 == "Shift3"{
                                second_list.append("Shift3")
                            }else{
                                second_list.append(C40_decode_base_mat[Cs.0]!)
                            }
                            if Cs.1 == "Shift2"{
                                second_list.append("Shift2")
                            }else if Cs.1 == "Shift3"{
                                second_list.append("Shift3")
                            }else{
                                if second_list.last == "Shift2"{
                                    second_list.append(C40_decode_shift2_mat[Cs.1]!)
                                }else if second_list.last == "Shift3"{
                                    second_list.append(C40_decode_shift3_mat[Cs.1]!)
                                }else{
                                    second_list.append(C40_decode_base_mat[Cs.1]!)
                                }
                            }
                            if Cs.2 == "Shift2"{
                                second_list.append("Shift2")
                            }else if Cs.2 == "Shift3"{
                                second_list.append("Shift3")
                            }else{
                                if second_list.last == "Shift2"{
                                    second_list.append(C40_decode_shift2_mat[Cs.2]!)
                                }else if second_list.last == "Shift3"{
                                    second_list.append(C40_decode_shift3_mat[Cs.2]!)
                                }else{
                                    second_list.append(C40_decode_base_mat[Cs.2]!)
                                }
                            }
                            count = count + 2
                        case "TEXT":
                            let Cs = decalculator_40(first: stringData[count], second: stringData[count+1])
                            for _ in 1...3{
                                first_list.append("TEXT")
                            }
                            if Cs.0 == "Shift2"{
                                second_list.append("Shift2")
                            }else if Cs.0 == "Shift3"{
                                second_list.append("Shift3")
                            }else{
                                second_list.append(Text_decode_base_mat[Cs.0]!)
                            }
                            if Cs.1 == "Shift2"{
                                second_list.append("Shift2")
                            }else if Cs.1 == "Shift3"{
                                second_list.append("Shift3")
                            }else{
                                if second_list.last == "Shift2"{
                                    second_list.append(Text_decode_shift2_mat[Cs.1]!)
                                }else if second_list.last == "Shift3"{
                                    second_list.append(Text_decode_shift3_mat[Cs.1]!)
                                }else{
                                    second_list.append(Text_decode_base_mat[Cs.1]!)
                                }
                            }
                            if Cs.2 == "Shift2"{
                                second_list.append("Shift2")
                            }else if Cs.2 == "Shift3"{
                                second_list.append("Shift3")
                            }else{
                                if second_list.last == "Shift2"{
                                    second_list.append(Text_decode_shift2_mat[Cs.2]!)
                                }else if second_list.last == "Shift3"{
                                    second_list.append(Text_decode_shift3_mat[Cs.2]!)
                                }else{
                                    second_list.append(Text_decode_base_mat[Cs.2]!)
                                }
                            }
                            count = count + 2
                        case "X12":
                            let Cs = decalculator_40(first: stringData[count], second: stringData[count+1])
                            for _ in 1...3{
                                first_list.append("X12")
                            }
                            second_list.append(X12_decode_mat[Cs.0]!)
                            second_list.append(X12_decode_mat[Cs.1]!)
                            second_list.append(X12_decode_mat[Cs.2]!)
                            count = count + 2
                        case "BASE256":
                            if Int(stringData[count],radix:16)! == 0{
                                repeat{
                                    first_list.append("BASE256")
                                    second_list.append(base256_decode_mat[stringData[count+1]]!)
                                    count = count + 1
                                }while count - 1 < stringData.count
                                break
                            }else if 1 <= Int(stringData[count],radix:16)!, Int(stringData[count],radix:16)! <= 249{
                                for i in 1...Int(stringData[count],radix:16)! {
                                    first_list.append("BASE256")
                                    second_list.append(base256_decode_mat[stringData[count+i]]!)
                                }
                                count = count + Int(stringData[count],radix:16)!+1
                                first_list.append("ASCII")
                            }else if 250 <= Int(stringData[count],radix:16)!, Int(stringData[count],radix:16)! <= 255{
                                for i in 2...250*(Int(stringData[count],radix:16)! - 249) + Int(stringData[count+1],radix:16)!+1{
                                    first_list.append("BASE256")
                                    second_list.append(base256_decode_mat[stringData[count+i]]!)
                                }
                                count = count + 250*(Int(stringData[count],radix:16)! - 249) + Int(stringData[count+1],radix:16)!+2
                                first_list.append("ASCII")
                            }
                        case "EDIFACT":
                            let Cs = decalculator_EDIFACT(first: stringData[count], second: stringData[count+1], third: stringData[count+2])
                            for _ in 1...Cs.4{
                                first_list.append("EDIFACT")
                            }
                            second_list.append(edifact_decode_mat[Cs.0]!)
                            second_list.append(edifact_decode_mat[Cs.1]!)
                            second_list.append(edifact_decode_mat[Cs.2]!)
                            second_list.append(edifact_decode_mat[Cs.3]!)
                            if Cs.4 == 1 || Cs.4 == 2{
                                count = count + Cs.4
                            } else{
                                count = count + 3
                            }
                        case "ASCII":
                            first_list.append("ASCII")
                            second_list.append(gs1_dataMatrix_Ascii_Code[stringData[count]]!)
                            count = count + 1
                        case "Shift2":
                            let Cs = decalculator_40(first: stringData[count], second: stringData[count+1])
                            if first_list.last == "C40"{
                                for _ in 1...3{
                                    first_list.append("C40")
                                }
                                second_list.append(C40_decode_shift2_mat[Cs.0]!)
                                if Cs.1 == "Shift2"{
                                    second_list.append("Shift2")
                                }else if Cs.1 == "Shift3"{
                                    second_list.append("Shift3")
                                }else{
                                    second_list.append(C40_decode_base_mat[Cs.1]!)
                                }
                                if Cs.2 == "Shift2"{
                                    second_list.append("Shift2")
                                }else if Cs.2 == "Shift3"{
                                    second_list.append("Shift3")
                                }else{
                                    if second_list.last == "Shift2"{
                                        second_list.append(C40_decode_shift2_mat[Cs.2]!)
                                    }else if second_list.last == "Shift3"{
                                        second_list.append(C40_decode_shift3_mat[Cs.2]!)
                                    }else{
                                        second_list.append(C40_decode_base_mat[Cs.2]!)
                                    }
                                }
                            }else if first_list.last == "TEXT"{
                                for _ in 1...3{
                                    first_list.append("TEXT")
                                }
                                second_list.append(Text_decode_shift2_mat[Cs.0]!)
                                if Cs.1 == "Shift2"{
                                    second_list.append("Shift2")
                                }else if Cs.1 == "Shift3"{
                                    second_list.append("Shift3")
                                }else{
                                    second_list.append(Text_decode_base_mat[Cs.1]!)
                                }
                                if Cs.2 == "Shift2"{
                                    second_list.append("Shift2")
                                }else if Cs.2 == "Shift3"{
                                    second_list.append("Shift3")
                                }else{
                                    if second_list.last == "Shift2"{
                                        second_list.append(Text_decode_shift2_mat[Cs.2]!)
                                    }else if second_list.last == "Shift3"{
                                        second_list.append(Text_decode_shift3_mat[Cs.2]!)
                                    }else{
                                        second_list.append(Text_decode_base_mat[Cs.2]!)
                                    }
                                }
                            }
                            count = count + 2
                        case "Shift3":
                            let Cs = decalculator_40(first: stringData[count], second: stringData[count+1])
                            if first_list.last == "C40"{
                                for _ in 1...3{
                                    first_list.append("C40")
                                }
                                second_list.append(C40_decode_shift3_mat[Cs.0]!)
                                if Cs.1 == "Shift2"{
                                    second_list.append("Shift2")
                                }else if Cs.1 == "Shift3"{
                                    second_list.append("Shift3")
                                }else{
                                    second_list.append(C40_decode_base_mat[Cs.1]!)
                                }
                                if Cs.2 == "Shift2"{
                                    second_list.append("Shift2")
                                }else if Cs.2 == "Shift3"{
                                    second_list.append("Shift3")
                                }else{
                                    if second_list.last == "Shift2"{
                                        second_list.append(C40_decode_shift2_mat[Cs.2]!)
                                    }else if second_list.last == "Shift3"{
                                        second_list.append(C40_decode_shift3_mat[Cs.2]!)
                                    }else{
                                        second_list.append(C40_decode_base_mat[Cs.2]!)
                                    }
                                }
                                
                            }else if first_list.last == "TEXT"{
                                for _ in 1...3{
                                    first_list.append("TEXT")
                                }
                                second_list.append(Text_decode_shift3_mat[Cs.0]!)
                                if Cs.1 == "Shift2"{
                                    second_list.append("Shift2")
                                }else if Cs.1 == "Shift3"{
                                    second_list.append("Shift3")
                                }else{
                                    second_list.append(Text_decode_base_mat[Cs.1]!)
                                }
                                if Cs.2 == "Shift2"{
                                    second_list.append("Shift2")
                                }else if Cs.2 == "Shift3"{
                                    second_list.append("Shift3")
                                }else{
                                    if second_list.last == "Shift2"{
                                        second_list.append(Text_decode_shift2_mat[Cs.2]!)
                                    }else if second_list.last == "Shift3"{
                                        second_list.append(Text_decode_shift3_mat[Cs.2]!)
                                    }else{
                                        second_list.append(Text_decode_base_mat[Cs.2]!)
                                    }
                                }
                                
                            }
                            count = count + 2
                        default:
                            switch first_list.last {
                            case "C40":
                                let Cs = decalculator_40(first: stringData[count], second: stringData[count+1])
                                for _ in 1...3{
                                    first_list.append("C40")
                                }
                                if Cs.0 == "Shift2"{
                                    second_list.append("Shift2")
                                }else if Cs.0 == "Shift3"{
                                    second_list.append("Shift3")
                                }else{
                                    second_list.append(C40_decode_base_mat[Cs.0]!)
                                }
                                if Cs.1 == "Shift2"{
                                    second_list.append("Shift2")
                                }else if Cs.1 == "Shift3"{
                                    second_list.append("Shift3")
                                }else{
                                    if second_list.last == "Shift2"{
                                        second_list.append(C40_decode_shift2_mat[Cs.1]!)
                                    }else if second_list.last == "Shift3"{
                                        second_list.append(C40_decode_shift3_mat[Cs.1]!)
                                    }else{
                                        second_list.append(C40_decode_base_mat[Cs.1]!)
                                    }
                                }
                                if Cs.2 == "Shift2"{
                                    second_list.append("Shift2")
                                }else if Cs.2 == "Shift3"{
                                    second_list.append("Shift3")
                                }else{
                                    if second_list.last == "Shift2"{
                                        second_list.append(C40_decode_shift2_mat[Cs.2]!)
                                    }else if second_list.last == "Shift3"{
                                        second_list.append(C40_decode_shift3_mat[Cs.2]!)
                                    }else{
                                        second_list.append(C40_decode_base_mat[Cs.2]!)
                                    }
                                }
                                count = count + 2
                            case "TEXT":
                                let Cs = decalculator_40(first: stringData[count], second: stringData[count+1])
                                for _ in 1...3{
                                    first_list.append("TEXT")
                                }
                                if Cs.0 == "Shift2"{
                                    second_list.append("Shift2")
                                }else if Cs.0 == "Shift3"{
                                    second_list.append("Shift3")
                                }else{
                                    second_list.append(Text_decode_base_mat[Cs.0]!)
                                }
                                if Cs.1 == "Shift2"{
                                    second_list.append("Shift2")
                                }else if Cs.1 == "Shift3"{
                                    second_list.append("Shift3")
                                }else{
                                    if second_list.last == "Shift2"{
                                        second_list.append(Text_decode_shift2_mat[Cs.1]!)
                                    }else if second_list.last == "Shift3"{
                                        second_list.append(Text_decode_shift3_mat[Cs.1]!)
                                    }else{
                                        second_list.append(Text_decode_base_mat[Cs.1]!)
                                    }
                                }
                                if Cs.2 == "Shift2"{
                                    second_list.append("Shift2")
                                }else if Cs.2 == "Shift3"{
                                    second_list.append("Shift3")
                                }else{
                                    if second_list.last == "Shift2"{
                                        second_list.append(Text_decode_shift2_mat[Cs.2]!)
                                    }else if second_list.last == "Shift3"{
                                        second_list.append(Text_decode_shift3_mat[Cs.2]!)
                                    }else{
                                        second_list.append(Text_decode_base_mat[Cs.2]!)
                                    }
                                }
                                count = count + 2
                            case "X12":
                                let Cs = decalculator_40(first: stringData[count], second: stringData[count+1])
                                for _ in 1...3{
                                    first_list.append("X12")
                                }
                                second_list.append(X12_decode_mat[Cs.0]!)
                                second_list.append(X12_decode_mat[Cs.1]!)
                                second_list.append(X12_decode_mat[Cs.2]!)
                                count = count + 2
                            case "EDIFACT":
                                let Cs = decalculator_EDIFACT(first: stringData[count], second: stringData[count+1], third: stringData[count+2])
                                for _ in 1...Cs.4{
                                    first_list.append("EDIFACT")
                                }
                                second_list.append(edifact_decode_mat[Cs.0]!)
                                second_list.append(edifact_decode_mat[Cs.1]!)
                                second_list.append(edifact_decode_mat[Cs.2]!)
                                second_list.append(edifact_decode_mat[Cs.3]!)
                                if Cs.4 == 1 || Cs.4 == 2{
                                    count = count + Cs.4
                                } else{
                                    count = count + 3
                                }
                            default:/// really case is "ASCII"
                                first_list.append("ASCII")
                                second_list.append(gs1_dataMatrix_Ascii_Code[stringData[count]]!)
                                count = count + 1
                            }
                        }
                    }else if stringData[count] == "fe"{
                        first_list.append("")
                        second_list.append("ASCII")
                        count = count + 1
                    }
                } else if count + 1 == stringData.count{
                    first_list.append("ASCII")
                    second_list.append(gs1_dataMatrix_Ascii_Code[stringData[count]]!)
                    count = count + 1
                }
            }
        }while count < stringData.count
        
        if let idx = second_list.firstIndex(of: "$"){
            second_list.removeSubrange(idx..<second_list.endIndex)
        }

        let readstring = second_list.map{$0 == "FNC1" ? "@" : $0}.map{$0 == "Shift1" ? "" : $0}.map{$0 == "Shift2" ? "" : $0}.map{$0 == "Shift3" ? "" : $0}.map{$0 == "C40" ? "" : $0}.map{$0 == "ASCII" ? "" : $0}.map{$0 == "BASE256" ? "" : $0}.map{$0 == "EDIFACT" ? "" : $0}.map{$0 == "X12" ? "" : $0}.map{$0 == "TEXT" ? "" : $0}
        return readstring.joined()
    }
    
    private func decalculator_40(first upper:String, second lower:String)->(String,String,String) {
        let text_v = Int(upper + lower, radix: 16)!
        let C3:Int = (text_v-1)%40
        let C2:Int = ((text_v-1)/40)%40
        let C1:Int = ((text_v-1)/40)/40
        return (String(format:"%02x",C1),String(format:"%02x",C2),String(format:"%02x",C3))
    }
    
    private func decalculator_EDIFACT(first upper:String, second middle:String, third lower:String)->(String,String,String,String,Int) {
        let text_v = Int(upper+middle+lower, radix:16)!
        let text = String(text_v,radix:2)
        let firstIndex:String.Index = text.startIndex
        let secondIndex:String.Index = text.index(text.startIndex, offsetBy: 6)
        let thirdIndex:String.Index = text.index(text.startIndex, offsetBy: 12)
        let forthIndex:String.Index = text.index(text.startIndex, offsetBy: 18)
        var decode_num:Int = 0
        var C_M = [String]()
        C_M[0] = String(text[firstIndex..<secondIndex])
        C_M[1] = String(text[secondIndex..<thirdIndex])
        C_M[2] = String(text[thirdIndex..<forthIndex])
        C_M[3] = String(text[forthIndex..<text.endIndex])
        var C_R:[String] = ["","","",""]
        for num in C_M.indices {
            if C_M[num] == "011111" {
                C_R[num] = "5f"
                decode_num = num + 1
                break
            } else if  String(C_M[num][C_M[num].startIndex]) == "0" {
                C_R[num] = String(format:"%02x",Int("01" + C_M[num],radix:2)!)
            }else if String(C_M[num][C_M[num].startIndex]) == "1" {
                C_R[num] = String(format:"%02x",Int("00" + C_M[num],radix:2)!)
            }
        }
        return (C_R[0],C_R[1],C_R[2],C_R[3],decode_num)
    }
                      
    private func readfromAI2fix(text leftText:String, AI:String)->String{
        var rLength : Int = 0
        if leftText.count >= ai2fixlength[AI]! {//固定長より長い文字列か確認
            rLength = leftText.count - ai2fixlength[AI]!
            let tempResult = String(leftText.dropLast(rLength).dropFirst(AI.count))
            if AI == "01" || AI == "02" || AI == "03"{
                scanResult = tempResult
            }
            if AI == "00" || AI == "01" || AI == "02" || AI == "03" || AI == "20"{
                content_List.append(GS1_Code_Content(title: String(localized: aiCode[AI]!), content: tempResult))
            }else if AI == "11" || AI == "12" || AI == "13" || AI == "15" || AI == "16" || AI == "17"{
                let date : String = tempResult
                let idxys : String.Index = date.startIndex
                let idxye : String.Index = date.index(after:idxys)
                let idxms : String.Index = date.index(after:idxye)
                let idxme : String.Index = date.index(after:idxms)
                let idxds : String.Index = date.index(after:idxme)
                let idxde : String.Index = date.index(after: idxds)
                if String(date[idxds...idxde]) == "00"{
                    let showdate : String = "20" + String(date[idxys...idxye]) + "-" + String(date[idxms...idxme]) + "-" + String(localized:"endOfMonth")
                    content_List.append(GS1_Code_Content(title: String(localized: aiCode[AI]!), content: showdate))
                } else {
                    let showdate : String = "20" + String(date[idxys...idxye]) + "-" + String(date[idxms...idxme]) + "-" + String(date[idxds...idxde])
                    content_List.append(GS1_Code_Content(title: String(localized: aiCode[AI]!), content: showdate))
                }
            }
        }else{
        }
        return String(leftText.dropFirst(ai2fixlength[AI]!))
    }
    
    private func readfromAI2non(text leftText:String, AI:String)->String{
        var rLength : Int = 0
        repeat{
            if rLength == leftText.count{
                break
            }
            if leftText[leftText.index(leftText.startIndex, offsetBy: rLength)] == "@"{
                break
            }
            rLength = rLength + 1
        }while leftText.count > 0
        if rLength <= ai2maxlength[AI]! {
            let tempResult = String(leftText.dropLast(leftText.count - rLength).dropFirst(AI.count))
            content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:tempResult))
        }else {
        }
        return String(leftText.dropFirst(rLength+1))
    }
    
    private func readfromAI3fix(text leftText:String, AI:String)->String{
        var rLength : Int = 0
        if leftText.count >= ai3fixlength[AI]! {
            rLength = leftText.count - ai3fixlength[AI]!
            let tempResult = String(leftText.dropLast(rLength).dropFirst(AI.count))
            if AI == "410" || AI == "411" || AI == "412" || AI == "413" || AI == "414" || AI == "415" || AI == "416" || AI == "417"{
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:tempResult))
                rLength = ai3fixlength[AI]!
            }else if AI == "402" || AI == "422" || AI == "424" || AI == "426"{
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:tempResult))
                rLength = ai3fixlength[AI]!+1
            }
        }else{
        }
        return String(leftText.dropFirst(rLength))
    }
    
    private func readfromAI3non(text leftText:String, AI:String)->String{
        var rLength : Int = 0
        repeat{
            if rLength == leftText.count{
                break
            }
            if leftText[leftText.index(leftText.startIndex, offsetBy: rLength)] == "@"{
                break
            }
            rLength = rLength + 1
        }while leftText.count > 0
        if rLength <= ai3maxlength[AI]! {//制限より短いか確認すること
            let tempResult = String(leftText.dropLast(leftText.count - rLength).dropFirst(AI.count))
            if AI == "235" || AI == "240" || AI == "241" || AI == "242" || AI == "243" || AI == "250" || AI == "251" || AI == "254" || AI == "400" || AI == "401" || AI == "403" || AI == "420" || AI == "710" || AI == "711" || AI == "712" || AI == "713" || AI == "714" || AI == "715" || AI == "716"{
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:tempResult))
            }else if AI == "253" || AI == "255" {///
                let tempcode = String(tempResult.dropLast(tempResult.count - 13))
                let tempserial = String(tempResult.dropFirst(13))
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:"\(tempcode):\(tempserial)"))
            }else if AI == "421"{///
                let tempcountrycode = String(tempResult.dropLast(tempResult.count - 3))
                let tempunique = String(tempResult.dropFirst(3))
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:"\(tempcountrycode):\(tempunique)"))
            }else if AI == "423" || AI == "425"{///
                var tempcountrycodes = ""
                var former = ""
                var latter = tempResult
                repeat{
                    former = String(latter.dropLast(tempResult.count - 3))
                    latter = String(latter.dropFirst(3))
                    if latter.count > 0{
                        tempcountrycodes.append("\(former):")
                    }else{
                        tempcountrycodes.append("\(former)")
                    }
                }while latter.count > 0
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:tempcountrycodes))
            }else if AI == "427"{
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:tempResult))
            }
        } else {
        }
        return String(leftText.dropFirst(rLength+1))
    }
    
    private func readfromAI4fix(text leftText:String, AI:String)->String{///未実装
        var rLength : Int = 0
        if leftText.count >= ai4fixlength[AI]! {//文字列が固定長より長いか確認
            rLength = leftText.count - ai4fixlength[AI]!
            let tempResult = String(leftText.dropLast(rLength).dropFirst(AI.count))

            if AI == "3100" || AI == "3110" || AI == "3120" || AI == "3130" || AI == "3140" || AI == "3150" || AI == "3160" || AI == "3200" || AI == "3210" || AI == "3220" || AI == "3230" || AI == "3240" || AI == "3250" || AI == "3260" || AI == "3270" || AI == "3280" || AI == "3290" || AI == "3370" || AI == "3500" || AI == "3510" || AI == "3520" || AI == "3560" || AI == "3570" || AI == "3600" || AI == "3610" || AI == "3640" || AI == "3650" || AI == "3660" || AI == "3300" || AI == "3310" || AI == "3320" || AI == "3330" || AI == "3340" || AI == "3350" || AI == "3360" || AI == "3400" || AI == "3410" || AI == "3420" || AI == "3430" || AI == "3440" || AI == "3450" || AI == "3460" || AI == "3470" || AI == "3480" || AI == "3490" || AI == "3530" || AI == "3540" || AI == "3550" || AI == "3620" || AI == "3630" || AI == "3670" || AI == "3680" || AI == "3690"{
                let result = String(Int(tempResult)!)
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result))
                rLength = ai4fixlength[AI]!
            }else if AI == "3101" || AI == "3111" || AI == "3121" || AI == "3131" || AI == "3141" || AI == "3151" || AI == "3161" || AI == "3201" || AI == "3211" || AI == "3221" || AI == "3231" || AI == "3241" || AI == "3251" || AI == "3261" || AI == "3271" || AI == "3281" || AI == "3291" || AI == "3371" || AI == "3501" || AI == "3511" || AI == "3521" || AI == "3561" || AI == "3571" || AI == "3601" || AI == "3611" || AI == "3641" || AI == "3651" || AI == "3661" || AI == "3301" || AI == "3311" || AI == "3321" || AI == "3331" || AI == "3341" || AI == "3351" || AI == "3361" || AI == "3401" || AI == "3411" || AI == "3421" || AI == "3431" || AI == "3441" || AI == "3451" || AI == "3461" || AI == "3471" || AI == "3481" || AI == "3491" || AI == "3531" || AI == "3541" || AI == "3551" || AI == "3621" || AI == "3631" || AI == "3671" || AI == "3681" || AI == "3691"{
                let former = String(tempResult.dropLast(1))
                let latter = String(tempResult.dropFirst(tempResult.count - 1))
                let result = String(Int(former)!) + "." + latter
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result))
                rLength = ai4fixlength[AI]!
            }else if AI == "3102" || AI == "3112" || AI == "3122" || AI == "3132" || AI == "3142" || AI == "3152" || AI == "3162" || AI == "3202" || AI == "3212" || AI == "3222" || AI == "3232" || AI == "3242" || AI == "3252" || AI == "3262" || AI == "3272" || AI == "3282" || AI == "3292" || AI == "3372" || AI == "3502" || AI == "3512" || AI == "3522" || AI == "3562" || AI == "3572" || AI == "3602" || AI == "3612" || AI == "3642" || AI == "3652" || AI == "3662" || AI == "3302" || AI == "3312" || AI == "3322" || AI == "3332" || AI == "3342" || AI == "3352" || AI == "3360" || AI == "3402" || AI == "3412" || AI == "3422" || AI == "3432" || AI == "3442" || AI == "3452" || AI == "3462" || AI == "3472" || AI == "3482" || AI == "3492" || AI == "3532" || AI == "3542" || AI == "3552" || AI == "3622" || AI == "3632" || AI == "3672" || AI == "3682" || AI == "3692"{
                let former = String(tempResult.dropLast(2))
                let latter = String(tempResult.dropFirst(tempResult.count - 2))
                let result = String(Int(former)!) + "." + latter
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result))
                rLength = ai4fixlength[AI]!
            }else if AI == "3103" || AI == "3113" || AI == "3123" || AI == "3133" || AI == "3143" || AI == "3153" || AI == "3163" || AI == "3203" || AI == "3213" || AI == "3223" || AI == "3233" || AI == "3243" || AI == "3253" || AI == "3263" || AI == "3273" || AI == "3283" || AI == "3293" || AI == "3373" || AI == "3503" || AI == "3513" || AI == "3523" || AI == "3563" || AI == "3573" || AI == "3603" || AI == "3613" || AI == "3643" || AI == "3653" || AI == "3663" || AI == "3303" || AI == "3313" || AI == "3323" || AI == "3333" || AI == "3343" || AI == "3353" || AI == "3363" || AI == "3403" || AI == "3413" || AI == "3423" || AI == "3433" || AI == "3443" || AI == "3453" || AI == "3463" || AI == "3473" || AI == "3483" || AI == "3493" || AI == "3533" || AI == "3543" || AI == "3553" || AI == "3623" || AI == "3633" || AI == "3673" || AI == "3683" || AI == "3693"{
                let former = String(tempResult.dropLast(3))
                let latter = String(tempResult.dropFirst(tempResult.count - 3))
                let result = String(Int(former)!) + "." + latter
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result))
                rLength = ai4fixlength[AI]!
            }else if AI == "3104" || AI == "3114" || AI == "3124" || AI == "3134" || AI == "3144" || AI == "3154" || AI == "3164" || AI == "3204" || AI == "3214" || AI == "3224" || AI == "3234" || AI == "3244" || AI == "3254" || AI == "3264" || AI == "3274" || AI == "3284" || AI == "3294" || AI == "3374" || AI == "3504" || AI == "3514" || AI == "3524" || AI == "3564" || AI == "3574" || AI == "3604" || AI == "3614" || AI == "3644" || AI == "3654" || AI == "3664" || AI == "3304" || AI == "3314" || AI == "3324" || AI == "3334" || AI == "3344" || AI == "3354" || AI == "3364" || AI == "3404" || AI == "3414" || AI == "3424" || AI == "3434" || AI == "3444" || AI == "3454" || AI == "3464" || AI == "3474" || AI == "3484" || AI == "3494" || AI == "3534" || AI == "3544" || AI == "3554" || AI == "3624" || AI == "3634" || AI == "3674" || AI == "3684" || AI == "3694"{
                let former = String(tempResult.dropLast(4))
                let latter = String(tempResult.dropFirst(tempResult.count - 4))
                let result = String(Int(former)!) + "." + latter
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result))
                rLength = ai4fixlength[AI]!
            }else if AI == "3105" || AI == "3115" || AI == "3125" || AI == "3135" || AI == "3145" || AI == "3155" || AI == "3165" || AI == "3205" || AI == "3215" || AI == "3225" || AI == "3235" || AI == "3245" || AI == "3255" || AI == "3265" || AI == "3275" || AI == "3285" || AI == "3295" || AI == "3375" || AI == "3505" || AI == "3515" || AI == "3525" || AI == "3565" || AI == "3575" || AI == "3605" || AI == "3615" || AI == "3645" || AI == "3655" || AI == "3665" || AI == "3305" || AI == "3315" || AI == "3325" || AI == "3335" || AI == "3345" || AI == "3355" || AI == "3365" || AI == "3405" || AI == "3415" || AI == "3425" || AI == "3435" || AI == "3445" || AI == "3455" || AI == "3465" || AI == "3475" || AI == "3485" || AI == "3495" || AI == "3535" || AI == "3545" || AI == "3555" || AI == "3625" || AI == "3635" || AI == "3675" || AI == "3685" || AI == "3695"{
                let former = String(tempResult.dropLast(5))
                let latter = String(tempResult.dropFirst(tempResult.count - 5))
                let result = String(Int(former)!) + "." + latter
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result))
                rLength = ai4fixlength[AI]!
            }else if AI == "3106" || AI == "3116" || AI == "3126" || AI == "3136" || AI == "3146" || AI == "3156" || AI == "3166" || AI == "3206" || AI == "3216" || AI == "3226" || AI == "3236" || AI == "3246" || AI == "3256" || AI == "3266" || AI == "3276" || AI == "3286" || AI == "3296" || AI == "3376" || AI == "3506" || AI == "3516" || AI == "3526" || AI == "3566" || AI == "3576" || AI == "3606" || AI == "3616" || AI == "3646" || AI == "3656" || AI == "3666" || AI == "3306" || AI == "3316" || AI == "3326" || AI == "3336" || AI == "3346" || AI == "3356" || AI == "3366" || AI == "3406" || AI == "3416" || AI == "3426" || AI == "3436" || AI == "3446" || AI == "3456" || AI == "3466" || AI == "3476" || AI == "3486" || AI == "3496" || AI == "3536" || AI == "3546" || AI == "3556" || AI == "3626" || AI == "3636" || AI == "3676" || AI == "3686" || AI == "3696"{
                let former = String(tempResult.dropLast(6))
                let latter = String(tempResult.dropFirst(tempResult.count - 6))
                let result = String(Int(former)!) + "." + latter
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result))
                rLength = ai4fixlength[AI]!
            }else if AI == "3940"{///
                let result = String(Int(tempResult)!)
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result))
                rLength = ai4fixlength[AI]!+1
            }else if AI == "3941"{///
                let former = String(tempResult.dropLast(1))
                let latter = String(tempResult.dropFirst(tempResult.count - 1))
                let result = String(Int(former)!) + "." + latter
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result))
                rLength = ai4fixlength[AI]!+1
            }else if AI == "3942"{///
                let former = String(tempResult.dropLast(2))
                let latter = String(tempResult.dropFirst(tempResult.count - 2))
                let result = String(Int(former)!) + "." + latter
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result))
                rLength = ai4fixlength[AI]!+1
            }else if AI == "3943"{///
                let former = String(tempResult.dropLast(3))
                let latter = String(tempResult.dropFirst(tempResult.count - 3))
                let result = String(Int(former)!) + "." + latter
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result))
                rLength = ai4fixlength[AI]!+1
            }else if AI == "3944"{///
                let former = String(tempResult.dropLast(4))
                let latter = String(tempResult.dropFirst(tempResult.count - 4))
                let result = String(Int(former)!) + "." + latter
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result))
                rLength = ai4fixlength[AI]!+1
            }else if AI == "3950"{///
                let result = String(Int(tempResult)!)
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result))
                rLength = ai4fixlength[AI]!+1
            }else if AI == "3951"{///
                let former = String(tempResult.dropLast(1))
                let latter = String(tempResult.dropFirst(tempResult.count - 1))
                let result = String(Int(former)!) + "." + latter
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result))
                rLength = ai4fixlength[AI]!+1
            }else if AI == "3952"{///
                let former = String(tempResult.dropLast(2))
                let latter = String(tempResult.dropFirst(tempResult.count - 2))
                let result = String(Int(former)!) + "." + latter
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result))
                rLength = ai4fixlength[AI]!+1
            }else if AI == "3953"{///
                let former = String(tempResult.dropLast(3))
                let latter = String(tempResult.dropFirst(tempResult.count - 3))
                let result = String(Int(former)!) + "." + latter
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result))
                rLength = ai4fixlength[AI]!+1
            }else if AI == "3954"{///
                let former = String(tempResult.dropLast(4))
                let latter = String(tempResult.dropFirst(tempResult.count - 4))
                let result = String(Int(former)!) + "." + latter
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result))
                rLength = ai4fixlength[AI]!+1
            }else if AI == "3955"{///
                let former = String(tempResult.dropLast(5))
                let latter = String(tempResult.dropFirst(tempResult.count - 5))
                let result = String(Int(former)!) + "." + latter
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result))
                rLength = ai4fixlength[AI]!+1
            }else if AI == "3956"{///
                let former = String(tempResult.dropLast(6))
                let latter = String(tempResult.dropFirst(tempResult.count - 6))
                let result = String(Int(former)!) + "." + latter
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result))
                rLength = ai4fixlength[AI]!+1
            }else if AI == "4307" || AI == "4317"{///
                let former = String(tempResult.dropLast(1))
                let latter = String(tempResult.dropFirst(tempResult.count - 1))
                let result = String(Int(former)!) + "." + latter
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result))
                rLength = ai4fixlength[AI]!+1
            }else if AI == "4309"{
                var wgs84lat:Double
                var wgs84lon:Double
                wgs84lat = Double(tempResult.dropLast(tempResult.count - 10))! / 10000000 - 90
                wgs84lon = (Double(tempResult.dropFirst(10))! + 180).truncatingRemainder(dividingBy: 360) - 180
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:"\(wgs84lat),\(wgs84lon)"))
                rLength = ai4fixlength[AI]!+1
            }else if AI == "4321"{///
                if tempResult == "0"{
                    content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:String(localized: "noDanger")))
                } else if tempResult == "1"{
                    content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:String(localized: "danger")))
                }
                rLength = ai4fixlength[AI]!+1
            }else if AI == "4322"{///
                if tempResult == "0"{
                    content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:String(localized: "noContactlessDelivery")))
                } else if tempResult == "1"{
                    content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:String(localized: "contactlessDeliveryOK")))
                }
                rLength = ai4fixlength[AI]!+1
            }else if AI == "4323"{///
                if tempResult == "0"{
                    content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:String(localized: "noSign")))
                } else if tempResult == "1"{
                    content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:String(localized: "neccesarySign")))
                }
                rLength = ai4fixlength[AI]!+1
            }else if AI == "4324" || AI == "4325"{///
                let date : String = tempResult
                let idxys : String.Index = date.startIndex
                let idxye : String.Index = date.index(after:idxys)
                let idxms : String.Index = date.index(after:idxye)
                let idxme : String.Index = date.index(after:idxms)
                let idxds : String.Index = date.index(after:idxme)
                let idxde : String.Index = date.index(after:idxds)
                let idxhs : String.Index = date.index(after:idxde)
                let idxhe : String.Index = date.index(after:idxhs)
                let idxmins : String.Index = date.index(after:idxhe)
                let idxmine : String.Index = date.index(after:idxmins)
                if String(date[idxmins...idxmine]) == "99"{
                    if String(date[idxhs...idxhe]) == "99"{
                        if String(date[idxds...idxde]) == "00"{
                            let showdate : String = "20" + String(date[idxys...idxye]) + "-" + String(date[idxms...idxme]) + "-" + String(localized: "endOfMonth")
                            content_List.append(GS1_Code_Content(title: String(localized: aiCode[AI]!), content: showdate))
                        } else {
                            let showdate : String = "20" + String(date[idxys...idxye]) + "-" + String(date[idxms...idxme]) + "-" + String(date[idxds...idxde])
                            content_List.append(GS1_Code_Content(title: String(localized: aiCode[AI]!), content: showdate))
                        }
                    }else{
                        if String(date[idxds...idxde]) == "00"{
                            let showdate : String = "20" + String(date[idxys...idxye]) + "-" + String(date[idxms...idxme]) + "-" + String(localized: "endOfMonth") + "-" + String(date[idxhs...idxhe])
                            content_List.append(GS1_Code_Content(title: String(localized: aiCode[AI]!), content: showdate))
                        } else {
                            let showdate : String = "20" + String(date[idxys...idxye]) + "-" + String(date[idxms...idxme]) + "-" + String(date[idxds...idxde]) + "-" + String(date[idxhs...idxhe])
                            content_List.append(GS1_Code_Content(title: String(localized: aiCode[AI]!), content: showdate))
                        }
                    }
                }else{
                    if String(date[idxds...idxde]) == "00"{
                        let showdate : String = "20" + String(date[idxys...idxye]) + "-" + String(date[idxms...idxme]) + "-" + String(localized: "endOfMonth") + "-" + String(date[idxhs...idxhe]) + ":" + String(date[idxmins...idxmine])
                        content_List.append(GS1_Code_Content(title: String(localized: aiCode[AI]!), content: showdate))
                    } else {
                        let showdate : String = "20" + String(date[idxys...idxye]) + "-" + String(date[idxms...idxme]) + "-" + String(date[idxds...idxde]) + "-" + String(date[idxhs...idxhe]) + ":" + String(date[idxmins...idxmine])
                        content_List.append(GS1_Code_Content(title: String(localized: aiCode[AI]!), content: showdate))
                    }
                }
                rLength = ai4fixlength[AI]!+1
            }else if AI == "4326" || AI == "7006"{///
                let date : String = tempResult
                let idxys : String.Index = date.startIndex
                let idxye : String.Index = date.index(after:idxys)
                let idxms : String.Index = date.index(after:idxye)
                let idxme : String.Index = date.index(after:idxms)
                let idxds : String.Index = date.index(after:idxme)
                let idxde : String.Index = date.index(after:idxds)
                let showdate : String = "20" + String(date[idxys...idxye]) + "-" + String(date[idxms...idxme]) + "-" + String(date[idxds...idxde])
                content_List.append(GS1_Code_Content(title: String(localized: aiCode[AI]!), content: showdate))
                rLength = ai4fixlength[AI]!+1
            }else if AI == "7001"{///n13
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:tempResult))
                rLength = ai4fixlength[AI]!+1
            }else if AI == "7003"{///
                let date : String = tempResult
                let idxys : String.Index = date.startIndex
                let idxye : String.Index = date.index(after:idxys)
                let idxms : String.Index = date.index(after:idxye)
                let idxme : String.Index = date.index(after:idxms)
                let idxds : String.Index = date.index(after:idxme)
                let idxde : String.Index = date.index(after:idxds)
                let idxhs : String.Index = date.index(after:idxds)
                let idxhe : String.Index = date.index(after:idxhs)
                let idxmins : String.Index = date.index(after:idxhe)
                let idxmine : String.Index = date.index(after:idxmins)
                let showdate : String = "20" + String(date[idxys...idxye]) + "-" + String(date[idxms...idxme]) + "-" + String(date[idxds...idxde]) + "-" + String(date[idxhs...idxhe]) + ":" + String(date[idxmins...idxmine])
                content_List.append(GS1_Code_Content(title: String(localized: aiCode[AI]!), content: showdate))
                rLength = ai4fixlength[AI]!+1
            }else if AI == "7040"{///
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:tempResult))
                rLength = ai4fixlength[AI]!+1
            }else if AI == "7241"{///
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:tempResult))
                rLength = ai4fixlength[AI]!+1
            }else if AI == "7250"{///
                let date : String = tempResult
                let idxys : String.Index = date.startIndex
                let idxye : String.Index = date.index(idxys, offsetBy: 3)
                let idxms : String.Index = date.index(after:idxye)
                let idxme : String.Index = date.index(after:idxms)
                let idxds : String.Index = date.index(after:idxme)
                let idxde : String.Index = date.index(after:idxds)
                let showdate : String = String(date[idxys...idxye]) + "-" + String(date[idxms...idxme]) + "-" + String(date[idxds...idxde])
                content_List.append(GS1_Code_Content(title: String(localized: aiCode[AI]!), content: showdate))
                rLength = ai4fixlength[AI]!+1
            }else if AI == "7251"{///
                let date : String = tempResult
                let idxys : String.Index = date.startIndex
                let idxye : String.Index = date.index(idxys, offsetBy: 3)
                let idxms : String.Index = date.index(after:idxye)
                let idxme : String.Index = date.index(after:idxms)
                let idxds : String.Index = date.index(after:idxme)
                let idxde : String.Index = date.index(after:idxds)
                let idxhs : String.Index = date.index(after:idxde)
                let idxhe : String.Index = date.index(after:idxhs)
                let idxmins : String.Index = date.index(after:idxhe)
                let idxmine : String.Index = date.index(after:idxmins)
                let showdate : String = String(date[idxys...idxye]) + "-" + String(date[idxms...idxme]) + "-" + String(date[idxds...idxde]) + "-" + String(date[idxhs...idxhe]) + ":" + String(date[idxmins...idxmine])
                content_List.append(GS1_Code_Content(title: String(localized: aiCode[AI]!), content: showdate))
                rLength = ai4fixlength[AI]!+1
            }else if AI == "7252"{///
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:tempResult))
                rLength = ai4fixlength[AI]!+1
            }else if AI == "7258"{///
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:tempResult))
                rLength = ai4fixlength[AI]!+1
            }else if AI == "8001"{///
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:tempResult))
                rLength = ai4fixlength[AI]!+1
            }else if AI == "8005"{
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:tempResult))
                rLength = ai4fixlength[AI]!+1
            }else if AI == "8006"{///
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:tempResult))
                rLength = ai4fixlength[AI]!+1
            }else if AI == "8017" || AI == "8018"{///
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:tempResult))
                rLength = ai4fixlength[AI]!+1
            }else if AI == "8026"{///
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:tempResult))
                rLength = ai4fixlength[AI]!+1
            }else if AI == "8111"{
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:tempResult))
                rLength = ai4fixlength[AI]!+1
            }
        }else {
            
        }
        return String(leftText.dropFirst(rLength))
    }
    
    private func readfromAI4non(text leftText:String, AI:String)->String{
        var rLength : Int = 0
        repeat{
            if rLength == leftText.count{
                break
            }
            if leftText[leftText.index(leftText.startIndex, offsetBy: rLength)] == "@"{
                break
            }
            rLength = rLength + 1
        }while leftText.count > 0

        if rLength <= ai4maxlength[AI]! {
            let tempResult = String(leftText.dropLast(leftText.count - rLength).dropFirst(AI.count))
            if AI == "3900" || AI == "3920"{
                let result:String = String(Int(tempResult)!)
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result))
            }else if AI == "3901" || AI == "3921"{
                let former = String(tempResult.dropLast(1))
                let latter = String(tempResult.dropFirst(tempResult.count - 1))
                let result = String(Int(former)!) + "." + latter
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result))
            }else if AI == "3902" || AI == "3922"{
                let former = String(tempResult.dropLast(2))
                let latter = String(tempResult.dropFirst(tempResult.count - 2))
                let result = String(Int(former)!) + "." + latter
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result))
            }else if AI == "3903" || AI == "3923"{
                let former = String(tempResult.dropLast(3))
                let latter = String(tempResult.dropFirst(tempResult.count - 3))
                let result = String(Int(former)!) + "." + latter
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result))
            }else if AI == "3904" || AI == "3924"{
                let former = String(tempResult.dropLast(4))
                let latter = String(tempResult.dropFirst(tempResult.count - 4))
                let result = String(Int(former)!) + "." + latter
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result))
            }else if AI == "3905" || AI == "3925"{
                let former = String(tempResult.dropLast(5))
                let latter = String(tempResult.dropFirst(tempResult.count - 5))
                let result = String(Int(former)!) + "." + latter
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result))
            }else if AI == "3906" || AI == "3926"{
                let former = String(tempResult.dropLast(6))
                let latter = String(tempResult.dropFirst(tempResult.count - 6))
                let result = String(Int(former)!) + "." + latter
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result))
            }else if AI == "3907" || AI == "3927"{
                let former = String(tempResult.dropLast(7))
                let latter = String(tempResult.dropFirst(tempResult.count - 7))
                let result = String(Int(former)!) + "." + latter
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result))
            }else if AI == "3908" || AI == "3928"{
                let former = String(tempResult.dropLast(8))
                let latter = String(tempResult.dropFirst(tempResult.count - 8))
                let result = String(Int(former)!) + "." + latter
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result))
            }else if AI == "3909" || AI == "3929"{
                let former = String(tempResult.dropLast(9))
                let latter = String(tempResult.dropFirst(tempResult.count - 9))
                let result = String(Int(former)!) + "." + latter
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result))
            }else if AI == "3910" || AI == "3930"{
                let fCode = String(tempResult.dropLast(tempResult.count - 3))
                let temp = String(Int(tempResult.dropFirst(3))!)
                let result = String(localized:"FinantialCodeKey") + fCode + ":" + temp
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result))
            }else if AI == "3911" || AI == "3931"{
                let fCode = String(tempResult.dropLast(tempResult.count - 3))
                let former = String(tempResult.dropLast(1))
                let latter = String(tempResult.dropFirst(tempResult.count - 1 - 3))
                let result = String(localized:"FinantialCodeKey") + fCode + ":" + String(Int(former)!) + "." + latter
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result))
            }else if AI == "3912" || AI == "3932"{
                let fCode = String(tempResult.dropLast(tempResult.count - 3))
                let former = String(tempResult.dropLast(2))
                let latter = String(tempResult.dropFirst(tempResult.count - 2 - 3))
                let result = String(localized:"FinantialCodeKey") + fCode + ":" + String(Int(former)!) + "." + latter
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result))
            }else if AI == "3913" || AI == "3933"{
                let fCode = String(tempResult.dropLast(tempResult.count - 3))
                let former = String(tempResult.dropLast(3))
                let latter = String(tempResult.dropFirst(tempResult.count - 3 - 3))
                let result = String(localized:"FinantialCodeKey") + fCode + ":" + String(Int(former)!) + "." + latter
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result))
            }else if AI == "3914" || AI == "3934"{
                let fCode = String(tempResult.dropLast(tempResult.count - 3))
                let former = String(tempResult.dropLast(4))
                let latter = String(tempResult.dropFirst(tempResult.count - 4 - 3))
                let result = String(localized:"FinantialCodeKey") + fCode + ":" + String(Int(former)!) + "." + latter
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result))
            }else if AI == "3915" || AI == "3935"{
                let fCode = String(tempResult.dropLast(tempResult.count - 3))
                let former = String(tempResult.dropLast(5))
                let latter = String(tempResult.dropFirst(tempResult.count - 5 - 3))
                let result = String(localized:"FinantialCodeKey") + fCode + ":" + String(Int(former)!) + "." + latter
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result))
            }else if AI == "3916" || AI == "3936"{
                let fCode = String(tempResult.dropLast(tempResult.count - 3))
                let former = String(tempResult.dropLast(6))
                let latter = String(tempResult.dropFirst(tempResult.count - 6 - 3))
                let result = String(localized:"FinantialCodeKey") + fCode + ":" + String(Int(former)!) + "." + latter
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result))
            }else if AI == "3917" || AI == "3937"{
                let fCode = String(tempResult.dropLast(tempResult.count - 3))
                let former = String(tempResult.dropLast(7))
                let latter = String(tempResult.dropFirst(tempResult.count - 7 - 3))
                let result = String(localized:"FinantialCodeKey") + fCode + ":" + String(Int(former)!) + "." + latter
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result))
            }else if AI == "3918" || AI == "3938"{
                let fCode = String(tempResult.dropLast(tempResult.count - 3))
                let former = String(tempResult.dropLast(8))
                let latter = String(tempResult.dropFirst(tempResult.count - 8 - 3))
                let result = String(localized:"FinantialCodeKey") + fCode + ":" + String(Int(former)!) + "." + latter
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result))
            }else if AI == "3919" || AI == "3939"{
                let fCode = String(tempResult.dropLast(tempResult.count - 3))
                let former = String(tempResult.dropLast(9))
                let latter = String(tempResult.dropFirst(tempResult.count - 9 - 3))
                let result = String(localized:"FinantialCodeKey") + fCode + ":" + String(Int(former)!) + "." + latter
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result))
            }else if AI == "4300" || AI == "4301" || AI == "4302" || AI == "4303" || AI == "4304" || AI == "4305" || AI == "4306" || AI == "4308" || AI == "4310" || AI == "4311" || AI == "4312" || AI == "4313" || AI == "4314" || AI == "4315" || AI == "4316" || AI == "4318" || AI == "4319" || AI == "4320"{
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:tempResult))
            }else if AI == "4330" || AI == "4331" || AI == "4332" || AI == "4333"{
                var result:String = ""
                if tempResult.count == 7{///
                    let minus = String(tempResult.dropFirst(6))
                    let former = String(Int(tempResult.dropLast(3))!)
                    let latter = String(tempResult.dropFirst(tempResult.count - 3).dropLast(1))
                    result = minus + former + "." + latter
                }else if tempResult.count == 6{///
                    let former = String(Int(tempResult.dropLast(2))!)
                    let latter = String(tempResult.dropFirst(tempResult.count - 2))
                    result = former + "." + latter
                }
                if AI == "4330" || AI == "4332"{
                    content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result + "℉"))

                }else if AI == "4331" || AI == "4333"{
                    content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result + "℃"))
                }
            }else if AI == "7002" || AI == "7004" || AI == "7005" || AI == "7008" || AI == "7009" {
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:tempResult))
            }else if AI == "7007"{///
                if tempResult.count == 6{///
                    let date : String = tempResult
                    let idxys : String.Index = date.startIndex
                    let idxye : String.Index = date.index(after:idxys)
                    let idxms : String.Index = date.index(after:idxye)
                    let idxme : String.Index = date.index(after:idxms)
                    let idxds : String.Index = date.index(after:idxme)
                    let idxde : String.Index = date.index(after:idxds)
                    let showdate : String = "20" + String(date[idxys...idxye]) + "-" + String(date[idxms...idxme]) + "-" + String(date[idxds...idxde])
                    content_List.append(GS1_Code_Content(title: String(localized: aiCode[AI]!), content: showdate + String(localized:"periodOneDay")))
                }else if tempResult.count == 12{///
                    let date : String = tempResult
                    let idxys : String.Index = date.startIndex
                    let idxye : String.Index = date.index(after:idxys)
                    let idxms : String.Index = date.index(after:idxye)
                    let idxme : String.Index = date.index(after:idxms)
                    let idxds : String.Index = date.index(after:idxme)
                    let idxde : String.Index = date.index(after:idxds)
                    let idxyes : String.Index = date.index(after:idxde)
                    let idxyee : String.Index = date.index(after:idxyes)
                    let idxmes : String.Index = date.index(after:idxyee)
                    let idxmee : String.Index = date.index(after:idxmes)
                    let idxdes : String.Index = date.index(after:idxmee)
                    let idxdee : String.Index = date.index(after:idxdes)
                    let startdate : String = "20" + String(date[idxys...idxye]) + "-" + String(date[idxms...idxme]) + "-" + String(date[idxds...idxde])
                    let enddate : String = "20" + String(date[idxyes...idxyee]) + "-" + String(date[idxmes...idxmee]) + "-" + String(date[idxdes...idxdee])
                    content_List.append(GS1_Code_Content(title: String(localized: aiCode[AI]!), content: String(localized:"period") + startdate + "-" + enddate))
                }
            }else if AI == "7010"{
                var result:String = ""
                if tempResult == "01"{
                    result = String(localized:"fromSea")
                }else if tempResult == "02"{
                    result = String(localized:"fromWater")
                }else if tempResult == "03"{
                    result = String(localized:"farming")
                }else if tempResult == "04"{
                    result = String(localized:"aquaculture")
                }
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result))
            }else if AI == "7011"{
                var showdate:String = ""
                if tempResult.count == 6{///
                    let date : String = tempResult
                    let idxys : String.Index = date.startIndex
                    let idxye : String.Index = date.index(after:idxys)
                    let idxms : String.Index = date.index(after:idxye)
                    let idxme : String.Index = date.index(after:idxms)
                    let idxds : String.Index = date.index(after:idxme)
                    let idxde : String.Index = date.index(after:idxds)
                    showdate = "20" + String(date[idxys...idxye]) + "-" + String(date[idxms...idxme]) + "-" + String(date[idxds...idxde])
                }else if tempResult.count == 10{
                    let date : String = tempResult
                    let idxys : String.Index = date.startIndex
                    let idxye : String.Index = date.index(after:idxys)
                    let idxms : String.Index = date.index(after:idxye)
                    let idxme : String.Index = date.index(after:idxms)
                    let idxds : String.Index = date.index(after:idxme)
                    let idxde : String.Index = date.index(after:idxds)
                    let idxhs : String.Index = date.index(after:idxde)
                    let idxhe : String.Index = date.index(after:idxhs)
                    let idxmins : String.Index = date.index(after:idxhe)
                    let idxmine : String.Index = date.index(after:idxmins)
                    showdate = "20" + String(date[idxys...idxye]) + "-" + String(date[idxms...idxme]) + "-" + String(date[idxds...idxde]) + "-" + String(date[idxhs...idxhe]) + ":" + String(date[idxmins...idxmine])
                }
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:showdate))
            }else if AI == "7020" || AI == "7021" || AI == "7022" || AI == "7023"{
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:tempResult))
            }else if AI == "7030" || AI == "7031" || AI == "7032" || AI == "7033" || AI == "7034" || AI == "7035" || AI == "7036" || AI == "7037" || AI == "7038" || AI == "7039"{
                let ccode:String = String(tempResult.dropLast(tempResult.count-3))
                let cernum:String = String(tempResult.dropFirst(3))
                let result:String = String(localized:"ISOcountryCode") + ccode + ":" + cernum
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result))
            }else if AI == "7041"{
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:tempResult))
            }else if AI == "7230" || AI == "7231" || AI == "7232" || AI == "7233" || AI == "7234" || AI == "7235" || AI == "7236" || AI == "7237" || AI == "7238" || AI == "7239"{
                let cerkind:String = String(tempResult.dropLast(tempResult.count-2))
                let cernum:String = String(tempResult.dropFirst(2))
                let result:String = String(localized:"cerKind") + cerkind + ":" + cernum
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result))
            }else if AI == "7240" || AI == "7242" || AI == "7253" || AI == "7254" || AI == "7255" || AI == "7256" || AI == "7257" || AI == "7259"{
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:tempResult))
            }else if AI == "8003"{
                var result:String = ""
                if tempResult.count - 14 > 0{///
                    let idennum:String = String(tempResult.dropLast(tempResult.count-14))
                    let serinum:String = String(tempResult.dropFirst(14))
                    result = idennum + ":" + serinum
                }else if tempResult.count - 14 == 0{///
                    result = tempResult
                }
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:result))
            }else if AI == "8008"{
                var showdate:String = ""
                if tempResult.count == 12{///
                    let date : String = tempResult
                    let idxys : String.Index = date.startIndex
                    let idxye : String.Index = date.index(after:idxys)
                    let idxms : String.Index = date.index(after:idxye)
                    let idxme : String.Index = date.index(after:idxms)
                    let idxds : String.Index = date.index(after:idxme)
                    let idxde : String.Index = date.index(after:idxds)
                    let idxhs : String.Index = date.index(after:idxde)
                    let idxhe : String.Index = date.index(after:idxhs)
                    let idxmins : String.Index = date.index(after:idxhe)
                    let idxmine : String.Index = date.index(after:idxmins)
                    let idxss: String.Index = date.index(after:idxmine)
                    let idxse: String.Index = date.index(after:idxss)
                    showdate = "20" + String(date[idxys...idxye]) + "-" + String(date[idxms...idxme]) + "-" + String(date[idxds...idxde]) + "-" + String(date[idxhs...idxhe]) + ":" + String(date[idxmins...idxmine]) + ":" + String(date[idxss...idxse])
                }else if tempResult.count == 10{///
                    let date : String = tempResult
                    let idxys : String.Index = date.startIndex
                    let idxye : String.Index = date.index(after:idxys)
                    let idxms : String.Index = date.index(after:idxye)
                    let idxme : String.Index = date.index(after:idxms)
                    let idxds : String.Index = date.index(after:idxme)
                    let idxde : String.Index = date.index(after:idxds)
                    let idxhs : String.Index = date.index(after:idxde)
                    let idxhe : String.Index = date.index(after:idxhs)
                    let idxmins : String.Index = date.index(after:idxhe)
                    let idxmine : String.Index = date.index(after:idxmins)
                    showdate = "20" + String(date[idxys...idxye]) + "-" + String(date[idxms...idxme]) + "-" + String(date[idxds...idxde]) + "-" + String(date[idxhs...idxhe]) + ":" + String(date[idxmins...idxmine])
                }else if tempResult.count == 8{///
                    let date : String = tempResult
                    let idxys : String.Index = date.startIndex
                    let idxye : String.Index = date.index(after:idxys)
                    let idxms : String.Index = date.index(after:idxye)
                    let idxme : String.Index = date.index(after:idxms)
                    let idxds : String.Index = date.index(after:idxme)
                    let idxde : String.Index = date.index(after:idxds)
                    let idxhs : String.Index = date.index(after:idxde)
                    let idxhe : String.Index = date.index(after:idxhs)
                    showdate = "20" + String(date[idxys...idxye]) + "-" + String(date[idxms...idxme]) + "-" + String(date[idxds...idxde]) + "-" + String(date[idxhs...idxhe])
                }
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:showdate))
            }else if AI == "8010"{///
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:tempResult))
            }else if AI == "8030"{///
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:tempResult))
            }else if AI == "8002" || AI == "8004" || AI == "8007" || AI == "8009" || AI == "8011" || AI == "8012" || AI == "8013" || AI == "8014" || AI == "8019" || AI == "8020" || AI == "8110" || AI == "8112" || AI == "8200"{
                content_List.append(GS1_Code_Content(title:String(localized: aiCode[AI]!),content:tempResult))
            }
        }
        return String(leftText.dropFirst(rLength+1))
    }
}
