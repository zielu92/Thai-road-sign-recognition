//
//  ViewController.swift
//  Road Sign Detector
//
//  Created by Tomasz Baranowicz on 15/11/2019.
//  Copyright © 2019 Tomasz Baranowicz. All rights reserved.
//
//Loading libraries
import UIKit
import CoreML
import Vision
import ImageIO

class ViewController: UIViewController, UINavigationControllerDelegate {
    //ADDED init var from main.storyboard
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
    
    @IBOutlet weak var timeLabel: UILabel!
    
    //Load model using lazy method
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
    //Button to open photo library
    @IBAction func testPhoto(sender: UIButton) {
        let vc = UIImagePickerController()
        vc.sourceType = .photoLibrary
        vc.delegate = self
        present(vc, animated: true)
    }
    
    //Checking if loaded photo is correct and extract values like orientation
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
    //queuing detection
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
    //Detecting object on picture
    func detectionsOnImage(detections: [VNRecognizedObjectObservation]) {
        //ADDED init state for main.storyboard
        self.photoCroped1.image = nil
        self.label1.text = ""
        self.ocrLabel1.text = ""
        self.photoCroped2.image = nil
        self.label2.text = ""
        self.ocrLabel2.text = ""
        self.photoCroped3.image = nil
        self.label3.text = ""
        self.ocrLabel3.text = ""
        self.photoCroped4.image = nil
        self.label4.text = ""
        self.ocrLabel4.text = ""
        self.timeLabel.text = ""
        //start timer
        let start = CFAbsoluteTimeGetCurrent()
        var countObjects = 0
        //set image on UI
        guard let image = self.photoImageView?.image else {
            return
        }
        
        let imageSize = image.size
        let scale: CGFloat = 0
        UIGraphicsBeginImageContextWithOptions(imageSize, false, scale)
        image.draw(at: CGPoint.zero)
        for  (index, detection) in detections.enumerated() {
            countObjects=countObjects+1
            //FIX Drawing Rectangles (starts from bottom left corner)
            let boundingBox = detection.boundingBox
            let rectangle = CGRect(x: boundingBox.minX*image.size.width-10, y: (1-boundingBox.minY-boundingBox.height)*image.size.height-20, width: boundingBox.width*image.size.width*1.1, height: boundingBox.height*image.size.height*1.1)
            UIColor(red: 0, green: 1, blue: 0, alpha: 0.5).setFill()
            UIRectFillUsingBlendMode(rectangle, CGBlendMode.multiply)
            
            //ADDED CROPING
            let cropedCGI = cropImage(image: image, rect: rectangle)
            let croped = UIImage(cgImage: cropedCGI)
            
            //ADDED OCR
            ocr(cropedCGI: cropedCGI, index: index)
            //ADD Displaying images and labels on storyboard
            
            //Display croped image and label on UI
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
                print("Not found")
            }
        }
        
        //display the new image with drawed ractangle on the detected object
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        self.photoImageView?.image = newImage
        
        //stop timer calculate difference
        let diff = CFAbsoluteTimeGetCurrent() - start
        print("Took \(diff) seconds")
        self.timeLabel.text = "Found \(countObjects) obj in  \(diff) s"
    }
    //ADDED Croping method
    func cropImage(image: UIImage, rect: CGRect) -> CGImage {
        let croppedCGImage: CGImage = image.cgImage!.cropping(to: rect)!
        return croppedCGImage
    }
    //ADDED OCR method
    func ocr(cropedCGI: CGImage, index: Int) {
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
            //DISPLAYING OCR RESULTS
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
                print("Not found")
            }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        let requests = [request]
        //more parallel (speed improvment)
        DispatchQueue.main.async(qos: .userInitiated) {
            let handler = VNImageRequestHandler(cgImage: cropedCGI, options: [:])
            try? handler.perform(requests)
        }
        
    }
    
}

//LOAD UI
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
