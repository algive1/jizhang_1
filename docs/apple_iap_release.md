# Apple IAP production configuration

The iOS membership UI uses StoreKit only. WeChat Pay and Alipay remain Android payment channels.

## App Store Connect
Create one auto-renewable subscription group and these products:
- `haohaojizhang.membership.monthly`
- `haohaojizhang.membership.quarterly`
- `haohaojizhang.membership.yearly`

Configure the App Store Server Notifications V2 production and sandbox URL as:
`https://<api-host>/api/v1/payments/apple/notify`

## Server environment
- `APPLE_BUNDLE_ID`: the exact iOS bundle identifier.
- `APPLE_ROOT_CA_PATHS`: comma-separated local paths to trusted Apple root certificate files downloaded from Apple PKI.

The server intentionally fails closed when no trusted Apple root CA is configured. Do not disable certificate-chain validation.

## Release verification
1. Create a Sandbox Apple ID / StoreKit test account.
2. Purchase each duration and verify `GET /api/v1/membership/current` returns active Apple membership.
3. Restore purchases on a second install while signed into the same app account.
4. Exercise renewal and expiration.
5. Exercise refund/revocation and confirm premium entitlements disappear.
6. Send an App Store Server Notifications V2 TEST notification and confirm HTTP 2xx.
7. Confirm iOS never renders WeChat Pay or Alipay membership controls.
8. Confirm Android WeChat/Alipay membership purchase remains unchanged.

No Apple private key, issuer ID, shared secret, certificate, or production credential belongs in source control.
