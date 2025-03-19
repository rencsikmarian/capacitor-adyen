package com.matrix.adyen;

import android.app.Application;
import android.util.Log;
import android.app.Activity;

import androidx.activity.ComponentActivity;

import com.adyen.checkout.components.model.paymentmethods.PaymentMethod;
import com.getcapacitor.PluginCall;
import com.getcapacitor.JSObject;
import com.adyen.checkout.googlepay.GooglePayComponent;
import com.adyen.checkout.googlepay.GooglePayConfiguration;
import com.adyen.checkout.core.api.Environment;
import com.adyen.checkout.components.model.payments.Amount;
import com.google.android.gms.wallet.PaymentData;

public class Adyen {
    private static final String TAG = "Adyen Implemenation";
    private String environment;
    private String merchantAccount;
    private String clientKey;
    private String countryCode;
    private Amount amount;
    private String merchantName;

    public void initialize(PluginCall call) {
        try {
            String envString = call.getString("environment", "TEST");
            this.environment = String.valueOf("TEST".equals(envString) ? Environment.TEST : Environment.LIVE);
            this.merchantAccount = call.getString("merchantAccount");
            this.clientKey = call.getString("clientKey");
            this.countryCode = call.getString("countryCode", "US");
            this.merchantName = call.getString("merchantName", "");
            
            JSObject amountObj = call.getObject("amount");
            if (amountObj != null) {
                this.amount = new Amount();
                this.amount.setCurrency(amountObj.getString("currency", "USD"));
                int amount = amountObj.getInt("value");
                this.amount.setValue(amount);
            } else {
                this.amount = new Amount();
                this.amount.setCurrency("USD");
                this.amount.setValue(0);
            }

            Log.d(TAG, "Adyen initialized with environment: " + this.environment + ", merchantAccount: " + this.merchantAccount + ", clientKey: " + this.clientKey + ", countryCode: " + this.countryCode + ", merchantName: " + this.merchantName + ", amount: " + this.amount);
            call.resolve();
        } catch (Exception e) {
            Log.e(TAG, "Error initializing Adyen plugin: " + e.getMessage());
            call.reject("Error initializing Adyen plugin: " + e.getMessage());
        }
    }

    public void isGooglePayAvailable(PluginCall call, Activity activity, Application application) {

        try {
            JSObject ret = new JSObject();
            
            // Create GooglePay configuration
            GooglePayConfiguration config = new GooglePayConfiguration.Builder(activity, this.clientKey)
                .setCountryCode(this.countryCode)
                .setAmount(this.amount)
                .build();

            // Create PaymentMethod for Google Pay
            PaymentMethod paymentMethod = new PaymentMethod();
            paymentMethod.setType("googlepay");

            // Check if Google Pay is available
            GooglePayComponent.PROVIDER.isAvailable(application, paymentMethod, config, (isAvailable, appContext, conf) -> {
                ret.put("isAvailable", isAvailable);
                call.resolve(ret);
            });
            
        } catch (Exception e) {
            Log.e(TAG, "Error checking Google Pay availability", e);
            call.reject("Error checking Google Pay availability: " + e.getMessage());
        }
    }

    public void isApplePayAvailable(PluginCall call) {
        call.resolve(new JSObject().put("isAvailable", false));
    }

    public void requestGooglePayment(PluginCall call, Activity activity) {
        try {
            if (activity == null) {
                call.reject("Activity is null");
                return;
            }

            // Ensure we're on the main thread
            activity.runOnUiThread(() -> {
                try {
                    // Create GooglePay configuration
                    GooglePayConfiguration config = new GooglePayConfiguration.Builder(activity, this.clientKey)
                            .setCountryCode(this.countryCode)
                            .setMerchantAccount(this.merchantAccount)
                            .setAmount(this.amount)
                            .build();

                    // Create PaymentMethod for Google Pay
                    PaymentMethod paymentMethod = new PaymentMethod();
                    paymentMethod.setType("googlepay");

                    // Create GooglePay component
                    GooglePayComponent googlePayComponent = GooglePayComponent.PROVIDER.get(
                            (ComponentActivity) activity,
                            paymentMethod,
                            config
                    );

                    // Add payment listener on the main thread
                    googlePayComponent.observe((ComponentActivity) activity, googlePayState -> {
                        if (googlePayState == null) {
                            call.reject("Google Pay response is null");
                            return;
                        }

                        if (googlePayState.isValid()) {
                            // Extract the payment data
                            PaymentData paymentData = googlePayState.getPaymentData();
                            if (paymentData != null) {
                                JSObject result = new JSObject();
                                result.put("paymentData", paymentData.toJson());
                                call.resolve(result);
                            } else {
                                call.reject("Google Pay token is null");
                            }
                        } else {
                            call.reject("Google Pay payment is invalid");
                        }
                    });

                    // Start Google Pay payment flow
                    googlePayComponent.startGooglePayScreen(activity, 1100);

                } catch (Exception e) {
                    call.reject("Error processing Google Pay payment: " + e.getMessage());
                }
            });

        } catch (Exception e) {
            call.reject("Unexpected error: " + e.getMessage());
        }
    }

    public void requestApplePayment(PluginCall call) {
        call.reject("Apple Pay is not available on Android");
    }
}
