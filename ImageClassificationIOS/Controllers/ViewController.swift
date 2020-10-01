//
//  ViewController.swift
//  ImageClassificationIOS
//
//  Created by Matheus Fogiatto on 01/10/20.
//  Copyright © 2020 Matheus Fogiatto. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    
    @IBOutlet weak var previewView: PreviewView!
    
    // MARK: Constants
    private let animationDuration = 0.5
    private let collapseTransitionThreshold: CGFloat = -40.0
    private let expandThransitionThreshold: CGFloat = 40.0
    private let delayBetweenInferencesMs: Double = 1000
    
    // MARK: Instance Variables
    // Holds the results at any time
    private var result: Result?
    private var initialBottomSpace: CGFloat = 0.0
    private var previousInferenceTimeMs: TimeInterval = Date.distantPast.timeIntervalSince1970 * 1000
    
    // MARK: Controllers that manage functionality
    // Handles all the camera related functionality
    private lazy var cameraCapture = CameraFeedManager(previewView: previewView)
    
    // Handles all data preprocessing and makes calls to run inference through the `Interpreter`.
    private var modelDataHandler: ModelDataHandler? =
        ModelDataHandler(modelFileInfo: MobileNet.modelInfo, labelsFileInfo: MobileNet.labelsInfo)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        cameraCapture.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        cameraCapture.checkCameraConfigurationAndStartSession()
      }

    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cameraCapture.stopSession()
    }
    
    @objc func classifyPasteboardImage() {
        guard let image = UIPasteboard.general.images?.first else {
            return
        }
        
        guard let buffer = CVImageBuffer.buffer(from: image) else {
            return
        }
        
        previewView.image = image
        
        DispatchQueue.global().async {
            self.didOutput(pixelBuffer: buffer)
        }
    }
}

// MARK: CameraFeedManagerDelegate Methods
extension ViewController: CameraFeedManagerDelegate {
    
    func didOutput(pixelBuffer: CVPixelBuffer) {
        let currentTimeMs = Date().timeIntervalSince1970 * 1000
        guard (currentTimeMs - previousInferenceTimeMs) >= delayBetweenInferencesMs else { return }
        previousInferenceTimeMs = currentTimeMs
        
        // Pass the pixel buffer to TensorFlow Lite to perform inference.
        result = modelDataHandler?.runModel(onFrame: pixelBuffer)
        
        // Display results by handing off to the InferenceViewController.
        DispatchQueue.main.async {
            let resolution = CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
            print(self.result ?? "")
            print(resolution)
            //            self.inferenceViewController?.inferenceResult = self.result
            //            self.inferenceViewController?.resolution = resolution
            //            self.inferenceViewController?.tableView.reloadData()
        }
    }
    
    // MARK: Session Handling Alerts
    func sessionWasInterrupted(canResumeManually resumeManually: Bool) {
        
        // Updates the UI when session is interupted.
        if resumeManually {
            // Set resume button hidden to false self.resumeButton.isHidden = false
        } else {
            // Set resume button hidden to Hidden
            //self.cameraUnavailableLabel.isHidden = false
        }
    }
    
    func sessionInterruptionEnded() {
        // Updates UI once session interruption has ended.
        //        if !self.cameraUnavailableLabel.isHidden {
        //            self.cameraUnavailableLabel.isHidden = true
        //        }
        //
        //        if !self.resumeButton.isHidden {
        //            self.resumeButton.isHidden = true
        //        }
    }
    
    func sessionRunTimeErrorOccured() {
        // Handles session run time error by updating the UI and providing a button if session can be manually resumed.
        //        self.resumeButton.isHidden = false
        //        previewView.shouldUseClipboardImage = true
    }
    
    func presentCameraPermissionsDeniedAlert() {
        let alertController = UIAlertController(title: "Camera Permissions Denied", message: "Camera permissions have been denied for this app. You can change this by going to Settings", preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        let settingsAction = UIAlertAction(title: "Settings", style: .default) { (action) in
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
        }
        alertController.addAction(cancelAction)
        alertController.addAction(settingsAction)
        
        present(alertController, animated: true, completion: nil)
        
        previewView.shouldUseClipboardImage = true
    }
    
    func presentVideoConfigurationErrorAlert() {
        let alert = UIAlertController(title: "Camera Configuration Failed", message: "There was an error while configuring camera.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        
        self.present(alert, animated: true)
        previewView.shouldUseClipboardImage = true
    }
}

