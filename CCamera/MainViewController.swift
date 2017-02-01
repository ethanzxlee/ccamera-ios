//
//  ViewController.swift
//  CCamera
//
//  Created by Zhe Xian Lee on 19/01/2017.
//  Copyright © 2017 Zhe Xian Lee. All rights reserved.
//

import UIKit
import GLKit
import AVFoundation
import Photos

class MainViewController: UIViewController {
    
    let previewSelectiveColorFilter = SelectiveColorFilter()
    
    let outputSelectiveColorFilter = SelectiveColorFilter()
    
    let captureVideoDataOutputQueue = DispatchQueue(label: "captureVideoDataOutputQueue")
    
    let processCapturedImageQueue = DispatchQueue(label: "processCaptureIamgeQueue")
    
    var currentCaptureDevice : AVCaptureDevice?
    
    var captureDeviceInput: AVCaptureDeviceInput?
    
    var captureSession : AVCaptureSession?
    
    var captureVideoDataOutput : AVCaptureVideoDataOutput?
    
    var captureStillImageOutput : AVCaptureStillImageOutput?
    
    let ciContext = CIContext()
    
    @IBOutlet weak var cameraViewfinderView: UIImageView!
    @IBOutlet weak var temporaryCoverView: UIView!
    @IBOutlet weak var shutterButton: UIButton!
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Rotate the viewfinder so that it display in the correct orientation
        switch UIApplication.shared.statusBarOrientation {
        case .portrait:
            self.cameraViewfinderView.transform = CGAffineTransform.init(rotationAngle: CGFloat(M_PI) / CGFloat(2))
        case .portraitUpsideDown:
            self.cameraViewfinderView.transform = CGAffineTransform.init(rotationAngle: CGFloat(M_PI) / CGFloat(-2))
        default:
            break
        }

        
        // Check if we have permission to access camera
        if AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo) == .authorized {
            setupCaptureSession()
        } else {
            AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo, completionHandler: { [weak self] (granted) in
                if granted {
                    self?.setupCaptureSession()
                }
            })
        }
        
        let imageManager = PHImageManager()
        let imageRequestOptions = PHImageRequestOptions()
        imageRequestOptions.isSynchronous = true
        
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animate(alongsideTransition: { [weak self] (context) in
            if let vc = self {
                // Counter the rotation transformation of cameraViewfinder, so that it looks like not rotating
                let deltaRotation = atan2f(Float(context.targetTransform.b), Float(context.targetTransform.a))
                let currentRotation = atan2f(Float(vc.cameraViewfinderView.transform.b), Float(vc.cameraViewfinderView.transform.a))
                
                // Adding a small value to the rotation angle forces the animation to occur in a the desired direction,
                // preventing an issue where the view would appear to rotate 2PI radians during a rotation from LandscapeRight -> LandscapeLeft.
                let targetRotation = currentRotation - deltaRotation + 0.00001
                
                vc.cameraViewfinderView.transform = CGAffineTransform.init(rotationAngle: CGFloat(targetRotation))
            }
        }) { [weak self] (context) in
            // Integralize the transform to undo the extra 0.0001 added to the rotation angle.
            if let vc = self {
                vc.cameraViewfinderView.transform.a = round(vc.cameraViewfinderView.transform.a)
                vc.cameraViewfinderView.transform.b = round(vc.cameraViewfinderView.transform.b)
                vc.cameraViewfinderView.transform.c = round(vc.cameraViewfinderView.transform.c)
                vc.cameraViewfinderView.transform.d = round(vc.cameraViewfinderView.transform.d)
            }
        }
        
        super.viewWillTransition(to: size, with: coordinator)
    }

    
    @IBAction func didTouchShutterButton(_ sender: UIButton, forEvent event: UIEvent) {
        shutterButton.isEnabled = false
        capturePhoto()
        //CIColor(red: <#T##CGFloat#>, green: <#T##CGFloat#>, blue: <#T##CGFloat#>)
    }
    
    func capturePhoto() {
        if let connection = captureStillImageOutput?.connection(withMediaType: AVMediaTypeVideo) {
            captureStillImageOutput?.captureStillImageAsynchronously(from: connection, completionHandler: { [weak self] (sampleBuffer, error) in
                guard let sampleBuffer = sampleBuffer,
                    let vc = self
                else {
                    return
                }
                
                vc.shutterButton.isEnabled = true
                vc.processCapturedImageQueue.async {
                    vc.processCapturedImage(sampleBuffer)
                }
            })
        }
    }
    
    func processCapturedImage(_ sampleBuffer: CMSampleBuffer) {
        guard let imageJpegData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sampleBuffer)
        else {
            return
        }
        
        guard let capturedImage = UIImage(data: imageJpegData)
        else {
            return
        }
        
        outputSelectiveColorFilter.inputImage = CIImage(image: capturedImage)
        
        guard let outputImage = outputSelectiveColorFilter.outputImage
        else {
            return
        }
        
        let context = CIContext()
        let toSaveImage = UIImage(cgImage: context.createCGImage(outputImage, from: outputImage.extent)!)
        
        UIImageWriteToSavedPhotosAlbum(toSaveImage, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
    }
    
    func image(_ image: UIImage, didFinishSavingWithError error: NSError?, contextInfo: UnsafeMutableRawPointer?) {
        if error == nil {
            print("Image saved")
        }
    }
    
    func setupCaptureSession() {
        currentCaptureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        
        if currentCaptureDevice != nil {
            // Setting up inputs
            do {
                try captureDeviceInput = AVCaptureDeviceInput(device: currentCaptureDevice)
            } catch let error {
                print(error.localizedDescription)
            }
            
            // Setting up preview output
            captureVideoDataOutput = AVCaptureVideoDataOutput()
            captureVideoDataOutput!.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable: kCVPixelFormatType_32BGRA]
            captureVideoDataOutput!.alwaysDiscardsLateVideoFrames = true
            captureVideoDataOutput?.setSampleBufferDelegate(self, queue: captureVideoDataOutputQueue)
            
            // Setting up still image output
            captureStillImageOutput = AVCaptureStillImageOutput()
            
            // Setting up the capture session
            if currentCaptureDevice!.supportsAVCaptureSessionPreset(AVCaptureSessionPresetPhoto) {
                captureSession = AVCaptureSession()
                captureSession?.sessionPreset = AVCaptureSessionPresetPhoto
                captureSession?.beginConfiguration()
                captureSession?.addInput(captureDeviceInput)
                captureSession?.addOutput(captureVideoDataOutput)
                captureSession?.addOutput(captureStillImageOutput)
                captureSession?.commitConfiguration()
                captureSession?.startRunning()
                
                hideTemporaryCoverView()
            }
        }
    }
    
    func hideTemporaryCoverView() {
        UIView.animate(withDuration: 0.1, animations: {
            self.temporaryCoverView.alpha = 0
        })
    }
    
    func showTemporaryCoverView() {
        UIView.animate(withDuration: 0.1, animations: {
            self.temporaryCoverView.alpha = 1
        })
    }
}

extension MainViewController : AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            let image = CIImage(cvImageBuffer: imageBuffer)
            
            previewSelectiveColorFilter.inputImage = image
            let outputImage = UIImage(ciImage: previewSelectiveColorFilter.outputImage!)
            
            DispatchQueue.main.async {
                self.cameraViewfinderView.image = outputImage
            }
            
        }
    }
    
}

