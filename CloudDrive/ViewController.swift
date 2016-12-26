//
//  ViewController.swift
//  CloudDrive
//
//  Created by Nelson on 12/17/16.
//  Copyright © 2016 Nelson. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var data : [CloudDriveMetadata]? {
        
        didSet{
            
            self.tableView?.reloadData()
        }
    }
    
    @IBOutlet weak var tableView : UITableView?
    @IBOutlet weak var goBackBtn : UIBarButtonItem?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        super.viewDidAppear(animated)
        
        self.title = "Cloud Files"
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func showContentInPath(path:String = ""){
        
        let newPath = path == "" ? CloudDriveManager.shareInstance.rootPathOfCloudDrive() : path
        CloudDriveManager.shareInstance.listContentInPath(path: newPath, completeHandler: { result, error in
            
            guard error == nil else {
                
                return
            }
            
            if let data = result{
                
                self.data = data
            }
            else{
                self.data = nil
            }
            
        })
    }
    
    @IBAction func onBack(){
        
        showContentInPath(path: CloudDriveManager.shareInstance.previousPath)
    }
    
    @IBAction func logout(){
        
        if CloudDriveManager.shareInstance.hasDownloadTaskForDriveType(driveType: CloudDriveManager.shareInstance.driveType){
            
            let controller = UIAlertController(title: "Logout", message: "Logout \(CloudDriveManager.shareInstance.driveTypeString) will cancel all related download task. Do you want to logout?", preferredStyle: .alert)
            
            let cancelAction = UIAlertAction(title: "NO", style: .cancel, handler: nil)
            let okAction = UIAlertAction(title: "YES", style: .default, handler: { action in
                
                CloudDriveManager.shareInstance.logout()
                self.data = nil
            })
            
            controller.addAction(okAction)
            controller.addAction(cancelAction)
            
            self.present(controller, animated: true, completion: nil)

        } else {
            
            CloudDriveManager.shareInstance.logout()
            self.data = nil
        }
        
    }

    @IBAction func openDrive(){
        
        let alertController = UIAlertController(title: "Cloud Drive", message: "Pick Drive", preferredStyle: .actionSheet)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .destructive) { action in
            
            self.dismiss(animated: true, completion: { 
                
            })
        }
        
        let dropboxAction = UIAlertAction(title: "DropBox", style: .default) { action in
            
            CloudDriveManager.shareInstance.onDirectoryPathChanged = {currentPath, isRoot in
            
                self.goBackBtn?.isEnabled = !isRoot
                
            }
            
            CloudDriveManager.shareInstance.driveType = .DropBox
            CloudDriveManager.shareInstance.startAuth(inController: self) { state in
                
                switch state{
                    
                case .Success:
                    
                    NSLog("log in successful")
                    self.showContentInPath()
                    break
                case .Cancel:
                    
                    NSLog("user cancel log in")
                    break
                case .Error(let msg):
                    
                    NSLog("log in error \(msg)")
                    break
                }
            }
            
        }
        
        let googleDriveAction = UIAlertAction(title: "GoogleDrive", style: .default) { action in
            
            CloudDriveManager.shareInstance.onDirectoryPathChanged = {currentPath, isRoot in
                
                self.goBackBtn?.isEnabled = !isRoot
                
            }
            
            CloudDriveManager.shareInstance.driveType = .GoogleDrive
            CloudDriveManager.shareInstance.startAuth(inController: self) { state in
                
                switch state{
                    
                case .Success:
                    
                    NSLog("log in successful")
                    self.showContentInPath()
                    break
                case .Cancel:
                    
                    NSLog("user cancel log in")
                    break
                case .Error(let msg):
                    
                    NSLog("log in error \(msg)")
                    break
                }
            }
            
        }
        
        alertController.addAction(dropboxAction)
        alertController.addAction(googleDriveAction)
        alertController.addAction(cancelAction)
        
        self.present(alertController, animated: true) { 
            
        }
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return self.data != nil ? (data?.count)! : 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cellId = "ItemCell"
    
        var cell = tableView.dequeueReusableCell(withIdentifier: cellId)
        
        if cell == nil {
            
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: cellId)
        }
        
        let metadata : CloudDriveMetadata = (data?[indexPath.row])!
        
        cell?.textLabel?.text = metadata.name
        cell?.detailTextLabel?.text = metadata.isFolder ? "Folder" : "File"
        
        return cell!
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        let item : CloudDriveMetadata = (data?[indexPath.row])!
        
        if item.isFolder {
            
            showContentInPath(path: CloudDriveManager.shareInstance.appendingPathComponent(path: item.underPath, component: item.name))
        }
        else {
            
            let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
            
            let localFilePath = (documentsPath as NSString).appendingPathComponent(item.name)
            let filePath = CloudDriveManager.shareInstance.appendingPathComponent(path: item.underPath, component: item.name)
            
            CloudDriveManager.shareInstance.downloadFileFromPath(path: filePath, localPath: localFilePath, resultHandler: { task, error in
                
                if let err = error{
                    
                    var errorMsg = ""
                    
                    switch err{
                        
                    case .CloudDriveDownloadExist:
                        errorMsg = "This file is already in download queue"
                        break
                    default:
                        break
                    }
                    
                    let controller = UIAlertController(title: "Error", message: errorMsg, preferredStyle: .alert)
                    
                    let cancelAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
                    
                    controller.addAction(cancelAction)
                    
                    self.present(controller, animated: true, completion: nil)
                    
                    
                    
                }
            })
        }
    }
}

