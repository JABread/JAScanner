//
//  Scanner.swift
//  JAScanner
//
//  Created by 张俊安 on 2018/1/30.
//  Copyright © 2018年 John.Zhang. All rights reserved.
//

/* v0.1.0
 * Feature
 * 1. Scanner只是一个功能类，在构造方法中传入扫描区域的view即可，几行代码即可完成大部分的项目需求，而非继承viewController以获取扫描功能，减轻控制器层的业务负担。
 * 2. 目前只对外提供两个设置属性，分别是处理扫描成功后的block以及设置指定的扫描类型。
 * 3. 通过队列管理耗时操作，减少卡顿。
 *
 * Drawback
 * 1. 业务场景考虑不周全，功能少。
 * 2. 未进行充分测试。
 * Usage
 *
 /// viewController 引用scanner
 var scanner: Scanner!
 /// 调用Scanner的唯一构造方法，传入用来扫描的preview View。
 scanner = Scanner(scanView: UIView(frame: CGRect(x: 0, y: 64, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)))
 /// 添加到控制器的view
 view.addSubview(scanner.scanView)
 /// 处理扫描成功的block
 scanner.scannedHandler = { [weak self] code in
 guard let `self` = self else { return }
 if let code = code {
 print(code)
 }
 }
 */

/*
 * v0.2.0
 * Usage
 *
 * look at the code source in ScannerViewController.swift
 *
 */

import UIKit
import AVFoundation

import SVProgressHUD

class Scanner: NSObject {

    /// 处理扫描结果
    var scannedHandler: ((_ code: String?) -> ())?
    /// 处理扫描结果
    var scanableHandler: ((_ scanable: Scanable?) -> ())?
    /// 指定扫描类型
    var metadataObjectTypes: [AVMetadataObject.ObjectType] = [.qr]


    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    private var setupResult: SessionSetupResult = .success
    private let sessionQueue = DispatchQueue(label: "session queue")
    private(set) var scanView: UIView
    private let validView: UIView = {
        let validView = UIView(frame: CGRect(x: UIScreen.main.bounds.width/2 - 110, y: 100, width: 220, height: 220))
        validView.layer.borderColor = UIColor.green.cgColor
        validView.layer.borderWidth = 1.0
        return validView
    }()
    private var session: AVCaptureSession = {
        let session = AVCaptureSession()
        session.sessionPreset = .high
        return session
    }()
    private let output = AVCaptureMetadataOutput()
    private var input: AVCaptureDeviceInput!
    private let videoPreviewLayer = AVCaptureVideoPreviewLayer()
    private let scanInterval = 0.5

    private override init() {
        self.scanView = UIView()
        super.init()
    }

    init(scanView: UIView) {
        self.scanView = scanView
        super.init()

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
                if !granted {
                    self.setupResult = .notAuthorized
                }
                self.sessionQueue.resume()
            })
        default:
            setupResult = .notAuthorized
        }

        sessionQueue.async {
            self.configureSession()
        }

        DispatchQueue.main.async {
            let size = self.scanView.bounds.size
            let validRect = self.validView.frame
            self.output.rectOfInterest = self.videoPreviewLayer.metadataOutputRectConverted(fromLayerRect: CGRect(x: validRect.origin.y/size.height, y: validRect.origin.x/size.width, width: validRect.size.height/size.height, height: validRect.size.width/size.width))
            self.videoPreviewLayer.videoGravity = .resizeAspectFill
            self.videoPreviewLayer.frame = self.scanView.bounds
            self.videoPreviewLayer.session = self.session
            self.videoPreviewLayer.addSublayer(self.validView.layer)
            self.scanView.layer.addSublayer(self.videoPreviewLayer)
        }

    }

}

// MARK: - session state
extension Scanner {
    public func startRunning() {
        DispatchQueue.main.async {
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }
    public func stopRunning() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }
    public func isRunning() -> Bool { return session.isRunning }
}

// MARK: - session configuration
extension Scanner {
    private func configureSession() {
        if setupResult != .success { return }
        session.beginConfiguration()

        do {
            var defaultVideoDevice: AVCaptureDevice?

            if let dualCameraDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
                defaultVideoDevice = dualCameraDevice
            } else if let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                defaultVideoDevice = backCameraDevice
            } else if let frontCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                defaultVideoDevice = frontCameraDevice
            }

            let videoDeviceInput = try AVCaptureDeviceInput(device: defaultVideoDevice!)

            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                self.input = videoDeviceInput
            } else {
                print("Could not add video device input to the session")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }

            if session.canAddOutput(output) {
                session.addOutput(output)
                output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                output.metadataObjectTypes = self.metadataObjectTypes
            } else {
                print("Could not add photo output to the session")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }

        } catch {
            print("Could not create video device input: \(error)")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }

        session.commitConfiguration()

    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate
extension Scanner: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {

        if let metadataObject = metadataObjects.first, let codeObject = metadataObject as? AVMetadataMachineReadableCodeObject, let code = codeObject.stringValue {
            scannedHandler?(code)
            scanableHandler?(Scanable(code: code))

            stopRunning()
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + scanInterval, execute: {
                self.startRunning()
            })

        } else {
            scannedHandler?(nil)
            scanableHandler?(nil)
        }

    }
}

// MARK: - decoration
extension Scanner {
    /// 设置扫描的`边框`以及解析区域
    func decorate(validView: UIView, validRect: CGRect) {
        // TODO: 设置扫描的`边框`以及解析区域
    }
}

// MARK: - Scanable Structure
struct Scanable {
    let code: String
}

extension Scanable{
    /// 验证
    func valid(predicate: (Scanable) -> Bool) -> Scanable? {
        if predicate(self) == false {
            SVProgressHUD.showError(withStatus: "Invalid code")
            return nil
        }
        return Scanable(code: code)
    }

    /// 修改
    func process(transform: (Scanable) -> Scanable?) -> Scanable? {
        if let ts = transform(self) {
            return Scanable(code: ts.code)
        } else { return nil }

    }

    /// 处理
    @discardableResult
    func handler(handle: (Scanable) -> Scanable?) -> Scanable? {
        return handle(self)
    }
}








