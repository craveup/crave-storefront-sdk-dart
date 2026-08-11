import 'dart:io';

import 'package:test/test.dart';

void main() {
  final readme = File('README.md');
  final changelog = File('CHANGELOG.md');
  final security = File('SECURITY.md');
  final contributing = File('CONTRIBUTING.md');
  final example = File('example/main.dart');
  final developmentVerification = File('tool/verify.sh');
  final webVerification = File('tool/verify_web.sh');
  final releaseVerification = File('tool/verify_release.sh');
  final ciWorkflow = File('.github/workflows/ci.yml');
  final publishWorkflow = File('.github/workflows/publish.yml');
  final dependabot = File('.github/dependabot.yml');
  final analyzerOptions = File('analysis_options.yaml');

  group('external developer documentation', () {
    test('ships the complete pub.dev documentation set', () {
      expect(readme.existsSync(), isTrue);
      expect(changelog.existsSync(), isTrue);
      expect(security.existsSync(), isTrue);
      expect(contributing.existsSync(), isTrue);
      expect(example.existsSync(), isTrue);
      expect(developmentVerification.existsSync(), isTrue);
      expect(webVerification.existsSync(), isTrue);
      expect(releaseVerification.existsSync(), isTrue);
    });

    test('pins the release and configures environment and tenant explicitly',
        () {
      final contents = readme.readAsStringSync();

      expect(contents, contains('crave_storefront_sdk: 0.2.0'));
      expect(contents, contains("Uri.parse('https://api.craveup.com')"));
      expect(contents, contains("merchantSlug: 'example-merchant'"));
      expect(contents.toLowerCase(), contains('sandbox'));
      expect(contents.toLowerCase(), contains('separate deployments'));
      expect(
        contents.toLowerCase(),
        contains(RegExp(r'runtime\s+environment switch')),
      );
      expect(contents, contains('@craveup/storefront-sdk'));
      expect(contents, isNot(contains('crave_storefront_sdk: any')));
      expect(contents, isNot(contains('crave_storefront_sdk: latest')));
      expect(contents, isNot(contains('git:')));
    });

    test('explains caller-owned identity and durable session storage', () {
      final contents = readme.readAsStringSync().toLowerCase();

      expect(contents, contains('customer jwt provider'));
      expect(contents, contains('encrypted platform storage'));
      expect(contents, contains('caller-owned'));
      expect(contents, contains('never persist'));
    });

    test('documents cancellation, typed failures, and conflict recovery', () {
      final contents = readme.readAsStringSync();
      final exampleContents = example.readAsStringSync().toLowerCase();

      expect(contents, contains('StorefrontRequestCancelledException'));
      expect(contents, contains('StorefrontTimeoutException'));
      expect(contents, contains('StorefrontApiException'));
      expect(contents, contains('CART_CONFLICT'));
      expect(contents, contains('reconcile'));
      expect(contents.toLowerCase(), contains('one logical operation'));
      expect(contents.toLowerCase(),
          contains('discard it when that operation settles'));
      expect(
          exampleContents, contains('discard it after the operation settles'));
    });

    test('walks through typed catalog and ordering operations', () {
      final readmeContents = readme.readAsStringSync();
      final exampleContents = example.readAsStringSync();

      for (final contents in [readmeContents, exampleContents]) {
        expect(contents, contains('client.locations.getOrderingReadiness'));
        expect(contents, contains('client.menus.getForLocation'));
        expect(contents, contains('client.orderingSessions.start'));
        expect(contents, contains('StartOrderingSessionRequest.fresh'));
        expect(contents, contains('final menu = await client.menus'));
        expect(
          contents,
          contains('final orderingSession = await client.orderingSessions'),
        );
        expect(contents,
            contains('return (menu: menu, orderingSession: orderingSession)'));
      }
    });

    test('records the 0.2.0 contract changes for pub.dev consumers', () {
      final contents = changelog.readAsStringSync();

      expect(contents, contains('## 0.2.0'));
      expect(contents, contains('getOrderingReadiness'));
      expect(contents, contains('FulfillmentMethod'));
      expect(contents, contains('0.1.0'));
    });

    test('explains ambiguous replays and injected-client trust', () {
      final readmeContents = readme.readAsStringSync().toLowerCase();
      final securityContents = security.readAsStringSync().toLowerCase();

      expect(readmeContents, contains('ambiguous outcome'));
      expect(readmeContents, contains('reuse the same idempotency key'));
      expect(readmeContents, contains('new logical mutation'));
      expect(readmeContents, contains('retryidempotencykey'));
      expect(readmeContents, contains('idempotencykeygenerator.next()'));
      expect(readmeContents, contains('before the first attempt'));
      for (final contents in [readmeContents, securityContents]) {
        expect(contents, contains('injected `http.client`'));
        expect(contents, contains('trusted'));
        expect(contents, contains('headers'));
      }
    });

    test('keeps public guidance on the typed client boundary', () {
      final publicGuidance = [
        readme,
        security,
        example,
      ]
          .where((file) => file.existsSync())
          .map((file) => file.readAsStringSync())
          .join('\n');

      expect(publicGuidance,
          isNot(contains(RegExp(r'api[ _-]?key', caseSensitive: false))));
      expect(publicGuidance,
          isNot(contains(RegExp(r'raw http', caseSensitive: false))));
      expect(publicGuidance, isNot(contains('/api/v1/storefront')));
    });

    test('example uses the canonical public origin and has no credential', () {
      final contents = example.readAsStringSync();

      expect(contents, contains("Uri.parse('https://api.craveup.com')"));
      expect(contents, contains("merchantSlug: 'example-merchant'"));
      expect(contents,
          isNot(contains(RegExp(r'Bearer\s+', caseSensitive: false))));
      expect(contents, isNot(contains(RegExp(r'eyJ[a-zA-Z0-9_-]+\.'))));
      expect(contents, isNot(contains(RegExp(r'pk_(test|live)_'))));
      expect(contents, isNot(contains(RegExp(r'sk_(test|live)_'))));
    });

    test('separates development verification from clean release gates', () {
      final development = developmentVerification.readAsStringSync();
      final release = releaseVerification.existsSync()
          ? releaseVerification.readAsStringSync()
          : '';
      final contributingContents = contributing.readAsStringSync();

      expect(development, isNot(contains('dart pub publish')));
      expect(development, isNot(contains('pana ')));
      expect(development, contains('dart pub get'));
      expect(release, contains('./tool/verify.sh'));
      expect(release, contains('./tool/verify_web.sh'));
      expect(release, contains('PANA_VERSION:-0.23.17'));
      expect(release, contains('0.23.12'));
      expect(release, contains('0.23.17'));
      expect(release, contains('pana --no-warning --exit-code-threshold=0'));
      expect(release, contains('dart pub publish --dry-run'));
      expect(release, contains('git status --porcelain'));
      expect(
        release.indexOf('pana --no-warning'),
        lessThan(release.indexOf('dart pub publish --dry-run')),
      );
      expect(
        release.indexOf('dart pub publish --dry-run'),
        lessThan(release.lastIndexOf('git status --porcelain')),
      );
      expect(contributingContents, contains('./tool/verify.sh'));
      expect(contributingContents, contains('./tool/verify_release.sh'));
      expect(contributingContents, contains('pana 0.23.12'));
      expect(contributingContents, contains('pana 0.23.17'));
      expect(contributingContents, contains('PANA_VERSION=0.23.12'));
      expect(contributingContents, contains('clean'));
    });

    test('analyzes the Flutter fixture only with its resolved toolchain', () {
      final contents = analyzerOptions.readAsStringSync();

      expect(contents, contains('exclude:'));
      expect(contents, contains('tool/flutter_consumer/**'));
      expect(developmentVerification.readAsStringSync(),
          contains('flutter analyze'));
      expect(ciWorkflow.readAsStringSync(),
          contains('working-directory: tool/flutter_consumer'));
    });

    test('CI holds main to 160 pana points and exercises web targets', () {
      final contents = ciWorkflow.readAsStringSync();
      final webContents = webVerification.readAsStringSync();

      expect(contents, contains('exit-code-threshold=10'));
      expect(contents, contains('exit-code-threshold=0'));
      expect(contents, contains('pana 0.23.17'));
      expect(contents, contains('./tool/verify_web.sh'));
      expect(webContents, contains('dart compile js example/main.dart'));
      expect(webContents, contains('dart test --platform chrome'));
      expect(webContents, contains('test/http/transport_test.dart'));
      expect(
        webContents,
        contains('test/runtime/cart_session_runtime_test.dart'),
      );
    });

    test('release tags are always validated before conditional OIDC upload',
        () {
      final contents = publishWorkflow.readAsStringSync();
      final development = developmentVerification.readAsStringSync();
      final release = releaseVerification.readAsStringSync();
      final validateJob = contents.indexOf('\n  validate:\n');
      final publishJob = contents.indexOf('\n  publish:\n');
      final firstReleaseGate =
          contents.indexOf("if: github.ref_name != 'v0.1.0'");

      expect(validateJob, greaterThanOrEqualTo(0));
      expect(publishJob, greaterThan(validateJob));
      expect(contents, contains('needs: validate'));
      expect(contents, contains('./tool/verify_release.sh'));
      expect(contents, contains('pana 0.23.17'));
      expect(contents, contains("PANA_VERSION: '0.23.17'"));
      expect(firstReleaseGate, greaterThan(publishJob));
      expect(contents, contains('git rev-list -n 1'));
      expect(development, contains('dart test'));
      expect(development, contains('flutter test'));
      expect(release, contains('git merge-base --is-ancestor'));
      expect(release, contains('pana --no-warning --exit-code-threshold=0'));
      expect(release, contains('dart pub publish --dry-run'));
      expect(release, contains('git status --porcelain'));
      expect(contents.indexOf('id-token: write'), greaterThan(publishJob));
    });

    test('Dependabot does not reference a missing repository label', () {
      expect(
        dependabot.readAsStringSync(),
        isNot(contains('labels:\n      - dependencies')),
      );
    });
  });
}
