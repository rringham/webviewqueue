//
//  ViewController.swift
//  WebViewQueue
//
//  Created by Robert Ringham on 10/10/16.
//

import Foundation
import UIKit
import WebKit
import JavaScriptCore

class RequestOperation {
    var operationId: Int
    
    init(_ operationId: Int) {
        self.operationId = operationId
    }
}

class ViewController: UIViewController, WKScriptMessageHandler, WKUIDelegate {

    var webView: WKWebView?
    var contentController: WKUserContentController?
    var requestQueue: [RequestOperation] = [RequestOperation]()
    var operationsQueued = 0
    var operationsStarted = 0
    var operationsCompleted = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        contentController = WKUserContentController()
        contentController?.addScriptMessageHandler(self, name: "continueHandler")
        
        let config = WKWebViewConfiguration()
        config.userContentController = contentController!
        
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 0, height: 0), configuration: config)
        webView?.UIDelegate = self
        webView?.loadHTMLString(getHtml(), baseURL: nil)
//        view.addSubview(webView)
    }
    
    func webView(webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: () -> Void)
    {
        let alert = UIAlertController(title: message, message: nil, preferredStyle: UIAlertControllerStyle.Alert);
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Cancel) { _ in completionHandler()});
        self.presentViewController(alert, animated: true, completion: {});
    }
    
    func userContentController(userContentController: WKUserContentController, didReceiveScriptMessage message: WKScriptMessage) {
        var queued = false
        if let queuedParam = message.body["queued"] as? Bool {
            queued = queuedParam
        }
        
        if let dataRequestProcessId = message.body["dataRequestProcessId"] as? Int {
            print("requested data for process id \(dataRequestProcessId)")
            self.webView?.evaluateJavaScript("continueLongRunningProcess(\(dataRequestProcessId), \(queued));", completionHandler: { (result, error) in
                print("evaluateJavaScript completion handler for \(queued ? "queued" : "unqueued") DATA REQUEST for js operation \(dataRequestProcessId) done")
            })
        }
        
        if let networkRequestProcessId = message.body["networkRequestProcessId"] as? Int {
            print("requested data for process id \(networkRequestProcessId)")
            self.webView?.evaluateJavaScript("finishLongRunningProcess(\(networkRequestProcessId), \(queued));", completionHandler: { (result, error) in
                print("evaluateJavaScript completion handler for \(queued ? "queued" : "unqueued") NETWORK REQUEST for js operation \(networkRequestProcessId) done")
            })
        }
        
        if let completedProcessId = message.body["completedProcessId"] as? Int {
            print("completed process id \(completedProcessId)")
            self.operationsCompleted += 1
            
            if queued {
                dequeueAndSubmitNextRequest()
            }
        }
        
        if let pongId = message.body["pongId"] as? Int {
            print("pong <- JS \(pongId)")
        }
    }
    
    @IBAction func startWithNoProcessQueuing(sender: AnyObject) {
        operationsQueued = 0
        operationsStarted = 0
        operationsCompleted = 0
        
        for operationId in 1...10 {
            print("started process \(operationId)")
            self.operationsQueued += 1
            self.operationsStarted += 1
            self.webView?.evaluateJavaScript("someLongRunningProcess(\(operationId), false);", completionHandler: { (result, error) in
                print("evaluateJavaScript completion handler for unqueued START js operation \(operationId) done")
            })
        }
        
//        startPings()
    }
    
    @IBAction func startWithProcessQueuing(sender: AnyObject) {
        operationsStarted = 0
        operationsCompleted = 0
        
        for operationId in 1...10 {
            self.operationsQueued += 1
            requestQueue.append(RequestOperation(operationId))
        }
        
        dequeueAndSubmitNextRequest()
//        startPings()
    }
    
    @IBAction func printStats(sender: AnyObject) {
        print("")
        print("operations queued: \(operationsQueued)")
        print("operations started: \(operationsStarted)")
        print("operations completed: \(operationsCompleted)")
        print("")
    }
    
    func dequeueAndSubmitNextRequest() {
        if let requestOperation = self.requestQueue.first {
            self.requestQueue.removeFirst()
            
            print("started process \(requestOperation.operationId)")
            self.operationsStarted += 1
            self.webView?.evaluateJavaScript("someLongRunningProcess(\(requestOperation.operationId), true);", completionHandler: { (result, error) in
                print("evaluateJavaScript completion handler for queued START js operation \(requestOperation.operationId) done")
            })
        }
    }
    
    func startPings() {
        dispatch_async(dispatch_get_main_queue()) {
            for pingId in 1...100 {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(UInt64(pingId * 1000) * NSEC_PER_MSEC)), dispatch_get_main_queue(), { () -> Void in
                    print("ping -> JS \(pingId)")
                    self.webView?.evaluateJavaScript("ping(\(pingId));", completionHandler: nil)
                })
            }
        }
    }
    
    func getHtml() -> String {
        let fileLocation = NSBundle.mainBundle().pathForResource("poc", ofType: "html")!
        do {
            return try String(contentsOfFile: fileLocation)
        }
        catch {
            return ""
        }
    }
}
