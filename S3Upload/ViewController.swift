//
//  ViewController.swift
//  S3Upload
//
//  Created by Kamal on 04/09/19.
//  Copyright © 2019 Kamal. All rights reserved.
//

import UIKit
import MobileCoreServices
import Reachability

class ViewController: UIViewController {

    let reachability = Reachability()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
    }
    
    private func openCaptureOptions(_ source: UIImagePickerController.SourceType) {
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = source
        imagePicker.mediaTypes = [kUTTypeImage as String, kUTTypeMovie as String]
        imagePicker.delegate = self
        present(imagePicker, animated: true, completion: nil)
    }
    
    private func requestS3Upload(modal: UploadModal) {
        S3.shared.uploadInMultipart(modal: modal,
                                    uploadProgress: { (progress) in
                                        
                                        debugPrint("Proress (Multipart upload) == \(progress.fractionCompleted)")
                                        
        }) { (url, error) in
            if let error = error {
                print("Error in uploading ==== \(error)")
            }
            else if let url = url {
                print("Url =  \(url)")
            }
        }
    }
    
    private func enableReachablility() {
        reachability?.whenReachable = { reachability in
            if reachability.connection == .wifi {
                S3.shared.performActions(action: .resume)
            } else {
                S3.shared.performActions(action: .pause)
            }
        }
        reachability?.whenUnreachable = { _ in
            S3.shared.performActions(action: .pause)
        }
        reachability?.whenReachable = { _ in
            S3.shared.performActions(action: .resume)
        }
        
        do {
            try reachability?.startNotifier()
        } catch {
            print("Unable to start notifier")
        }
    }
    
    
    @IBAction func btnAction(_ sender: UIButton) {
        let action = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        action.addAction(UIAlertAction(title: "Camera", style: .default, handler: { [weak self] (_) in
            self?.openCaptureOptions(.camera)
        }))
        action.addAction(UIAlertAction(title: "Gallery", style: .default, handler: { [weak self] (_) in
            self?.openCaptureOptions(.photoLibrary)
        }))
        action.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        if UIDevice.current.userInterfaceIdiom == .pad {
            action.popoverPresentationController?.sourceView = sender
            action.popoverPresentationController?.sourceRect = sender.bounds
        }
        present(action, animated: true, completion: nil)
    }

}

//Upload to S3
extension ViewController {
    private func uploadFile(_ image: UIImage?, _ videoUrl:URL?) {
        if let data = image?.jpegData(compressionQuality: 0.7) {
            let fileName = "image\(Int(Date().timeIntervalSinceReferenceDate)).jpeg"
            let modal = UploadModal(data: data,
                                    fileName: fileName,
                                    type: .image)
            requestS3Upload(modal: modal)
        }
        else if let url = videoUrl, let data = try? Data(contentsOf: url) {
           
            //=> If you need compress the video, you can use the following method. It will return you compressed URL in completion
            /**
             url.compressVideo(fileName: <FILENAME>, handler: <COMPLETION_BLOCK>)
             url.compressVideo(fileName: <FILENAME>, compression: <COMPRESSION_VALUE>, handler: <COMPLETION_BLOCK>)
             **/
            
            if data.count > 5000000, reachability?.connection != .wifi {
               // "You are not connected to Wifi"  - show Alert
            }
            let fileName = "video\(Int(Date().timeIntervalSinceReferenceDate)).mp4"
            let modal = UploadModal(data: data,
                                    fileName: fileName,
                                    type: .video)
            requestS3Upload(modal: modal)
        }
    }
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
       let mediaType = info[UIImagePickerController.InfoKey.mediaType] as! CFString
        
        switch mediaType {
        case kUTTypeImage: uploadFile(info[UIImagePickerController.InfoKey.originalImage] as? UIImage, nil)
            
        case kUTTypeMovie: uploadFile(nil, info[UIImagePickerController.InfoKey.mediaURL] as? URL)
            
        default: break
        }
        dismiss(animated: true, completion: nil)
    }
}

