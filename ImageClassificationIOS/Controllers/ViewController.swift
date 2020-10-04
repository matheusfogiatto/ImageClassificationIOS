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
    @IBOutlet weak var tableView: UITableView!
    
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
        tableView.dataSource = self
        tableView.delegate = self
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
            self.tableView.reloadData()
        }
    }
    
    // MARK: Session Handling Alerts
    func sessionWasInterrupted(canResumeManually resumeManually: Bool) {

    }
    
    func sessionInterruptionEnded() {

    }
    
    func sessionRunTimeErrorOccured() {

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
    
    func displayStringsForResults(atRow row: Int) -> (String, String) {

      var fieldName: String = ""
      var info: String = ""

      guard let tempResult = result, tempResult.inferences.count > 0 else {

        if row == 1 {
          fieldName = "No Results"
          info = ""
        }
        else {
          fieldName = ""
          info = ""
        }
        return (fieldName, info)
      }

      if row < tempResult.inferences.count {
        let inference = tempResult.inferences[row]
        fieldName = inference.label
        info =  String(format: "%.2f", inference.confidence * 100.0) + "%"
      }
      else {
        fieldName = ""
        info = ""
      }

      return (fieldName, info)
    }
}

extension ViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return result?.inferences.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ResultsTableViewCell") as? ResultsTableViewCell
        
        var fieldName = ""
        var info = ""
        
        let tuple = displayStringsForResults(atRow: indexPath.row)
        fieldName = tuple.0
        info = tuple.1
        
        cell?.nameLabel.text = fieldName
        cell?.percentLabel.text = info
        return cell ?? UITableViewCell()
    }
    
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50
    }
    
}

