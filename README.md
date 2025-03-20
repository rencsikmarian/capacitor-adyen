# capacitor-adyen

Adyen Mobile SDK wrapper for Capacitor.

## Install

```bash
npm install capacitor-adyen
npx cap sync
```

## API

<docgen-index>

* [`initialize(...)`](#initialize)
* [`isGooglePayAvailable()`](#isgooglepayavailable)
* [`isApplePayAvailable()`](#isapplepayavailable)
* [`requestGooglePayment(...)`](#requestgooglepayment)
* [`requestApplePayment(...)`](#requestapplepayment)

</docgen-index>

<docgen-api>
<!--Update the source file JSDoc comments and rerun docgen to update the docs below-->

### initialize(...)

```typescript
initialize(options: { environment: string, merchantAccount: string, clientKey:string, countryCode: string, merchantName:string, amount:{currency: string, value: int} }) => Promise<void>
```

| Param         | Type                                                              |
| ------------- | ----------------------------------------------------------------- |
| **`options`** | <code>{ environment: string; }</code>                             |
| ------------- | ----------------------------------------------------------------- |
| **`options`** | <code>{ merchantAccount: string; }</code>                         |
| ------------- | ----------------------------------------------------------------- |
| **`options`** | <code>{ clientKey: string; }</code>                               |
| ------------- | ----------------------------------------------------------------- |
| **`options`** | <code>{ countryCode: string; }</code>                             |
| ------------- | ----------------------------------------------------------------- |
| **`options`** | <code>{ merchantName: string; }</code>                            |
| ------------- | ----------------------------------------------------------------- |
| **`options`** | <code>{ amount: {currency: string, value: int}; }</code>          |

**Returns:** <code>Promise&lt;void&gt;</code>
--------------------

</docgen-api>
