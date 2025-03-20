package com.matrix.adyen;

import android.content.Intent;
import android.util.Log;

import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

@CapacitorPlugin(name = "Adyen", requestCodes = { 60001 })
public class AdyenPlugin extends Plugin {
    private static final String TAG = "AdyenPlugin";
    public static final int PAYMENT_REQUEST_CODE = 60001;
    private String googlePayCallbackId;
    private final Adyen implementation = new Adyen();

    @PluginMethod
    public void initialize(PluginCall call) {
        implementation.initialize(call);
    }

    @PluginMethod
    public void isGooglePayAvailable(PluginCall call) {
        implementation.isGooglePayAvailable(call, getActivity(), getActivity().getApplication());
    }

    @PluginMethod
    public void isApplePayAvailable(PluginCall call) {
        implementation.isApplePayAvailable(call);
    }

    @PluginMethod
    public void requestGooglePayment(PluginCall call) {
        this.googlePayCallbackId = call.getCallbackId();
        this.bridge.saveCall(call);
        call.setKeepAlive(true);
        implementation.requestGooglePayment(call, getActivity(), this.bridge, googlePayCallbackId);
    }

    @PluginMethod
    public void requestApplePayment(PluginCall call) {
        // Not applicable on Android, but we need to implement it
        implementation.requestApplePayment(call);
    }

    @Override
    protected void handleOnActivityResult(int requestCode, int resultCode, Intent data) {
        super.handleOnActivityResult(requestCode, resultCode, data);

        if (requestCode == AdyenPlugin.PAYMENT_REQUEST_CODE) {
            Log.d(TAG, "Handling Google Pay activity result");
            implementation.handleGooglePayResult(requestCode, resultCode, data, this.bridge,this.googlePayCallbackId );
        }
    }
}
