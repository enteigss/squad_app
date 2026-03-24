Run the Flutter app on a connected device.

Ask the user which environment if not specified in their message:
- **dev** (test environment): `--flavor=dev --dart-define=ENV=dev`
- **prod** (production): `--flavor=prod --dart-define=ENV=prod`

Run from the `app/` directory:

```
flutter run --flavor=<flavor> --dart-define=ENV=<env>
```

Default to **dev** if the user says "just run it" or doesn't specify.
