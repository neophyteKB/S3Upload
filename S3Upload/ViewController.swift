//
//  ViewController.swift
//  S3Upload
//
//  Created by Kamal on 04/09/19.
//  Copyright © 2019 Kamal. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let data = #imageLiteral(resourceName: "create_post").jpegData(compressionQuality: 1.0)
        S3.shared.uploadRequest(data: data, fileName: "image.jpeg", mediaType: .image, uploadProgress: { (progress) in
            debugPrint("Progress percentage -- \(progress.fractionCompleted)")
        }) { (url, error) in
            
        }
        
        
        S3.shared.uploadInMultipart(data: data, fileName: "image.jpeg", mediaType: .image, uploadProgress: { (progress) in
            
            
        }) { (url, error) in
            
        }
        
        S3.shared.performActions(action: .cancel)
        // Do any additional setup after loading the view.
    }


}

