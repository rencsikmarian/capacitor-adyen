package com.matrix.adyen;

import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

@CapacitorPlugin(name = "Adyen")
public class AdyenPlugin extends Plugin {
    private static final String TAG = "AdyenPlugin";

    private Adyen implementation = new Adyen();

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
        implementation.requestGooglePayment(call, getActivity());
    }

    @PluginMethod
    public void requestApplePayment(PluginCall call) {
        // Not applicable on Android, but we need to implement it
        implementation.requestApplePayment(call);
    }
}
