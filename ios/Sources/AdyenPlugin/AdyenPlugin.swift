import Foundation
import Capacitor

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
    private let implementation = Adyen()
    private var clientKey: String = ""
    private var merchantAccount: String = ""
    private var environment: Adyen.Environment = .test
    private var countryCode: String = "US"
    private var amount: Adyen.Amount = Adyen.Amount(value: 0, currencyCode: "USD")
    private var merchantName: String = ""
    private var merchantIdentifier: String = ""
    private var dropInComponent: DropInComponent?

    @objc func initialize(_ call: CAPPluginCall) {
        let envString = call.getString("environment", "TEST")
        self.environment = envString == "TEST" ? .test : .live
        
        guard let merchantAccount = call.getString("merchantAccount") else {
            call.reject("Missing merchantAccount")
            return
        }
        self.merchantAccount = merchantAccount
        
        guard let clientKey = call.getString("clientKey") else {
            call.reject("Missing clientKey")
            return
        }
        self.clientKey = clientKey
        
        self.countryCode = call.getString("countryCode", "US")
        self.merchantName = call.getString("merchantName", "")
        self.merchantIdentifier = call.getString("merchantIdentifier", "")
        
        if let amountObj = call.getObject("amount") {
            let currency = amountObj["currency"] as? String ?? "USD"
            let value = amountObj["value"] as? Int ?? 0
            self.amount = Adyen.Amount(value: value, currencyCode: currency)
        }
        
        call.resolve()
    }
    
    @objc func isGooglePayAvailable(_ call: CAPPluginCall) {
        // Not applicable on iOS, but we need to implement it
        call.resolve([
            "isAvailable": false
        ])
    }
    
    @objc func isApplePayAvailable(_ call: CAPPluginCall) {
        let isAvailable = PKPaymentAuthorizationViewController.canMakePayments()
        call.resolve([
            "isAvailable": isAvailable
        ])
    }
    
    @objc func requestGooglePayment(_ call: CAPPluginCall) {
        // Not applicable on iOS, but we need to implement it
        call.reject("Google Pay is not available on iOS")
    }
    
    @objc func requestApplePayment(_ call: CAPPluginCall) {
        guard let totalPrice = call.getString("totalPrice") else {
            call.reject("Missing totalPrice")
            return
        }
        
        let currencyCode = call.getString("currencyCode", "USD")
        let merchantName = call.getString("merchantName", self.merchantName)
        
        // Create payment request
        let applePayComponent = try? ApplePayComponent(
            paymentMethod: ApplePayPaymentMethod(),
            payment: Payment(
                amount: amount,
                countryCode: countryCode
            ),
            merchantIdentifier: merchantIdentifier
        )
        
        guard let applePayComponent = applePayComponent else {
            call.reject("Failed to initialize Apple Pay component")
            return
        }
        
        // Get summary items
        var summaryItems: [PKPaymentSummaryItem] = []
        if let items = call.getArray("summaryItems") as? [[String: Any]] {
            for item in items {
                guard let label = item["label"] as? String,
                      let amountString = item["amount"] as? String,
                      let amountValue = Double(amountString) else {
                    continue
                }
                
                let type: PKPaymentSummaryItemType = (item["type"] as? String == "pending") ? .pending : .final
                let itemAmount = NSDecimalNumber(value: amountValue)
                let summaryItem = PKPaymentSummaryItem(label: label, amount: itemAmount, type: type)
                summaryItems.append(summaryItem)
            }
        }
        
        // Set default total if no summary items provided
        if summaryItems.isEmpty {
            let totalAmount = NSDecimalNumber(string: totalPrice)
            let totalItem = PKPaymentSummaryItem(label: merchantName, amount: totalAmount, type: .final)
            summaryItems.append(totalItem)
        }
        
        // Configure Apple Pay
        applePayComponent.summaryItems = summaryItems
        
        // Set merchant capabilities
        var capabilities: PKMerchantCapability = .capability3DS
        if let merchantCapabilities = call.getArray("merchantCapabilities") as? [String] {
            for capability in merchantCapabilities {
                if capability == "debit" {
                    capabilities.insert(.debit)
                } else if capability == "credit" {
                    capabilities.insert(.credit)
                }
            }
        }
        applePayComponent.merchantCapabilities = capabilities
        
        // Set supported networks
        if let supportedNetworks = call.getArray("supportedNetworks") as? [String] {
            var networks: [PKPaymentNetwork] = []
            
            for network in supportedNetworks {
                switch network.lowercased() {
                case "visa":
                    networks.append(.visa)
                case "mastercard":
                    networks.append(.masterCard)
                case "amex":
                    networks.append(.amex)
                case "discover":
                    networks.append(.discover)
                default:
                    break
                }
            }
            
            if !networks.isEmpty {
                applePayComponent.supportedNetworks = networks
            }
        }
        
        // Set shipping and billing contact fields required
        if call.getBool("shippingContact", false) {
            applePayComponent.requiredShippingContactFields = [.postalAddress, .name, .phoneNumber, .emailAddress]
        }
        
        if call.getBool("billingContact", false) {
            applePayComponent.requiredBillingContactFields = [.postalAddress, .name]
        }
        
        // Present Apple Pay
        DispatchQueue.main.async {
            applePayComponent.delegate = self
            applePayComponent.viewController = self.bridge?.viewController
            
            applePayComponent.startPayment { [weak self] result, component in
                guard let self = self else { return }
                
                switch result {
                case .success(let result):
                    let resultData: [String: Any] = [
                        "success": true,
                        "token": result.paymentMethod.encodedToken,
                        "paymentData": result.paymentMethod.checkoutAttemptId ?? ""
                    ]
                    
                    call.resolve(resultData as [AnyHashable : Any])
                    
                case .failure(let error):
                    call.reject("Apple Pay error: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - ApplePayComponentDelegate
extension AdyenPlugin: ApplePayComponentDelegate {
    public func didSubmit(_ applePayToken: PKPaymentToken, from component: ApplePayComponent, completion: @escaping (Bool) -> Void) {
        // We just return true since we handle the token in the callback above
        completion(true)
    }
    
    public func didFail(with error: Error, from component: ApplePayComponent) {
        // Error is handled in the callback above
    }
}
