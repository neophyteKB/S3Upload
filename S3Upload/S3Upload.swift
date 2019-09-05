//
//  S3Upload.swift
//  S3Upload
//
//  Created by Kamal on 04/09/19.
//  Copyright © 2019 Kamal. All rights reserved.
//

import Foundation
import AWSS3


typealias S3CompletionBlock = (_ url: String?, _ error: String?) -> Void


// Make sure to set bucket and s3 values, region should be compulsory to same as bucket has.
class S3 {
    
    static private let bucketName = "practina-test"
    static private let accessKey = "AKIAJJOE23XH3POFBHGA"
    static private let secretKey = "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"
    static private let region: AWSRegionType = .USWest2
    
    private func bucketSetup() {
        let credentialsProvider = AWSStaticCredentialsProvider(accessKey: S3.accessKey, secretKey: S3.secretKey)
        let configuration = AWSServiceConfiguration(region: S3.region, credentialsProvider: credentialsProvider)
        AWSServiceManager.default().defaultServiceConfiguration = configuration
    }
    
    private func publicUrl(_ fileName: String) -> String {
        let url = [AWSS3.default().configuration.endpoint.url.absoluteString, S3.bucketName, fileName].joined(separator: "/")
        return url
    }
    
    static var shared = S3()
    public lazy var multipartUploadingTasks = [AWSS3TransferUtilityMultiPartUploadTask]()
    public lazy var uploadingTasks = [AWSS3TransferUtilityTask]()
}

//MARK: => Upload files
extension S3 {
    public func uploadRequest(modal: UploadModal,
                              uploadProgress: ((_ progress: Progress) -> ())?,
                              completion: @escaping S3CompletionBlock) {
        
        // Prepare the bucket configurations
        bucketSetup()
        
        //Set progress block
        let expression: AWSS3TransferUtilityUploadExpression = AWSS3TransferUtilityUploadExpression()
        expression.progressBlock = {(task, progress) in
            uploadProgress?(progress)
            self.uploadingTasks.append(task)
        }
        
        //Start Uploading
        let transferUtility = AWSS3TransferUtility.default()
        transferUtility.uploadData(modal.data,
                                   bucket: S3.bucketName,
                                   key: modal.fileName,
                                   contentType: modal.type.mimeType,
                                   expression: expression) { (task, error) in
                                    if let error = error {
                                        completion(nil, error.localizedDescription)
                                        return
                                    }
                                    print(task.taskIdentifier)
                                    let url = self.publicUrl(modal.fileName)
                                    completion(url, nil)
        }
    }
    
    public func uploadInMultipart(modal: UploadModal,
                                uploadProgress: ((_ progress: Progress) -> ())?,
                                completion: @escaping S3CompletionBlock) {
        
        // Prepare the bucket configurations
        bucketSetup()
        
        //Set progress block
        let expression: AWSS3TransferUtilityMultiPartUploadExpression = AWSS3TransferUtilityMultiPartUploadExpression()
        expression.progressBlock = {(task, progress) in
            uploadProgress?(progress)
            self.multipartUploadingTasks.append(task)
        }
        
        //Start Uploading
        let transferUtility = AWSS3TransferUtility.default()
        transferUtility.uploadUsingMultiPart(data: modal.data,
                                             bucket: S3.bucketName,
                                             key: modal.fileName,
                                             contentType: modal.type.mimeType,
                                             expression: expression) { (task, error) in
                                                
                                                if let error = error {
                                                    completion(nil, error.localizedDescription)
                                                    return
                                                }
                                                print(task.transferID)
                                                let url = self.publicUrl(modal.fileName)
                                                completion(url, nil)
        }
    }
    
    private func removeTaskFromUploading(_ task: Any) {
        if let uploadTask = task as? AWSS3TransferUtilityTask {
            if let index = uploadingTasks.firstIndex(of: uploadTask) {
                uploadingTasks.remove(at: index)
            }
        }
        else if let multipartTask = task as? AWSS3TransferUtilityMultiPartUploadTask {
            if let index = multipartUploadingTasks.firstIndex(of: multipartTask) {
                multipartUploadingTasks.remove(at: index)
            }
        }
    }
}


//MARK: => Delete or cancel the task
extension S3 {
    public func performActions(action a: UploadAction) {
        
        //Multipart uploading Actions
        multipartUploadingTasks.forEach { (task) in
            switch a {
            case .cancel : task.cancel()
            case .pause: task.suspend()
            case .resume: task.resume()
            }
        }
        
        //Normal uploading Actions
        uploadingTasks.forEach { (task) in
            switch a {
            case .cancel : task.cancel()
            case .pause: task.suspend()
            case .resume: task.resume()
            }
        }
    }
    
    public func deleteFile(fileName name: String?, completion: @escaping(_ status: Bool, _ error: String?) -> ()) {
        // Prepare the bucket configurations
        bucketSetup()
        
        //Prepare to delete the filename
        let s3Object = AWSS3.default()
        let deleteRequest = AWSS3DeleteObjectRequest()
        deleteRequest?.bucket = S3.bucketName
        deleteRequest?.key = name
        guard let obj = deleteRequest else {
            completion(false , "Something went wrong with bucket settings.")
            return
        }
        s3Object.deleteObject(obj).continueWith { (task) -> Any? in
            DispatchQueue.main.async {
                if let error = task.error {
                    completion(false , error.localizedDescription)
                }
                completion(true, nil)
            }
        }
    }
}

struct UploadModal {
    var data: Data
    var fileName: String
    var type: FileTypes
}

enum FileTypes {
    case image
    case video
    case document

    var mimeType: String {
        switch self {
        case .image: return "image/jpeg"
        case .video: return "video/mp4"
        case .document: return "application/pdf"
        }
    }
}

enum UploadAction {
    case pause, resume, cancel
}


import AVKit
extension URL {
    func compressVideo(fileName: String, compression: String = AVAssetExportPresetMediumQuality, handler:@escaping (_ outputUrl: URL?) -> ()) {
        let outputUrl = URL(fileURLWithPath: (NSTemporaryDirectory() + fileName))
        let urlAsset = AVURLAsset(url: self, options: nil)
        guard let exportSession = AVAssetExportSession(asset: urlAsset, presetName: compression) else {
            handler(nil)
            
            return
        }
        exportSession.outputURL = outputUrl
        exportSession.outputFileType = AVFileType.mov
        exportSession.shouldOptimizeForNetworkUse = true
        exportSession.exportAsynchronously { () -> Void in
            if exportSession.status == .completed {
                handler(outputUrl)
            }
        }
    }
}
