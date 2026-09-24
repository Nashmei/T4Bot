# IPA signing

GitHub Actions can compile the application without an Apple account and package it as an **unsigned IPA**. That is what `build-ipa.yml` produces.

An unsigned IPA is not directly installable on a normal stock iPhone. It must be signed by a valid Apple development, ad-hoc, enterprise, or App Store distribution identity before installation.

## Recommended production path

Use Apple-managed signing in Xcode or a dedicated private signing workflow with these values stored only as GitHub encrypted secrets:

- distribution/development certificate (.p12, base64)
- certificate password
- provisioning profile (.mobileprovision, base64)
- Apple Developer Team ID
- final bundle identifier

Never commit certificates, private keys, provisioning profiles, App Store Connect keys, or passwords.

## Why unsigned is the default workflow

It keeps repository builds reproducible without placing signing credentials into source control and produces a real iPhoneOS `.app` packaged as `.ipa` for a later signing stage.
