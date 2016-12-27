//
//  DownloadViewController.swift
//  CloudDrive
//
//  Created by Nelson on 12/22/16.
//  Copyright © 2016 Nelson. All rights reserved.
//

import Foundation
import UIKit

class DownloadViewController : UIViewController, UITableViewDelegate, UITableViewDataSource{
    
    @IBOutlet weak var tableView : UITableView?
    
    @IBInspectable var completeColor : UIColor?
    @IBInspectable var errorColor : UIColor?
    @IBInspectable var cancelColor : UIColor?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.title = "Download"
        
        CloudDriveManager.shareInstance.autoCleanDownloadTask = false
        
        CloudDriveManager.shareInstance.onDownloadBegin = {task in
        
            
            if let index = CloudDriveManager.shareInstance.allDownloadTasks.index(of: task){
                
                self.tableView?.beginUpdates()
                
                self.tableView?.insertRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
                
                self.tableView?.endUpdates()
            }
 
            
        }
        
        CloudDriveManager.shareInstance.onDownloadStarted = {task in
        
            
        }
        
        CloudDriveManager.shareInstance.onDownloadReceivedData = {task, progress in
        
            self.tableView?.reloadData()
        }
        
        CloudDriveManager.shareInstance.onDownloadComplete = {task in
        
            
            self.tableView?.reloadData()
            
        }
        
        CloudDriveManager.shareInstance.onDownloadEnd = {task, index in
        
            self.tableView?.beginUpdates()
            
            self.tableView?.deleteRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
            
            self.tableView?.endUpdates()
        }
        
        CloudDriveManager.shareInstance.onDownloadCancel = {task in
        
            
            self.tableView?.reloadData()
        }
        
        CloudDriveManager.shareInstance.onDownloadError = {task, error in
            
            
            self.tableView?.reloadData()
        
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return CloudDriveManager.shareInstance.allDownloadTasks.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cellId = "DownloadCell"
        
        let task = CloudDriveManager.shareInstance.allDownloadTasks[indexPath.row]
        
        if let cell = tableView.dequeueReusableCell(withIdentifier: cellId){
            
            return configureCell(cell: cell as! DownloadCell, task: task)
        }
        
        let cell = DownloadCell()
        
        return configureCell(cell: cell, task: task)
    }
    
    func configureCell(cell : DownloadCell, task:CloudDriveDownloadTask) -> DownloadCell{
        
        cell.filenameLable?.text = task.fileName
        cell.progressView?.progress = task.downloadProgress
        
        switch task.status {
        case .Downloading:
            cell.statusLabel?.text = task.downloadProgress < 0 ? "Unknow progress" : "\(UInt(task.downloadProgress * 100.0))%"
        case .Complete:
            cell.statusLabel?.text = "Download complete"
            cell.statusLabel?.textColor = self.completeColor
            
        case .Cancel:
            cell.statusLabel?.text = "Download cancel"
            cell.statusLabel?.textColor = self.cancelColor
            
        case .Error:
            cell.statusLabel?.text = "Download error"
            cell.statusLabel?.textColor = self.errorColor
            
        default:
            cell.statusLabel?.text = "0%"
            cell.statusLabel?.textColor = UIColor.black
        }
        
        cell.cloudDriveLabel?.text = task.driveTypeString()
        
        
        return cell
    }
}

class DownloadCell : UITableViewCell{
    
    @IBOutlet weak var filenameLable : UILabel?
    @IBOutlet weak var progressView : UIProgressView?
    @IBOutlet weak var statusLabel : UILabel?
    @IBOutlet weak var cloudDriveLabel : UILabel?
    
    override func prepareForReuse() {
        
        
    }
}
