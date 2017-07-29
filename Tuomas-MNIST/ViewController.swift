//
//  ViewController.swift
//  Tuomas-MNIST
//
//  Created by Tuomas Rintamäki on 23/07/2017.
//  Copyright © 2017 Tuomas Rintamäki. All rights reserved.
//

import UIKit
import Vision
import CoreMedia

class ViewController: UIViewController {

    @IBOutlet weak var drawView: DrawView!
    @IBOutlet weak var predictionLabel: UILabel!
    
    let model = mnist()
    var inputImage: CGImage!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        predictionLabel.isHidden = true
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK - Interaction with buttons
    @IBAction func tappedDetect(_ sender: Any) {
        let context = drawView.getViewContext()
        inputImage = context?.makeImage()
        let pixelBuffer = UIImage(cgImage: inputImage).pixelBuffer()
        let output = try? model.prediction(image: pixelBuffer!)
        predictionLabel.text = output?.classLabel
        predictionLabel.isHidden = false
    }
    
    @IBAction func tappedClear(_ sender: Any) {
        drawView.lines = []
        drawView.setNeedsDisplay()
        predictionLabel.isHidden = true
    }
    
}

extension UIImage {
    func pixelBuffer() -> CVPixelBuffer? {
        let width = self.size.width
        let height = self.size.height
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                     kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         Int(width),
                                         Int(height),
                                         kCVPixelFormatType_OneComponent8,
                                         attrs,
                                         &pixelBuffer)
        
        guard let resultPixelBuffer = pixelBuffer, status == kCVReturnSuccess else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(resultPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(resultPixelBuffer)
        
        let grayColorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(data: pixelData,
                                      width: Int(width),
                                      height: Int(height),
                                      bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(resultPixelBuffer),
                                      space: grayColorSpace,
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
                                        return nil
        }
        
        context.translateBy(x: 0, y: height)
        context.scaleBy(x: 1.0, y: -1.0)
        
        UIGraphicsPushContext(context)
        self.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        UIGraphicsPopContext()
        CVPixelBufferUnlockBaseAddress(resultPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        return resultPixelBuffer
    }
}

