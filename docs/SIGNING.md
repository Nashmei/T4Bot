# IPA signing

T4Bot provides two GitHub Actions workflows for IPA artifacts.

## Unsigned IPA

`build-ipa.yml` compiles the real iPhoneOS target with code signing disabled and packages `T4Bot-unsigned.ipa`.

This is useful for a later signing/sideload stage, but it is not directly installable on a normal stock iPhone.

## Signed IPA

`build-signed-ipa.yml` performs manual Apple code signing using encrypted GitHub Actions secrets. Configure:

- `IOS_CERTIFICATE_P12_BASE64` — base64 contents of the signing .p12.
- `IOS_CERTIFICATE_PASSWORD` — password for the .p12.
- `IOS_PROVISIONING_PROFILE_BASE64` — base64 contents of the matching .mobileprovision.
- `IOS_BUNDLE_ID` — bundle identifier contained by that provisioning profile.

The workflow derives the Apple Team ID and profile name from the profile, verifies that its application identifier exactly matches the configured bundle ID, imports the certificate into a temporary keychain, builds, verifies the final code signature, packages `T4Bot-signed.ipa`, then removes temporary signing files and the temporary keychain.

The provisioning profile determines where the resulting build can be installed. For example, a development/ad-hoc profile must include the intended device as required by Apple's signing rules.

Never commit certificates, private keys, provisioning profiles, App Store Connect keys, or passwords to the repository.
