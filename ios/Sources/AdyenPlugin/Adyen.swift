import Foundation
import PassKit
import Capacitor
import Adyen

public struct AdyenCoder {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()

    static func encode<T: Encodable>(_ value: T) throws -> [String: Any]? {
        let data = try encoder.encode(value)
        let jsonObject = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
        return jsonObject as? [String: Any]
    }
    
    // Decode from a Capacitor JSObject [String: Any]
    static func decode<T: Decodable>(_ dictionary: [String: Any], as type: T.Type) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: dictionary, options: [])
        return try decoder.decode(type, from: data)
    }
}

@objc public class Adyen: NSObject {
    weak var plugin: AdyenPlugin?
    private var merchantAccount: String = ""
    private var clientKey: String = ""
    private var environment: Environment = .test
    private var countryCode: String = "US"
    private var amount: Amount = Amount(value: 0, currencyCode: "USD")
    private var merchantName: String = ""
    private var merchantIdentifier: String = ""
    private var isInitialized = false
    // Keep Adyen context and component references
    private var apiContext: APIContext?
    private var adyenContext: AdyenContext?
    private var applePayComponent: ApplePayComponent?

    init(plugin: AdyenPlugin) {
        self.plugin = plugin
        super.init()
    }


    @objc public func initialize(_ call: CAPPluginCall) {
        guard let merchantAccount = call.getString("merchantAccount"), !merchantAccount.isEmpty else {
            call.reject("Missing required 'merchantAccount'")
            return
        }
        guard let clientKey = call.getString("clientKey"), !clientKey.isEmpty else {
            call.reject("Missing required 'clientKey'")
            return
        }
        // Merchant Identifier is required for Apple Pay
        guard let merchantIdentifier = call.getString("merchantIdentifier"), !merchantIdentifier.isEmpty else {
            call.reject("Missing required 'merchantIdentifier' for Apple Pay setup")
            return
        }

        self.merchantAccount = merchantAccount
        self.clientKey = clientKey
        self.merchantIdentifier = merchantIdentifier
        self.countryCode = call.getString("countryCode", "US")
        self.merchantName = call.getString("merchantName", "Your Merchant Name") // Provide a default or make required

        if let amountObj = call.getObject("amount") {
            let currency = amountObj["currency"] as? String ?? "USD"
            let value = amountObj["value"] as? Int ?? 0
            self.amount = Amount(value: value, currencyCode: currency)
        } else {
            self.amount = Amount(value: 0, currencyCode: "USD")
            print("Adyen Plugin Warning: Initializing with zero amount.")
        }

        let environmentString = call.getString("environment", "test").lowercased()
        // Ensure correct mapping to Adyen.Environment
        if environmentString.starts(with: "live") {
             self.environment = environmentString.contains("australia") ? .liveAustralia :
                        environmentString.contains("us") ? .liveUnitedStates :
                        environmentString.contains("apse") ? .liveApse :
                        .liveEurope
        } else {
            self.environment = .test
        }


        do {
            self.apiContext = try APIContext(environment: self.environment, clientKey: self.clientKey)
            // Payment can be updated later if needed per transaction
            let payment = Payment(amount: self.amount, countryCode: self.countryCode)
            self.adyenContext = AdyenContext(apiContext: self.apiContext!, payment: payment)

            self.isInitialized = true
            print("Adyen Plugin Initialized: \(environmentString), \(merchantAccount)")
            call.resolve()

        } catch {
            self.isInitialized = false
            call.reject("Error initializing Adyen APIContext: \(error.localizedDescription)")
        }
    }

    @objc public func isGooglePayAvailable(_ call: CAPPluginCall) {
        call.resolve(["isAvailable": false])
    }

    @objc public func requestGooglePayment(_ call: CAPPluginCall) {
        call.reject("Google Pay is not available on iOS")
    }

    @objc public func isApplePayAvailable(_ call: CAPPluginCall) {
        // No need to check isInitialized here, PKPaymentAuthorizationController works independently
        // However, ensure Merchant ID is configured in entitlements.

        // Basic check
        let canMakePayments = PKPaymentAuthorizationController.canMakePayments()

        // Check for specific card networks supported by your Adyen account & region
        // Common networks: .visa, .masterCard, .amex, .discover
        // Consult Adyen docs for networks supported via Apple Pay in your configuration
        let supportedNetworks: [PKPaymentNetwork] = [.visa, .masterCard, .amex]
        let canMakePaymentsWithNetwork = PKPaymentAuthorizationController.canMakePayments(usingNetworks: supportedNetworks)

        call.resolve(["isAvailable": canMakePayments && canMakePaymentsWithNetwork])
    }

    @objc public func requestApplePayment(_ call: CAPPluginCall, callbackId: String) {
        guard self.isInitialized, let adyenContext = self.adyenContext else {
            plugin?.rejectApplePayCall("Adyen Plugin not initialized or context missing.")
            return
        }

        // 1. Get ApplePayPaymentMethod from JS (originating from Adyen's /paymentMethods)
        guard let paymentMethodJson = call.getObject("paymentMethod"),
              let paymentMethod = try? AdyenCoder.decode(paymentMethodJson, as: ApplePayPaymentMethod.self) else {
            plugin?.rejectApplePayCall("Invalid or missing 'paymentMethod' data for Apple Pay.")
            return
        }

        // 2. Get Amount and other details for *this specific* transaction from JS call
        // Allow overriding the initialized amount/details per transaction
        let transactionAmount: Amount
        if let amountObj = call.getObject("amount") {
            let currency = amountObj["currency"] as? String ?? self.amount.currencyCode
            let value = amountObj["value"] as? Int ?? self.amount.value
            transactionAmount = Amount(value: value, currencyCode: currency)
        } else {
            transactionAmount = self.amount // Use initialized amount if not provided
        }
        
        // Update context with potentially new amount for this specific transaction
        //self.adyenContext?.payment?.amount = transactionAmount
        
        // Merchant name can also be passed per transaction if needed
        let transactionMerchantName = call.getString("merchantName", self.merchantName)

        do {
            // 3. Configure Apple Pay Component
            let summaryItems = [
                PKPaymentSummaryItem(label: transactionMerchantName,
                                     amount: NSDecimalNumber(value: Double(transactionAmount.value) / 100.0)) // Apple Pay uses decimal amount
                // Add more items like tax, discount, shipping if needed
            ]

            // Use the Adyen.ApplePayPayment structure
             let applePayPayment = try ApplePayPayment(countryCode: adyenContext.payment?.countryCode ?? self.countryCode,
                                                      currencyCode: transactionAmount.currencyCode,
                                                      summaryItems: summaryItems)

            let config = ApplePayComponent.Configuration(payment: applePayPayment,
                                                         merchantIdentifier: self.merchantIdentifier)
            // Add required billing/shipping fields if needed:
            // config.requiredBillingContactFields = [.postalAddress]
            // config.requiredShippingContactFields = [.postalAddress, .phoneNumber, .emailAddress]
            // config.shippingMethods = [...] // Define PKShippingMethods if applicable

            // 4. Create and Present Apple Pay Component
            let component = try ApplePayComponent(paymentMethod: paymentMethod,
                                                  context: adyenContext,
                                                  configuration: config)
            component.delegate = self // Handles final result (didSubmit/didFail)
            // Set applePayDelegate ONLY if you need advanced features like shipping updates (iOS 15+)
            if #available(iOS 15.0, *) {
                 component.applePayDelegate = self // Handles dynamic updates during payment sheet interaction
            }
            self.applePayComponent = component // Keep a reference

            // Present the Apple Pay sheet
            guard let rootVC = plugin?.getRootVC() else {
                plugin?.rejectApplePayCall("Could not get Root ViewController to present Apple Pay.")
                return
            }
            // Ensure presentation on main thread
            DispatchQueue.main.async {
                rootVC.present(component.viewController, animated: true, completion: nil)
            }

        } catch {
            plugin?.rejectApplePayCall("Error configuring Apple Pay: \(error.localizedDescription)")
        }
    }
}

// MARK: - PaymentComponentDelegate (Handles final success/failure)
extension Adyen: PaymentComponentDelegate {

    public func didSubmit(_ data: PaymentComponentData, from component: PaymentComponent) {
        print("Adyen Delegate: didSubmit from \(component.paymentMethod.name)")

        guard component is ApplePayComponent,
              let applePayDetails = data.paymentMethod as? ApplePayDetails else {
            // If other components use this delegate later, handle them here or log error
            print("Adyen Delegate Error: didSubmit called from non-ApplePay component or incorrect data format.")
            self.plugin?.rejectApplePayCall("Internal error: Unexpected payment component data received.")
            self.applePayComponent = nil // Clean up component reference
            return
        }

        do {
            let detailsJson = try AdyenCoder.encode(applePayDetails)

            var result = JSObject()
            result["paymentData"] = detailsJson
            result["storePaymentMethod"] = data.storePaymentMethod

            self.plugin?.resolveApplePayCall(result)

        } catch {
            // Handle encoding errors
            self.plugin?.rejectApplePayCall("Failed to encode Apple Pay payment details: \(error.localizedDescription)")
        }

        self.applePayComponent = nil
    }

    public func didFail(with error: Error, from component: PaymentComponent) {
        print("Adyen Delegate: didFail from \(component.paymentMethod.name) with error: \(error.localizedDescription)")

        self.plugin?.rejectApplePayCall("Apple Pay Failed: \(error.localizedDescription)", error)

        self.applePayComponent = nil
    }
}

// MARK: - ApplePayComponentDelegate (Handles updates DURING Apple Pay sheet interaction - Optional, iOS 15+)
@available(iOS 15.0, *)
extension Adyen: ApplePayComponentDelegate {
    // Implement these methods if you need to handle dynamic updates based on
    // shipping contact, shipping method, or coupon code changes.
    // For simple payments, these might not be necessary.

    public func didUpdate(contact: PKContact, for payment: ApplePayPayment, completion: @escaping (PKPaymentRequestShippingContactUpdate) -> Void) {
        print("ApplePay Delegate: didUpdate contact")
        // Example: Validate address, calculate shipping, update summary items
        // let newShippingMethods = ...
        // let newSummaryItems = ...
        // let errors: [Error]? = nil // or [yourValidationError]
        let update = PKPaymentRequestShippingContactUpdate(errors: nil, paymentSummaryItems: payment.summaryItems, shippingMethods: []) // Provide actual methods if used
        completion(update)
    }

    public func didUpdate(shippingMethod: PKShippingMethod, for payment: ApplePayPayment, completion: @escaping (PKPaymentRequestShippingMethodUpdate) -> Void) {
        print("ApplePay Delegate: didUpdate shippingMethod")
        // Example: Update summary items based on selected shipping method
        // let newSummaryItems = ... based on shippingMethod.amount
        let update = PKPaymentRequestShippingMethodUpdate(paymentSummaryItems: payment.summaryItems) // Provide updated items
        completion(update)
    }

    public func didUpdate(couponCode: String, for payment: ApplePayPayment, completion: @escaping (PKPaymentRequestCouponCodeUpdate) -> Void) {
        print("ApplePay Delegate: didUpdate couponCode")
        // Example: Validate coupon, update summary items with discount
        // let newSummaryItems = ...
        // let errors: [Error]? = nil // or [yourValidationError]
        let update = PKPaymentRequestCouponCodeUpdate(errors: nil, paymentSummaryItems: payment.summaryItems, shippingMethods: []) // Provide actual methods if used
        completion(update)
    }
}

// MARK: - PresentationDelegate (Not strictly needed if only using Apple Pay which presents itself)
// If you plan to add other Adyen components (like Card Component), you'll need this.
// extension Adyen: PresentationDelegate {
//     public func present(component: PresentableComponent) {
//         guard let rootVC = plugin?.getRootVC() else {
//             print("Adyen PresentationDelegate Error: Could not get Root ViewController.")
//             return
//         }
//         DispatchQueue.main.async {
//              rootVC.present(component.viewController, animated: true, completion: nil)
//         }
//     }
// }
