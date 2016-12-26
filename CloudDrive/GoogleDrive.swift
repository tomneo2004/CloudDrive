//
//  GoogleDrive.swift
//  CloudDrive
//
//  Created by Nelson on 12/23/16.
//  Copyright © 2016 Nelson. All rights reserved.
//

import Foundation
import UIKit
import GTMOAuth2
import AppAuth
import GTMAppAuth
import GTMSessionFetcher
import GTMSessionFetcher.GTMSessionFetcherService
import GoogleAPIClient

let GoogleClientId = "GoogleClientID"
class GoogleDrive : CloudDrive, CloudDriveProtocol, OIDAuthStateChangeDelegate, OIDAuthStateErrorDelegate{

    
    private let issuer = "https://accounts.google.com"
    private let driveScope = "https://www.googleapis.com/auth/drive"
    private let keychainItemName = "GoogleDriveAPI"
    private var clientId = "CLIENT_ID.googleusercontent.com"
    private var redirectURI = "com.googleusercontent.apps.CLIENT_ID:/oauthredirect"
    //private let googleAuthURL = "https://accounts.google.com/o/oauth2/auth"
    //private let googleTokenURL = "https://accounts.google.com/o/oauth2/token"
    
    private var authorization : GTMAppAuthFetcherAuthorization?
    private var driveService : GTLServiceDrive = GTLServiceDrive()
    private var authFlow : Any?
    
    /**
     Start google drive service
     
     Return true successful otherwise false
    */
    private func startGoogleDriveService() -> Bool{
        
        
        if let credential = self.authorization{
            
            driveService.authorizer = credential
            
            return true
        }
        
        return false
    }
    
    /**
     Load authorized state
     
     Return true if auth state loaded otherwise false
    */
    private func loadAuthState() ->Bool{
        
        if let savedAuth = GTMAppAuthFetcherAuthorization.init(fromKeychainForName: self.keychainItemName){
            
            self.authorization = savedAuth
            self.saveAuthState()
            return true
        }
        
        return false
        
        
    }
    
    private func saveAuthState(){
        
        if self.authorization == nil{
            
            GTMAppAuthFetcherAuthorization.removeFromKeychain(forName: self.keychainItemName)
            
            return
        }
        
        if (self.authorization?.canAuthorize())!{
            
            GTMAppAuthFetcherAuthorization.save(self.authorization!, toKeychainForName: self.keychainItemName)
            
        } else {
            
            GTMAppAuthFetcherAuthorization.removeFromKeychain(forName: self.keychainItemName)
        }
    }
    
    private func setAuthorization(auth:GTMAppAuthFetcherAuthorization?){
        
        self.authorization = auth
        self.saveAuthState()
    }
    
    private func setupClientID(){
        
        let path = Bundle.main.path(forResource: "Info", ofType: "plist")
        let dic = NSDictionary(contentsOfFile: path!)
        let clientId = dic?[GoogleClientId]
        
        assert(clientId != nil, "No app key for DropBox. In Info.plist add \(GoogleClientId) as key and [YourGoogleClientID] as string value")
        
        self.clientId = "\(clientId as! NSString).apps.googleusercontent.com"
    }
    
    private func setupRedirectURL(){
        
        let path = Bundle.main.path(forResource: "Info", ofType: "plist")
        let dic = NSDictionary(contentsOfFile: path!)
        let clientId = dic?[GoogleClientId]
        
        assert(clientId != nil, "No app key for DropBox. In Info.plist add \(GoogleClientId) as key and [YourGoogleClientID] as string value")
        
        self.redirectURI = "com.googleusercontent.apps.\(clientId as! NSString):/oauthredirect"
    }
    
    private func verifiesURLSchemes(){
        
        // verifies that the custom URI scheme has been updated in the Info.plist
        let urlTypes : [AnyObject] = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as! [AnyObject]
        assert(urlTypes.count > 0, "No custom URI scheme has been configured for Google for the project.")
        let urlSchemes : [AnyObject] = urlTypes.first?["CFBundleURLSchemes"] as! [AnyObject]
        assert(urlSchemes.count > 0, "No custom URI scheme has been configured for Google for the project.")
        
        
        var urlScheme : String? = nil
        
        for item in urlSchemes{
            
            if (item as! String).hasPrefix("com.googleusercontent.apps"){
                
                urlScheme = item as? String
                
                break
            }
        }
        
        assert(urlScheme != nil, "Configure the URI scheme in Info.plist (URL Types -> Item 0 -> URL Schemes -> Item 0) and give your client ID e.g: com.googleusercontent.apps.YOUR_CLIENT")

    }
    
    /**
     Start authorize process
     */
    func authorize(inController:UIViewController){
        
        self.verifiesURLSchemes()
        self.setupClientID()
        self.setupRedirectURL()
        
        if self.loadAuthState(){
            
            if self.startGoogleDriveService(){
                
                if let handler = self.authCompleteHandler{
                    
                    handler(CloudDriveAuthState.Success)
                }
            } else {
                
                if let handler = self.authCompleteHandler{
                    
                    handler(CloudDriveAuthState.Error("Unable to start google dirve service"))
                }
            }
            
            return
        }
        
        let issuerURL = URL(string: self.issuer)
        let redirectURL = URL(string: self.redirectURI)
        
        OIDAuthorizationService.discoverConfiguration(forIssuer: issuerURL!) { configuation, error in
            
            if (configuation == nil) {
                
                self.setAuthorization(auth: nil)
                
                if let handler = self.authCompleteHandler{
                    
                    handler(CloudDriveAuthState.Error("Google service configuration not found"))
                }
                
                return
            }
            
            let authRequest : OIDAuthorizationRequest = OIDAuthorizationRequest.init(configuration: configuation!, clientId: self.clientId, scopes: [OIDScopeOpenID, self.driveScope], redirectURL: redirectURL!, responseType: OIDResponseTypeCode, additionalParameters: nil)
            
            self.authFlow = OIDAuthState.authState(byPresenting: authRequest, presenting: inController, callback: { authState, error in
                
                if authState != nil{
                    
                    #if DEBUG
                        print("google drive access token: \(authState?.lastTokenResponse?.accessToken)")
                    #endif
                    
                    let auth = GTMAppAuthFetcherAuthorization.init(authState: authState!)
                    self.setAuthorization(auth: auth)
                    
                    if self.startGoogleDriveService(){
                        
                        if let handler = self.authCompleteHandler{
                            
                            handler(CloudDriveAuthState.Success)
                        }
                    } else {
                        
                        if let handler = self.authCompleteHandler{
                            
                            handler(CloudDriveAuthState.Error("Unable to start google dirve service"))
                        }
                    }
                    
                } else {
                    
                    self.setAuthorization(auth: nil)
                    
                    if let handler = self.authCompleteHandler{
                        
                        handler(CloudDriveAuthState.Error(error as! String))
                    }
                }
            })
        }
    }
    
    /**
     Get list of data at path
     */
    func contentsAtPath(path:String, complete:(([CloudDriveMetadata]?, CloudDriveError?)->())?){
        
        let query = GTLQueryDrive.queryForFilesList()
        query?.restrictToMyDrive = true
        query?.includeRemoved = false
        query?.includeDeleted = false
        query?.q = "'0ByNb_6ANzXiLOUlaTHJSZGU4aGc' in parents and trashed=false"
        
        self.driveService.executeQuery(query!) { ticket, result, error in
            
            if error != nil{
                
                if let handler = complete{
                    
                    print(error)
                    handler(nil, CloudDriveError.CloudDriveInternalError(error as! String))
                }
            }
            else {
                
                let fileLists : GTLDriveFileList = result as! GTLDriveFileList
                
                for f in fileLists.files{
                    
                    print("file: \(f)")
                    print("\n")
                }
            }
        }
    }
    
    /**
     Return type of cloud drive
     */
    func driveType() -> CloudDriveType{
        
        return .GoogleDrive
    }
    
    /**
     Return type of cloud drive in string
     */
    func driveTypeString() -> String{
        
        return "GoogleDrive"
    }
    
    /**
     Return root path
     */
    func rootPath() -> String{
        
        return "'root' in parents"
    }
    
    /**
     Return new appending path
     */
    func appendingPathComponent(currentPath:String, component:String) -> String{
        
        if currentPath == rootPath(){
            
            return ("root" as NSString).appendingPathComponent(component)
        }
        
        return (currentPath as NSString).appendingPathComponent(component)
    }
    
    /**
     Return new deleting last path
     */
    func deletingLastPathComponent(path:String) -> String{
        
        let removedPath = (path as NSString).deletingLastPathComponent
        
        if removedPath == rootPath() || removedPath == ""{
            
            return self.rootPath()
        }
        
        return removedPath
    }
    
    /**
     Return a new download task
     */
    func createDownloadTask(path:String, localPath:String) -> CloudDriveDownloadTask{
        
        let download = DropBoxDownload(type: .GoogleDrive, path: path, localPath: localPath)
        
        return download
    }
    
    /**
     Logout
     */
    func logout(){
        
        self.setAuthorization(auth: nil)
    }
    
    //MARK:Override from CloudDrive
    override func handleRedirect(url:URL){
        
        // Sends the URL to the current authorization flow (if any) which will process it if it relates to
        // an authorization response.
        if let flow = self.authFlow{
            
            (flow as! OIDAuthorizationFlowSession).resumeAuthorizationFlow(with: url)
            self.authFlow = nil
        }
    }
    
    override func cloudName() -> String{
        
        return "Google"
    }
    
    //MARK: Google authorization delegate
    func didChange(_ state: OIDAuthState) {
        
        self.saveAuthState()
    }
    
    func authState(_ state: OIDAuthState, didEncounterAuthorizationError error: Error) {
        
        if let handler = authCompleteHandler{
            
            handler(CloudDriveAuthState.Error(error as! String))
        }
    }
}

//MARK:DropBoxDownload class
class GoogleDriveDownload : CloudDriveDownloadTask, CloudDriveDownloadProtocol{
    
    override func driveTypeString() -> String{
        
        return "GoogleDrive"
    }
    
    func startDownload(){
        
    }
    
    func cancelDownload() {
        
    }
}
