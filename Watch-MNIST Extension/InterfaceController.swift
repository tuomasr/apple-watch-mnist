//
//  InterfaceController.swift
//  Watch-MNIST Extension
//
//  Created by Tuomas Rintamäki on 25/07/2017.
//  Copyright © 2017 Tuomas Rintamäki. All rights reserved.
//

import CoreVideo

import WatchKit
import Foundation

class InterfaceController: WKInterfaceController {
    @IBOutlet var myLabel: WKInterfaceLabel!
    @IBOutlet var canvasGroup: WKInterfaceGroup!
    
    let model = mnist()
    
    var penWidth: CGFloat = 7
    var color = UIColor.white
    var previousPoint1: CGPoint!
    var previousPoint2: CGPoint!
    var savedImage: UIImage?
    var scaledImage: UIImage?
    var isInstructionVisible = true
    
    var mnistSize = CGSize(width: 28, height: 28)

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        // Configure interface objects here.
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

    @IBAction func detectTapped() {
        let pixelBuffer = scaledImage?.pixelBuffer()
        let output = try? model.prediction(image: pixelBuffer!)
        myLabel.setText("It's a " + output!.classLabel + ".")
    }
    
    @IBAction func clearTapped() {
        myLabel.setText("Please draw!")
        savedImage = nil
        canvasGroup.setBackgroundImage(nil)
    }
    
    // this method calculates the midpoint between two points
    func midPoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        return CGPoint(x: (a.x + b.x) * 0.5, y: (a.y + b.y) * 0.5)
    }
    
    // this method helps tame large velocity values
    // the plot of sqrt() curves up and out from zero
    // sqrt() doesn't work for negative numbers, so we have to use the absolute value and add the negative sign back in
    func exponentialScale(_ a: CGFloat) -> CGFloat {
        return a >= 0 ? sqrt(a) : -sqrt(abs(a))
    }
    
    func curveThrough(a: CGPoint, b: CGPoint, c: CGPoint, in rect: CGRect, with alphaComponent: CGFloat = 1) -> UIImage {
        let mid2 = midPoint(b, a)
        let mid1 = midPoint(c, b)
        
        UIGraphicsBeginImageContextWithOptions(rect.size, true, 0) // opaque for performance
        savedImage?.draw(in: rect) // paste the previous rendering
        let linePath = UIBezierPath()
        linePath.move(to: mid2)
        linePath.addQuadCurve(to: mid1, controlPoint: b)
        color.set()
        linePath.lineWidth = penWidth
        linePath.lineCapStyle = .round
        linePath.stroke()
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }
    
    @IBAction func panRecognized(_ sender: AnyObject) {
        guard let panGesture = sender as? WKPanGestureRecognizer else {
            return
        }
        
        let rect = panGesture.objectBounds()
        switch panGesture.state {
        case .began:
            previousPoint1 = panGesture.locationInObject()
            
            // create backward projection
            let velocity = panGesture.velocityInObject()
            // the pan gesture recognizer requires some movement before recognition
            // this multiplier accounts for the delay
            let multiplier: CGFloat = 1.75
            previousPoint2 = CGPoint(x: previousPoint1.x - exponentialScale(velocity.x) * multiplier,
                                     y: previousPoint1.y - exponentialScale(velocity.y) * multiplier)
            
        case .changed:
            
            let currentPoint = panGesture.locationInObject()
            
            // draw a curve through the two mid points between three points. The middle point acts as a control point
            // this creates a smoothly connected curve
            // a downside to this apprach is that the drawing doesn't reach all the way to the the user's finger touch. We create forward and backward projections with the velocity to account for the lag
            let actualImage = curveThrough(a: previousPoint2, b: previousPoint1, c: currentPoint, in: rect)
            savedImage = actualImage
            
            // create forward projection
            let velocity = panGesture.velocityInObject()
            let projectedPoint = CGPoint(x: currentPoint.x + exponentialScale(velocity.x), y: currentPoint.y + exponentialScale(velocity.y))
            let projectedImage = curveThrough(a: previousPoint1,
                                              b: currentPoint,
                                              c: midPoint(currentPoint, projectedPoint),
                                              in: rect,
                                              with: 0.5)
            // show the forward projection but don't save it
            canvasGroup.setBackgroundImage(projectedImage)
            
            previousPoint2 = previousPoint1
            previousPoint1 = currentPoint
            
        case .ended:
            let currentPoint = panGesture.locationInObject()
            let image = curveThrough(a: previousPoint2, b: previousPoint1, c: currentPoint, in: rect)
            canvasGroup.setBackgroundImage(image)
            savedImage = image
            scaledImage = imageWithImage(image: image, scaledToSize: mnistSize)
        default:
            break
        }
    }
}

func imageWithImage(image:UIImage, scaledToSize newSize:CGSize) -> UIImage{
    UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0);
    image.draw(in: CGRect(origin: CGPoint.zero, size: CGSize(width: newSize.width, height: newSize.height)))
    let newImage:UIImage = UIGraphicsGetImageFromCurrentImageContext()!
    UIGraphicsEndImageContext()
    return newImage
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
