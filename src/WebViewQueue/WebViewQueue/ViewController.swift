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

class ViewController: UIViewController, WKScriptMessageHandler, WKUIDelegate {

    private var context: JSContext! = JSContext()
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
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1, height: 1), configuration: config)
        webView.UIDelegate = self
        webView.loadHTMLString(getHtml(), baseURL: nil)
        view.addSubview(webView)
        
        context.setObject(Test.self, forKeyedSubscript: "Test")
        context.exceptionHandler = { context, exception in
            print("JS Error: \(exception)")
        }
        context.evaluateScript(getJS())
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
        
        for i in 1...10 {
            print("starting main js operation \(i)")
            self.operationsStarted += 1
            self.webView.evaluateJavaScript("someLongRunningProcess(100, \(i));", completionHandler: { (result, error) in
                print("evaluateJavaScript completion handler for main js operation \(i) done")
            })
        }
        
        for _ in 1...100 {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(UInt64(1) * NSEC_PER_MSEC)), dispatch_get_main_queue(), { () -> Void in
                print("pinging JS")
                self.webView.evaluateJavaScript("ping();", completionHandler: nil)
            })
        }
    }
    
    @IBAction func hammerJavaScriptCore(sender: AnyObject) {
        dispatch_async(dispatch_get_main_queue(), {
            for i in 1...10 {
                dispatch_async(dispatch_get_main_queue(), {
                    print("starting main js operation \(i)")
                    self.operationsStarted += 1
                    self.context.evaluateScript("someLongRunningProcess(\(i));")
                })
            }
        })
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
    
    func getJS() -> String {
        let fileLocation = NSBundle.mainBundle().pathForResource("poc", ofType: "js")!
        do {
            return try String(contentsOfFile: fileLocation)
        }
        catch {
            return ""
        }
    }
}

// JSCore setTimeout http://stackoverflow.com/questions/15991044/ios-implemention-of-window-settimeout-with-javascriptcore
@objc protocol TestJSExports : JSExport {
    static func setTimeout(_ cb: JSValue, _ wait: Int) -> ()
    static func test(result: String) -> ()
}

@objc class Test : NSObject, TestJSExports {
    class func setTimeout(_ cb: JSValue, _ wait: Int) -> () {
        let callback = cb as JSValue
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(UInt64(wait) * NSEC_PER_MSEC)), dispatch_get_main_queue(), { () -> Void in
            callback.callWithArguments([])
        })
    }
    
    class func test(result: String) -> () {
        print("pid \(result) callback")
    }
}

