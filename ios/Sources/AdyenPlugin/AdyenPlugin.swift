import Foundation
import Capacitor
import Adyen 

/**
 * Please read the Capacitor iOS Plugin Development Guide
 * here: https://capacitorjs.com/docs/plugins/ios
 */
@objc(AdyenPlugin)
public class AdyenPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "AdyenPlugin"
    public let jsName = "Adyen"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "initialize", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "isGooglePayAvailable", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "isApplePayAvailable", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "requestGooglePayment", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "requestApplePayment", returnType: CAPPluginReturnPromise)
    ]

    // Use lazy var for implementation to ensure bridge is available if needed later
    private lazy var implementation = Adyen(plugin: self)
    private var applePayCallbackId: String? // Keep track of the specific callback

    override public func load() {
        // You might perform early setup here if needed,
        // but initialization based on JS call is usually preferred.
        implementation.plugin = self // Ensure the plugin reference is set
    }

    @objc func initialize(_ call: CAPPluginCall) {
        implementation.initialize(call)
    }

    @objc func isGooglePayAvailable(_ call: CAPPluginCall) {
        implementation.isGooglePayAvailable(call)
    }

    @objc func isApplePayAvailable(_ call: CAPPluginCall) {
        implementation.isApplePayAvailable(call)
    }

    @objc func requestGooglePayment(_ call: CAPPluginCall) {
        implementation.requestGooglePayment(call)
    }

    // We need to save the call to resolve it asynchronously later in the delegate
    @objc func requestApplePayment(_ call: CAPPluginCall) {
        self.applePayCallbackId = call.callbackId
        call.save() // Use Capacitor's save/release mechanism
        implementation.requestApplePayment(call, callbackId: call.callbackId)
    }

    // Helper to get the root view controller - essential for presenting UI
    func getRootVC() -> UIViewController? {
        var window: UIWindow? = UIApplication.shared.delegate?.window ?? nil

        if window == nil {
            let scene: UIWindowScene? = UIApplication.shared.connectedScenes.first as? UIWindowScene
            window = scene?.windows.filter({$0.isKeyWindow}).first
            if window == nil {
                window = scene?.windows.first
            }
        }
        return window?.rootViewController
    }

    // Method to resolve the saved Apple Pay call from the implementation
    func resolveApplePayCall(_ result: JSObject) {
        if let callbackId = self.applePayCallbackId, let call = bridge?.savedCall(withID: callbackId) {
            call.resolve(result)
            bridge?.releaseCall(call)
            self.applePayCallbackId = nil
        }
    }

    // Method to reject the saved Apple Pay call from the implementation
    func rejectApplePayCall(_ message: String, _ error: Error? = nil) {
        if let callbackId = self.applePayCallbackId, let call = bridge?.savedCall(withID: callbackId) {
            call.reject(message, nil, error)
            bridge?.releaseCall(call)
            self.applePayCallbackId = nil
        }
    }
}