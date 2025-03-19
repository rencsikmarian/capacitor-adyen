import { WebPlugin, Capacitor, registerPlugin } from '@capacitor/core';

import type { AdyenInitOptions, AdyenPlugin, ApplePayRequestOptions, PaymentRequestOptions, PaymentResult } from './definitions';

export class AdyenWeb extends WebPlugin implements AdyenPlugin {
  private platform: string | undefined;
  private initialized = false;
  private config: AdyenInitOptions | null = null;

  constructor() {
    super();
    // Determine platform
    this.platform = this.getPlatform();
  }

  private getPlatform(): string {
    return Capacitor.getPlatform();
  }

  async initialize(options: AdyenInitOptions): Promise<void> {
    if (!options.merchantAccount) {
      throw new Error('merchantAccount is required');
    }

    if (!options.clientKey) {
      throw new Error('clientKey is required');
    }

    if (this.platform === 'ios' && !options.merchantIdentifier) {
      console.warn('merchantIdentifier is recommended for Apple Pay on iOS');
    }

    this.config = { ...options };
    this.initialized = true;

    // Forward to native implementation
    try {
      const nativePlugin = registerPlugin<AdyenPlugin>('Adyen');
      await nativePlugin.initialize(this.config);
      return;
    } catch (error) {
      console.error('Error initializing Adyen payment plugin:', error);
      throw error;
    }
  }

  async isGooglePayAvailable(): Promise<{ isAvailable: boolean }> {
    this.checkInitialized();

    if (this.platform !== 'android') {
      return { isAvailable: false };
    }

    try {
      const nativePlugin = registerPlugin<AdyenPlugin>('Adyen');
      return await nativePlugin.isGooglePayAvailable();
    } catch (error) {
      console.error('Error checking Google Pay availability:', error);
      return { isAvailable: false };
    }
  }

  async isApplePayAvailable(): Promise<{ isAvailable: boolean }> {
    this.checkInitialized();

    if (this.platform !== 'ios') {
      return { isAvailable: false };
    }

    try {
      const nativePlugin = registerPlugin<AdyenPlugin>('Adyen');
      return await nativePlugin.isApplePayAvailable();
    } catch (error) {
      console.error('Error checking Apple Pay availability:', error);
      return { isAvailable: false };
    }
  }

  async requestGooglePayment(options: PaymentRequestOptions): Promise<PaymentResult> {
    this.checkInitialized();

    if (this.platform !== 'android') {
      return {
        success: false,
        error: {
          message: 'Google Pay is only available on Android devices',
          code: 'NOT_AVAILABLE'
        }
      };
    }

    try {
      const nativePlugin = registerPlugin<AdyenPlugin>('Adyen');
      return await nativePlugin.requestGooglePayment(options);
    } catch (error) {
      console.error('Error requesting Google Pay payment:', error);
      return {
        success: false,
        error: {
          message: error instanceof Error ? error.message : 'Unknown error occurred',
          code: 'PAYMENT_ERROR'
        }
      };
    }
  }

  async requestApplePayment(options: ApplePayRequestOptions): Promise<PaymentResult> {
    this.checkInitialized();

    if (this.platform !== 'ios') {
      return {
        success: false,
        error: {
          message: 'Apple Pay is only available on iOS devices',
          code: 'NOT_AVAILABLE'
        }
      };
    }

    try {
      const nativePlugin = registerPlugin<AdyenPlugin>('Adyen');
      return await nativePlugin.requestApplePayment(options);
    } catch (error) {
      console.error('Error requesting Apple Pay payment:', error);
      return {
        success: false,
        error: {
          message: error instanceof Error ? error.message : 'Unknown error occurred',
          code: 'PAYMENT_ERROR'
        }
      };
    }
  }

  private checkInitialized(): void {
    if (!this.initialized) {
      throw new Error('Adyen plugin is not initialized. Call initialize() first.');
    }
  }
}
