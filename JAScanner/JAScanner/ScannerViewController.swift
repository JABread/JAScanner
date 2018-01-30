//
//  ScannerViewController.swift
//  JAScanner
//
//  Created by 张俊安 on 2018/1/30.
//  Copyright © 2018年 John.Zhang. All rights reserved.
//

import UIKit
import AVFoundation


class ScannerViewController: UIViewController {

    var scannedHandler: ((_ code: String?) -> ())!
    var scanner: Scanner!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.white

        // 1. layout the preview of scanner
        scanner = Scanner(scanView: UIView(frame: CGRect(x: 0, y: 64, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)))
        view.addSubview(scanner.scanView)

        // 2. config the type of scanner
        scanner.metadataObjectTypes = [.qr, .ean13]

        // 3. handler the result of scanner
        scanner.scanableHandler = { [weak self] rawScanable in
            guard let `self` = self else { return }
            rawScanable?.valid { (rawScanable) -> Bool in
                // filter the code we want by setting the return boolean of condition
                return rawScanable.code.hasPrefix("http://weixin.qq.com")
                }?.process { (validScanable) -> Scanable? in
                    // set the valid code. e.g set the prefix or postfix
                    return Scanable(code: "prefix\(validScanable.code)")
                }?.handler { (processedScanable) -> Scanable? in
                    /* handler the code here.
                     e.g
                     let code = processedScanable.code
                     let congress = Congress.filtered(by: code)
                     */
                    self.scannedHandler(processedScanable.code)
                    self.navigationController?.popViewController(animated: true)
                    return nil
            }
        }

    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        scanner.startRunning()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        scanner.stopRunning()
    }


}



