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

    var webView: WKWebView!
    var contentController: WKUserContentController?
    var requestQueue: [RequestOperation] = [RequestOperation]()
    var operationsQueued = 0
    var operationsStarted = 0
    var operationsCompleted = 0
    var operationsCompletedCallback: (() -> ())?
    var webViewPingTimer: NSTimer?
    var pingId: Int = 0
    
    deinit {
        webViewPingTimer?.invalidate()
        webViewPingTimer = nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        contentController = WKUserContentController()
        contentController?.addScriptMessageHandler(self, name: "continueHandler")
        
        let config = WKWebViewConfiguration()
        config.userContentController = contentController!
        
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 0, height: 0), configuration: config)
        webView.UIDelegate = self
        webView.loadHTMLString(getHtml(), baseURL: nil)
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
            self.webView.evaluateJavaScript("continueLongRunningProcess(\(dataRequestProcessId), \(queued));", completionHandler: { (result, error) in
                print("evaluateJavaScript completion handler for \(queued ? "queued" : "unqueued") DATA REQUEST for js operation \(dataRequestProcessId) done")
            })
        }
        
        if let networkRequestProcessId = message.body["networkRequestProcessId"] as? Int {
            print("requested network data for process id \(networkRequestProcessId)")
            self.webView.evaluateJavaScript("finishLongRunningProcess(\(networkRequestProcessId), \(queued));", completionHandler: { (result, error) in
                print("evaluateJavaScript completion handler for \(queued ? "queued" : "unqueued") NETWORK REQUEST for js operation \(networkRequestProcessId) done")
            })
        }
        
        if let completedProcessId = message.body["completedProcessId"] as? Int {
            print("completed process id \(completedProcessId)")
            self.operationsCompleted += 1
            
            if queued {
                dequeueAndSubmitNextRequest()
            }
            
            if self.operationsStarted == self.operationsCompleted {
                operationsCompletedCallback?()
                operationsCompletedCallback = nil
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
        
        for operationId in 1...3 {
            print("started process \(operationId)")
            self.operationsQueued += 1
            startSingleOperation(operationId, queued: false)
        }
    }
    
    private func startSingleOperation(operationId: Int, queued: Bool) {
        self.operationsStarted += 1
        self.webView.evaluateJavaScript("someLongRunningProcess(\(operationId), \(queued ? "true" : "false"));", completionHandler: { (result, error) in
            if let error = error {
                print("[evaluateJavaScript] \(queued ? "queued" : "unqueued") START js operation \(operationId) FAILED: \(error)")
            } else {
                print("[evaluateJavaScript] \(queued ? "queued" : "unqueued") START js operation \(operationId) done")
            }
        })
    }
    
    @IBAction func startWithProcessQueuing(sender: AnyObject) {
        operationsStarted = 0
        operationsCompleted = 0
        
        for operationId in 1...3 {
            self.operationsQueued += 1
            requestQueue.append(RequestOperation(operationId))
        }
        
        dequeueAndSubmitNextRequest()
    }
    
    @IBAction func webViewAttachedChanged(sender: UISwitch) {
        if sender.on {
            view.addSubview(webView!)
            print("WebView attached")
        } else {
            webView.removeFromSuperview()
            print("WebView detached")
        }
    }
    
    @IBAction func pingingEnabledChanged(sender: UISwitch) {
        if sender.on {
            startPings()
            print("Pinging started")
        } else {
            stopPings()
            print("Pinging stopped")
        }
    }
    
    @IBAction func printStats(sender: AnyObject) {
        print("")
        print("operations queued: \(operationsQueued)")
        print("operations started: \(operationsStarted)")
        print("operations completed: \(operationsCompleted)")
        print("")
    }
    
    func startWithNoProcessQueuing(withCallback callback: () -> ()) {
        operationsCompletedCallback = callback
        startWithNoProcessQueuing("")
    }
    
    func startWithProcessQueuing(withCallback callback: () -> ()) {
        operationsCompletedCallback = callback
        startWithProcessQueuing("")
    }
    
    func dequeueAndSubmitNextRequest() {
        if let requestOperation = self.requestQueue.first {
            self.requestQueue.removeFirst()
            
            print("started process \(requestOperation.operationId)")
            startSingleOperation(requestOperation.operationId, queued: true)
        }
    }
    
    func startPings() {
        webViewPingTimer = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: #selector(ViewController.pingWebView), userInfo: nil, repeats: true)
    }
    
    func stopPings() {
        webViewPingTimer?.invalidate()
        webViewPingTimer = nil
    }
    
    func pingWebView() {
        pingId += 1
        print("ping -> JS \(pingId)")
        self.webView.evaluateJavaScript("ping(\(pingId));", completionHandler: nil)
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
