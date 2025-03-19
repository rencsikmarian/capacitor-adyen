export interface AdyenPlugin {
  initialize(options: AdyenInitOptions): Promise<void>;
  isGooglePayAvailable(): Promise<{ isAvailable: boolean }>;
  isApplePayAvailable(): Promise<{ isAvailable: boolean }>;
  requestGooglePayment(options: PaymentRequestOptions): Promise<PaymentResult>;
  requestApplePayment(options: ApplePayRequestOptions): Promise<PaymentResult>;
}

export interface AdyenInitOptions {
  environment: 'TEST' | 'LIVE';
  merchantAccount: string;
  clientKey: string;
  countryCode: string;
  amount: {
    value: number;
    currency: string;
  };
  merchantName: string;
  merchantIdentifier?: string; // Required for Apple Pay
}

export interface PaymentRequestOptions {
  totalPrice: string;
  currencyCode: string;
  merchantName: string;
  transactionId?: string;
  billingAddressRequired?: boolean;
  additionalData?: Record<string, any>;
}

export interface ApplePayRequestOptions extends PaymentRequestOptions {
  summaryItems: ApplePaySummaryItem[];
  merchantCapabilities?: string[];
  supportedNetworks?: string[];
  shippingContact?: boolean;
  billingContact?: boolean;
}

export interface ApplePaySummaryItem {
  label: string;
  amount: string;
  type?: 'final' | 'pending';
}

export interface PaymentResult {
  success: boolean;
  paymentData?: string;
  token?: string;
  error?: {
    code: string;
    message: string;
  };
}


