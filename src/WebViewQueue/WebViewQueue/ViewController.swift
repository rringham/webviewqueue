//
//  ViewController.swift
//  WebViewQueue
//
//  Created by Robert Ringham on 10/10/16.
//

import Foundation
import UIKit
import WebKit

class ViewController: UIViewController, WKScriptMessageHandler, WKUIDelegate {

    private var webView: WKWebView!
    private var contentController: WKUserContentController!
    var operationsStarted = 0
    var operationsCompleted = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let config = WKWebViewConfiguration()
        contentController = WKUserContentController()
        contentController.addScriptMessageHandler(self, name: "continueHandler")
        config.userContentController = contentController
        webView = WKWebView(
            frame: self.view.frame,
            configuration: config
        )
        webView.UIDelegate = self
        webView.loadHTMLString(getHtml(), baseURL: nil)
    }
    
    func webView(webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: () -> Void) {
        let alert = UIAlertController(title: message, message: nil, preferredStyle: UIAlertControllerStyle.Alert);
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Cancel) { _ in completionHandler()});
        self.presentViewController(alert, animated: true, completion: {});
    }
    
    func userContentController(userContentController: WKUserContentController, didReceiveScriptMessage message: WKScriptMessage) {
        guard let pid = message.body["pid"] as? Int else {
            return
        }
        print("pid \(pid) callback")
        self.operationsCompleted += 1
    }
    
    @IBAction func hammerWebView(sender: AnyObject) {
        operationsStarted = 0
        operationsCompleted = 0
        
        // approach 1: async dispatch, interleaved request queuing
        // result: all complete successfully, no WKWebView hang
        //
        /*for i in 1...20 {
            dispatch_async(dispatch_get_main_queue(), {
                print("starting main js operation \(i)")
                self.operationsStarted += 1
                self.webView.evaluateJavaScript("someLongRunningProcess(2000, \(i));", completionHandler: { (result, error) in
                    print("evaluateJavaScript completion handler for main js operation \(i) done")
                    
                    for j in 1...20 {
                        dispatch_async(dispatch_get_main_queue(), {
                            print("    starting interleaved js operation \(j)")
                            self.operationsStarted += 1
                            self.webView.evaluateJavaScript("someLongRunningProcess(2000, \(j));", completionHandler: { (result, error) in
                                print("    evaluateJavaScript completion handler for interleaved js operation \(j) done")
                            })
                        })
                    }
                })
            })
        }*/
        
        // approach 2: serial request queuing
        // result: all complete successfully, no WKWebView hang
        //
        for i in 1...100 {
            print("starting main js operation \(i)")
            self.operationsStarted += 1
            self.webView.evaluateJavaScript("someLongRunningProcess(3000, \(i));", completionHandler: { (result, error) in
                print("evaluateJavaScript completion handler for main js operation \(i) done")
            })
        }
    }
    
    @IBAction func stats(sender: AnyObject) {
        print("operations started: \(operationsStarted)")
        print("operations completed: \(operationsCompleted)")
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

