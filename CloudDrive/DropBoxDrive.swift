//
//  DropBox.swift
//  CloudDrive
//
//  Created by Nelson on 12/17/16.
//  Copyright © 2016 Nelson. All rights reserved.
//

import Foundation
import SwiftyDropbox

let DropBoxAppKey = "DropBoxAppKey"
class DropBoxDrive : CloudDrive, CloudDriveProtocol{

    static let setupOnce : Void = {
    
        let path = Bundle.main.path(forResource: "Info", ofType: "plist")
        let dic = NSDictionary(contentsOfFile: path!)
        let appKey = dic?[DropBoxAppKey]
        
        assert(appKey != nil, "No app key for DropBox. In Info.plist add \(DropBoxAppKey) as key and [YourDropBoxAppKey] as string value")
        
        DropboxClientsManager.setupWithAppKey(appKey as! String)
        //DropboxClientsManager.setupWithAppKey("e1acqhgupugq70w")
        
    }()
    
    var client : DropboxClient?
    
    required override init() {
        
        super.init()
        
        DropBoxDrive.setupOnce
    }
    
    deinit {
        
        self.client = nil
    }
    
    private func verifiesURLSchemes() {
        
        // verifies that the custom URI scheme has been updated in the Info.plist
        let urlTypes : [AnyObject] = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as! [AnyObject]
        assert(urlTypes.count > 0, "No custom URI scheme has been configured for DropBox for the project.")
        let urlSchemes : [AnyObject] = urlTypes.first?["CFBundleURLSchemes"] as! [AnyObject]
        assert(urlSchemes.count > 0, "No custom URI scheme has been configured for DropBox for the project.")
        
        
        var urlScheme : String? = nil
        
        for item in urlSchemes{
            
            if (item as! String).hasPrefix("db-"){
                
                urlScheme = item as? String
                
                break
            }
        }
        
        assert(urlScheme != nil, "Configure the URI scheme in Info.plist (URL Types -> Item 0 -> URL Schemes -> Item 0) and give your DropBox app key e.g: db-[YourDropBoxAppKey]")
    }
    
    //MARK:CloudDriveProtocol
    
    func authorize(inController:UIViewController) {
        
        self.verifiesURLSchemes()
        
        guard DropboxClientsManager.authorizedClient == nil else {
            
            if let handler = authCompleteHandler{
                
                self.client = DropboxClientsManager.authorizedClient
                handler(CloudDriveAuthState.Success)
            }
            
            return
        }
        
        DropboxClientsManager.authorizeFromController(UIApplication.shared, controller: inController, openURL: { (url:URL) in
        
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }, browserAuth: false)
    }
    
    func contentsAtPath(path: String, complete: (([CloudDriveMetadata]?, CloudDriveError?) -> ())?){
        
        guard self.client != nil else {
        
            if let handler = complete {
                
                handler(nil, CloudDriveError.CloudDriveInternalError("DropBox client was not authorized"))
            }
            
            return
        }
        
        self.client?.files.listFolder(path: path).response(completionHandler: { result, error in
            
            if error == nil {
                
                guard (result?.entries.count)! > 0 else {
                    
                    if let handler = complete {
                        
                        handler(nil, nil)
                    }
                    
                    return
                }
                
                var retMetadata = Array<CloudDriveMetadata>()
                
                let lastPath = path == "" ? path : (path as NSString).lastPathComponent
                let underRoot = path == "" ? true : false
                
                for metadata in (result?.entries)!{
                    
                    //metadata is folder
                    if metadata is Files.FolderMetadata{
                        
                        retMetadata.append(CloudDriveMetadata(m_folder: true, m_underRootFolder: underRoot, m_name: metadata.name, m_ParentFolderName:lastPath, m_underPath: path))
                    }
                    //metadata is file
                    else if metadata is Files.FileMetadata{
                        
                        retMetadata.append(CloudDriveMetadata(m_folder: false, m_underRootFolder: underRoot, m_name: metadata.name, m_ParentFolderName:lastPath, m_underPath: path))
                    }
                }
                
                if let handler = complete {
                    
                    handler(retMetadata, nil)
                }
                
            }
            else {
                
                if let handler = complete{
                    
                    handler(nil, CloudDriveError.CloudDriveInternalError((error?.description)!))
                }
                
            }
        })
    }
    
    func driveType() -> CloudDriveType{
    
        return .DropBox
    }
    
    func driveTypeString() -> String{
        
        return "DropBox"
    }
    
    func rootPath() -> String{
        
        return ""
    }
    
    func appendingPathComponent(currentPath:String, component:String) -> String{
        
        if currentPath == rootPath(){
            
           return ("/" as NSString).appendingPathComponent(component)
        }
        
        return (currentPath as NSString).appendingPathComponent(component)
    }
    
    func deletingLastPathComponent(path:String) -> String{
        
        let removedPath = (path as NSString).deletingLastPathComponent
        
        if removedPath == "/" || removedPath == ""{
            
            return self.rootPath()
        }
        
        return removedPath
    }
    
    func createDownloadTask(path: String, localPath: String) -> CloudDriveDownloadTask {
    
        let download = DropBoxDownload(type: .DropBox, path: path, localPath: localPath)
        download.client = self.client
        
        return download
    }
    
    func logout() {
        
        DropboxClientsManager.unlinkClients()
        self.client = nil
    }
    
    //MARK:Override from CloudDrive
    override func handleRedirect(url:URL) {
        
        if let authResult = DropboxClientsManager.handleRedirectURL(url) {
            switch authResult {
            case .success:
                if let handler = authCompleteHandler{
                    
                    self.client = DropboxClientsManager.authorizedClient
                    handler(CloudDriveAuthState.Success)
                }
            case .cancel:
                if let handler = authCompleteHandler{
                    
                    self.client = nil
                    handler(CloudDriveAuthState.Cancel)
                }
            case .error(_, let description):
                if let handler = authCompleteHandler{
                    
                    self.client = nil
                    handler(CloudDriveAuthState.Error(description))
                }
            }
        }
    }
    
    override func cloudName() -> String{
        
        return "DropBox"
    }
}

//MARK:DropBoxDownload class
class DropBoxDownload : CloudDriveDownloadTask, CloudDriveDownloadProtocol{
    
    weak var client : DropboxClient?
    
    /**
     DropBox download task
     Make sure to nil it when everything done otherwise will cause memory leak
    */
    var task : DownloadRequestFile<Files.FileMetadataSerializer, Files.DownloadErrorSerializer>?
    
    deinit {
        
        self.client = nil
        self.task = nil
        
    }
    
    override func driveTypeString() -> String{
        
        return "DropBox"
    }
    
    func startDownload(){
        
        if self.task != nil{
            self.task?.cancel()
            self.task = nil
        }
        
        self.task = self.client?.files.download(path: self.filePathAtCloud, overwrite: self.overWriteFile, destination: { tempURL, respone -> URL in
            
            return URL(fileURLWithPath: self.filePathAtLocal)
        })
        
        //response
        self.task?.response(completionHandler: { respone, error in
            
            //if cancel we dont notify whether it is complete or error
            if self.status == .Cancel{
                
                return
            }
            
            if error != nil{
                
                self.status = .Error
                
                if let handler = self.onDownloadError{
                    
                    handler(self, CloudDriveError.CloudDriveDownloadError((error?.description)!))
                }
            }
            else{
                
                self.status = .Complete
                if let handler = self.onDownloadComplete{
                    
                    handler(self)
                    
                    self.task = nil
                }
            }
        })
        
        //each data receive progress
        self.task?.progress({ progress in
            
            self.status = .Downloading
            
            self.downloadProgress = Float(progress.completedUnitCount)/Float(progress.totalUnitCount)
            
            if let handler = self.onDownloadReceiveData{
                
                handler(self, self.downloadProgress)
            }
        })
         
        
    }
    
    func cancelDownload(){
        
        self.task?.cancel()
        self.status = .Cancel
        self.task = nil
        
        if let handler = self.onDownloadCancel{
            
            handler(self)
        }
    }
    
}