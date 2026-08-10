# Contributing

Thanks for improving the Crave Storefront SDK. Every public API is durable once published, so keep
changes small, typed, and backed by executable Storefront contract evidence.

## Set up

Install a supported Dart SDK, then run:

```sh
dart pub get
dart test
```

Flutter stable is also required for the disposable consumer fixture under `tool/flutter_consumer`.

## Development workflow

1. Open an issue for a new public operation or breaking surface change.
2. Add a focused failing test and observe the expected failure.
3. Add the smallest implementation through the shared transport/session runtime.
4. Run focused tests, then the development verification script.
5. Keep the public entrypoint documented and update the changelog for user-visible behavior.

Resource clients must not duplicate authorization, capability, revision, idempotency, timeout,
cancellation, or decoding behavior. Do not add arbitrary request paths, merchant/admin credentials,
environment inference, native platform code, or a Flutter runtime dependency.

## Verify

```sh
./tool/verify.sh
```

This command is designed for a normal dirty development tree. It runs formatting, analysis, Dart
tests and documentation, dependency review, the credential-material scan, and the Flutter fixture.

From the clean, exact release tag, install the pinned quality analyzer and run the release gates:

```sh
dart pub global activate pana 0.23.17
./tool/verify_release.sh
```

Pana 0.23.17 requires Dart 3.11 or newer. If a locally bundled Flutter toolchain still provides an
older Dart SDK, use the temporary compatibility pin for local verification:

```sh
dart pub global activate pana 0.23.12
PANA_VERSION=0.23.12 ./tool/verify_release.sh
```

CI and tag publication always use Pana 0.23.17 with the current stable Dart toolchain. Remove the
fallback when supported Flutter stable bundles Dart 3.11 or newer everywhere the SDK is maintained.

Release verification reruns the development gates and the compiled JavaScript/Chrome runtime gate,
requires the tag to match `pubspec.yaml`, requires the commit to be on `origin/main`, enforces a full
pana score, inspects the dry-run archive last, and then proves the working tree is still clean.

Run the credential-material check before attaching logs or opening a pull request:

```sh
./tool/check_secrets.sh
```

The checker reports file names only; it never prints a matching value.

## Pull requests

- Explain the developer-visible behavior and contract evidence.
- Include the observed failing test and the passing verification commands.
- Update docs and sanitized fixtures with any public behavior change.
- Keep generated artifacts, build output, credentials, customer data, and production identifiers out
  of commits.
- Use an imperative commit subject and normal pull-request merge.

Publication is performed only from the exact reviewed release tag by a Crave maintainer. Version
`0.1.0` is published manually; later versions can use the protected pub.dev environment after the
package is transferred to the verified publisher and automated publishing is configured.
