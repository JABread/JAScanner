//
//  ViewController.swift
//  JAScanner
//
//  Created by 张俊安 on 2018/1/30.
//  Copyright © 2018年 John.Zhang. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    var resultLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Scanner"
        view.backgroundColor = UIColor.red
        let resultLabel = UILabel(frame: CGRect(x: 0, y: 63, width: UIScreen.main.bounds.width, height: 100))
        resultLabel.numberOfLines = 0
        view.addSubview(resultLabel)
        self.resultLabel = resultLabel

    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let scannerVc = ScannerViewController()
        scannerVc.scannedHandler = { [weak self] code in
            guard let `self` = self else { return }
            self.resultLabel.text = code
        }
        navigationController?.pushViewController(scannerVc, animated: true)
    }


}

