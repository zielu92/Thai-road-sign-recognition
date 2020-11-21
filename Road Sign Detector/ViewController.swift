//
//  ViewController.swift
//  Road Sign Detector
//
//  Created by Tomasz Baranowicz on 15/11/2019.
//  Copyright © 2019 Tomasz Baranowicz. All rights reserved.
//

import UIKit
import CoreML
import Vision
import ImageIO

class ViewController: UIViewController, UINavigationControllerDelegate {
    //init var from storyboard ADDED
    @IBOutlet weak var photoImageView: UIImageView?
    @IBOutlet weak var photoCroped1: UIImageView!
    @IBOutlet weak var photoCroped2: UIImageView!
    @IBOutlet weak var photoCroped3: UIImageView!
    @IBOutlet weak var photoCroped4: UIImageView!
    @IBOutlet weak var label1: UILabel!
    @IBOutlet weak var label2: UILabel!
    @IBOutlet weak var label3: UILabel!
    @IBOutlet weak var label4: UILabel!
    
    @IBOutlet weak var ocrLabel1: UILabel!
    @IBOutlet weak var ocrLabel2: UILabel!
    @IBOutlet weak var ocrLabel3: UILabel!
    @IBOutlet weak var ocrLabel4: UILabel!

    lazy var detectionRequest: VNCoreMLRequest = {
        do {
            let model = try VNCoreMLModel(for: ThaiRoadSignsV3_1().model)
            
            let request = VNCoreMLRequest(model: model, completionHandler: { [weak self] request, error in
                self?.processDispatcher(for: request, error: error)
            })
            request.imageCropAndScaleOption = .scaleFit
            return request
        } catch {
            fatalError("Failed to load ML model: \(error)")
        }
    }()
    
    @IBAction func testPhoto(sender: UIButton) {
        let vc = UIImagePickerController()
        vc.sourceType = .photoLibrary
        vc.delegate = self
        present(vc, animated: true)
    }
    
    private func checkPhoto(for image: UIImage) {

        let orientation = CGImagePropertyOrientation(rawValue: UInt32(image.imageOrientation.rawValue))
        guard let ciImage = CIImage(image: image) else { fatalError("Unable to create \(CIImage.self) from \(image).") }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation!)
            do {
                try handler.perform([self.detectionRequest])
            } catch {
                print("Detection failed.\n\(error.localizedDescription)")
            }
        }
    }
    
    private func processDispatcher(for request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            guard let results = request.results else {
                print("Unable to detect.\n\(error!.localizedDescription)")
                return
            }
        
            let detections = results as! [VNRecognizedObjectObservation]
            self.detectionsOnImage(detections: detections)
        }
    }
    
    func detectionsOnImage(detections: [VNRecognizedObjectObservation]) {
        //init ADDED
        self.photoCroped1.image = nil
        self.label1.text = ""
        self.ocrLabel2.text = ""
        self.photoCroped2.image = nil
        self.label2.text = ""
        self.ocrLabel2.text = ""
        self.photoCroped3.image = nil
        self.label3.text = ""
        self.ocrLabel3.text = ""
        self.photoCroped4.image = nil
        self.label4.text = ""
        self.ocrLabel4.text = ""
        
        guard let image = self.photoImageView?.image else {
            return
        }
        
        let imageSize = image.size
        let scale: CGFloat = 1.6
        UIGraphicsBeginImageContextWithOptions(imageSize, false, scale)

        image.draw(at: CGPoint.zero)
        var countObjects = 0
        for  (index, detection) in detections.enumerated() {
            countObjects=countObjects+1
            //Drawing Rectangles FIXED
            let boundingBox = detection.boundingBox
            let rectangle = CGRect(x: boundingBox.minX*image.size.width-10, y: (1-boundingBox.minY-boundingBox.height)*image.size.height-20, width: boundingBox.width*image.size.width*1.1, height: boundingBox.height*image.size.height*1.1)
            UIColor(red: 0, green: 1, blue: 0, alpha: 0.5).setFill()
            UIRectFillUsingBlendMode(rectangle, CGBlendMode.multiply)
            
            //CROPING ADDED
            let cropedCGI = cropImage(image: image, rect: rectangle)
            let croped = UIImage(cgImage: cropedCGI)
            //OCR ADDED
            var OCRtext = ""
            let request = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    fatalError("Received invalid observations")
                }
                for observation in observations {
                    guard let bestCandidate = observation.topCandidates(1).first else {
                        OCRtext = " "
                        continue
                    }
                    OCRtext += " \(bestCandidate.string)"
                }
                //DISPLAYING OCR RESULTS ADDED
                switch index {
                    case 0:
                        self.ocrLabel1.text = OCRtext
                    case 1:
                        self.ocrLabel2.text = OCRtext
                    case 2:
                        self.ocrLabel3.text = OCRtext
                    case 3:
                        self.ocrLabel4.text = OCRtext
                default:
                    print("No found")
                }
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            //OCR Request ADDED
            let requests = [request]
            //more parallel
            DispatchQueue.main.async(qos: .userInitiated) {
                let handler = VNImageRequestHandler(cgImage: cropedCGI, options: [:])
                try? handler.perform(requests)
            }
            
            //DISPLAYING ADDED
            switch index {
                case 0:
                    self.photoCroped1.image = croped
                    self.label1.text = detection.labels.first?.identifier
                    self.ocrLabel1.text = "OCR loading..."
                case 1:
                    self.photoCroped2.image = croped
                    self.label2.text = detection.labels.first?.identifier
                    self.ocrLabel2.text = "OCR loading..."
                case 2:
                    self.photoCroped3.image = croped
                    self.label3.text = detection.labels.first?.identifier
                    self.ocrLabel3.text = "OCR loading..."
                case 3:
                    self.photoCroped4.image = croped
                    self.label4.text = detection.labels.first?.identifier
                    self.ocrLabel4.text = "OCR loading..."
            default:
                print("No found")
            }
        }
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        self.photoImageView?.image = newImage
        
        print(countObjects)

    }
    //Croping function ADDED
    func cropImage(image: UIImage, rect: CGRect) -> CGImage {
        let croppedCGImage: CGImage = image.cgImage!.cropping(to: rect)!
        return croppedCGImage
    }
    
}


extension ViewController: UIImagePickerControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)

        guard let image = info[.originalImage] as? UIImage else {
            return
        }

        self.photoImageView?.image = image
        checkPhoto(for: image)
    }
}
