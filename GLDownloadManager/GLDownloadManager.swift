//
//  GLDownloadManager.swift
//  GLDownloadManager
//
//  Created by LeoGeng on 12/01/2017.
//  Copyright © 2017 LeoGeng. All rights reserved.
//

protocol GLDownloadManagerDelegate:NSObjectProtocol{
    func didFinshDownload(downloadModel:GLDownloadModel)
    func didDownloadFailed(downloadMode:GLDownloadModel,error:Error)
}

class GLDownloadManager: NSObject {
    private let sessionIdenfier = "GLDownloadManager.background.download"
    private let queueIdenfier = "GLDownloadManager.background.queue"
    
    private lazy var session:URLSession = {
        let config =  URLSessionConfiguration.background(withIdentifier:self.sessionIdenfier )
        config.httpMaximumConnectionsPerHost = self.taskCount
        
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    fileprivate var downloadModels:[GLDownloadModel]!

    var taskCount = 3
    var delegate:GLDownloadManagerDelegate?
    
    override init() {
        super.init()
        
        self.downloadModels = [GLDownloadModel]()
    }
    
    func  startDownload(fileName:String,fileUrl:String,destPath:String)  {
        let task = self.session.downloadTask(with: URL(string: fileUrl)!)
        
        let model = GLDownloadModel(fileName: fileName, fileUrl: fileUrl, destPath: destPath, sessionTask: task)
        self.downloadModels.append(model)
        
        task.resume()
    }
    
    func cancel()  {
        downloadModels.forEach(){ model in
            model.sessionTask.cancel()
        }
    }
}

extension GLDownloadManager:URLSessionDownloadDelegate{
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        print(error!.localizedDescription)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error,let model = self.getDownloadModel(task: task as! URLSessionDownloadTask) {
            self.delegate?.didDownloadFailed(downloadMode: model, error: error)
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
        let percent:Float = round(Float(totalBytesWritten)/Float(totalBytesExpectedToWrite) * 100)
        print("\(Thread.current):\(percent)%")
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let model = self.getDownloadModel(task: downloadTask) else{
            return
        }
        
        do {
            var isDir = ObjCBool(false)
            let exist = FileManager.default.fileExists(atPath: model.destPath, isDirectory: &isDir)
            
            if !exist {
                try FileManager.default.createDirectory(atPath: model.destPath, withIntermediateDirectories: false, attributes: nil)
            }else if !isDir.boolValue{
                try FileManager.default.removeItem(atPath: model.destPath)
                try FileManager.default.createDirectory(atPath: model.destPath, withIntermediateDirectories: false, attributes: nil)
            }
            
            let path = URL(fileURLWithPath: model.destPath).appendingPathComponent(model.fileName).appendingPathExtension("zip").path
            
            if FileManager.default.fileExists(atPath: path) {
                try FileManager.default.removeItem(atPath: path)
            }
            
            try FileManager.default.moveItem(atPath: location.path, toPath: path)
            self.delegate?.didFinshDownload(downloadModel: model)
        } catch  {
            print("\(error.localizedDescription)")
            self.delegate?.didDownloadFailed(downloadMode: model,error:error)
        }
    }
    
    
    private func getDownloadModel(task:URLSessionDownloadTask)->GLDownloadModel?{
        for (index,model) in self.downloadModels.enumerated() {
            if task.isEqual(model.destPath) {
                self.downloadModels.remove(at: index)
                return model
            }
        }
        
        return nil
    }
}
