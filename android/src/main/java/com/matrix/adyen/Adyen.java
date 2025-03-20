package com.matrix.adyen;

import android.app.Application;
import android.content.Intent;
import android.util.Log;
import android.app.Activity;

import androidx.fragment.app.FragmentActivity;

import com.adyen.checkout.components.model.paymentmethods.PaymentMethod;
import com.getcapacitor.Bridge;
import com.getcapacitor.PluginCall;
import com.getcapacitor.JSObject;
import com.adyen.checkout.googlepay.GooglePayComponent;
import com.adyen.checkout.googlepay.GooglePayConfiguration;
import com.adyen.checkout.components.model.payments.Amount;
import com.google.android.gms.wallet.PaymentData;

public class Adyen {
    private static final String TAG = "Adyen Implemenation";
    private GooglePayComponent googlePayComponent;
    private String merchantAccount;
    private String clientKey;
    private String countryCode;
    private Amount amount;
    private boolean isInitialized = false;

    public void initialize(PluginCall call) {
        try {
            this.merchantAccount = call.getString("merchantAccount");
            this.clientKey = call.getString("clientKey");
            this.countryCode = call.getString("countryCode", "US");
            
            JSObject amountObj = call.getObject("amount");
            String defaultCurrency = "EURO";
            if (amountObj != null) {
                this.amount = new Amount();
                this.amount.setCurrency(amountObj.getString("currency", defaultCurrency));
                int amount = amountObj.getInt("value");
                this.amount.setValue(amount);
            } else {
                this.amount = new Amount();
                this.amount.setCurrency(defaultCurrency);
                this.amount.setValue(0);
            }

            Log.d(TAG, "Adyen initialized with merchantAccount: " + this.merchantAccount + ", clientKey: " + this.clientKey + ", countryCode: " + this.countryCode + ", amount: " + this.amount);
            this.isInitialized = true;
            call.resolve();
        } catch (Exception e) {
            Log.e(TAG, "Error initializing Adyen plugin: " + e.getMessage());
            call.reject("Error initializing Adyen plugin: " + e.getMessage());
        }
    }

    public void isGooglePayAvailable(PluginCall call, Activity activity, Application application) {
        try {
            if (!this.isInitialized){
                call.reject("Error plugin is no initialized" );
                return;
            }
            JSObject ret = new JSObject();
            // Create GooglePay configuration
            GooglePayConfiguration config = new GooglePayConfiguration.Builder(activity, this.clientKey)
                .setCountryCode(this.countryCode)
                .setMerchantAccount(this.merchantAccount)
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

    public void requestGooglePayment(PluginCall call, Activity activity, Bridge bridge, String googlePayCallbackId) {
        try {
            if (!this.isInitialized){
                call.reject("Error plugin is no initialized" );
                return;
            }
            if (!(activity instanceof FragmentActivity fragmentActivity)) {
                Log.e(TAG, "Activity is not a FragmentActivity");
                call.reject("Activity is not a FragmentActivity");
                return;
            }

            fragmentActivity.runOnUiThread(() -> {
                try {
                    GooglePayConfiguration config = new GooglePayConfiguration.Builder(bridge.getContext(), this.clientKey)
                            .setCountryCode(this.countryCode)
                            .setMerchantAccount(this.merchantAccount)
                            .setAmount(this.amount)
                            .build();

                    PaymentMethod paymentMethod = new PaymentMethod();
                    paymentMethod.setType("googlepay");

                    this.googlePayComponent = GooglePayComponent.PROVIDER.get(
                            fragmentActivity,
                            paymentMethod,
                            config
                    );

                    this.googlePayComponent.observe(fragmentActivity, googlePayState -> {
                        PluginCall savedCall = bridge.getSavedCall(googlePayCallbackId);

                        if (savedCall == null) {
                            Log.e(TAG, "Saved call is null, likely already handled or expired.");
                            return;
                        }

                        if (googlePayState == null) {
                            Log.e(TAG, "Google Pay state is null");
                            savedCall.reject("Google Pay response is null");
                            return;
                        }

                        if (googlePayState.isValid()) {
                            PaymentData paymentData = googlePayState.getPaymentData();
                            if (paymentData != null) {
                                Log.d(TAG, "Payment data received: " + paymentData.toJson());
                                JSObject result = new JSObject();
                                result.put("success", true);
                                result.put("paymentData", paymentData.toJson());
                                savedCall.resolve(result);
                            } else {
                                Log.e(TAG, "Payment data is null");
                                savedCall.reject("Google Pay token is null");
                            }
                        } else {
                            Log.e(TAG, "Google Pay state is invalid");
                            savedCall.reject("Google Pay payment is invalid");
                        }
                    });

                    this.googlePayComponent.startGooglePayScreen(fragmentActivity, AdyenPlugin.PAYMENT_REQUEST_CODE);

                } catch (Exception e) {
                    Log.e(TAG, "Error processing Google Pay payment", e);
                    call.reject("Error processing Google Pay payment: " + e.getMessage());
                }
            });

        } catch (Exception e) {
            Log.e(TAG, "Unexpected error in requestGooglePayment", e);
            call.reject("Unexpected error: " + e.getMessage());
        }
    }

    public void requestApplePayment(PluginCall call) {
        call.reject("Apple Pay is not available on Android");
    }

    public void handleGooglePayResult(int requestCode, int resultCode, Intent data, Bridge bridge, String googlePayCallbackId) {
        Log.d(TAG, "Handling Google Pay result, requestCode: " + requestCode + ", resultCode: " + resultCode);
        PluginCall savedCall = bridge.getSavedCall(googlePayCallbackId);
        if (this.googlePayComponent != null) {
            Log.d(TAG, "Calling googlePayComponent.handleActivityResult()");
            this.googlePayComponent.handleActivityResult(resultCode, data);
        } else {
            if (savedCall != null) {
                savedCall.reject("Google Pay component is null");
            }
        }
    }
}
