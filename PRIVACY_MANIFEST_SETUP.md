# iOS PrivacyInfo.xcprivacy setup

`PrivacyInfo.xcprivacy.template` is a starting point for the app's own collected-data declaration.

Before App Store submission:
1. Generate the iOS project with `flutter create .` (or use the existing iOS project in your repository).
2. Add `PrivacyInfo.xcprivacy.template` to the Runner target and rename it to `PrivacyInfo.xcprivacy`.
3. Review the collected-data categories against the final implementation and all third-party SDKs.
4. Do not copy this template unchanged into a production submission without that review.
5. Complete App Store Connect's App Privacy questionnaire from the final implementation and SDK inventory.

Apple requires the manifest to use the documented data-type, linked-to-user, tracking, and purpose keys. Third-party SDKs can have their own privacy manifests, so the final review must cover the full dependency set.

Official references:
- https://developer.apple.com/documentation/bundleresources/privacy-manifest-files
- https://developer.apple.com/documentation/technotes/tn3184-adding-data-collection-details-to-your-privacy-manifest
