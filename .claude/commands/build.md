Build the Flutter app for distribution.

Ask the user which **environment** if not specified:
- **dev** (test environment): `--flavor=dev --dart-define=ENV=dev`
- **prod** (production): `--flavor=prod --dart-define=ENV=prod`

Ask the user which **build target** if not specified:
- **appbundle** — Android App Bundle: `flutter build appbundle`
- **apk** — Android APK: `flutter build apk`
- **ipa** — iOS archive: `flutter build ipa`

Run from the `app/` directory:

```
flutter build <target> --flavor=<flavor> --dart-define=ENV=<env>
```

Default to **dev** if environment is not specified.
