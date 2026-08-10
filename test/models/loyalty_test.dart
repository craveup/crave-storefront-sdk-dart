import 'dart:convert';
import 'dart:io';

import 'package:crave_storefront_sdk/src/models/loyalty.dart';
import 'package:test/test.dart';

Map<String, Object?> fixture() {
  final decoded = jsonDecode(
    File('test/fixtures/loyalty.json').readAsStringSync(),
  );
  return (decoded as Map<Object?, Object?>).cast<String, Object?>();
}

void main() {
  test('decodes loyalty quote and ledger without closing response enums', () {
    final data = fixture();
    final quote = LoyaltyQuote.fromJson(
      (data['quote']! as Map<Object?, Object?>).cast<String, Object?>(),
    );
    final ledger = LoyaltyLedger.fromJson(
      (data['ledger']! as Map<Object?, Object?>).cast<String, Object?>(),
    );

    expect(quote.rewards.single.status, 'future_status');
    expect(quote.rewards.single.unavailableReasons, isEmpty);
    expect(quote.pointsToEarn, 25.5);
    expect(quote.balance?.available, 80.25);
    expect(quote.rewards.single.pointsCost, 50.5);
    expect(ledger.balances.single.available, 80.25);
    expect(ledger.entries.single.expiresAt, isNull);
  });

  test('allowlists redemption and claim submission request fields', () {
    final redemption = RedeemLoyaltyRequest(rewardId: 'reward_01');
    final claim = SubmitLoyaltyClaimRequest(
      orderId: 'order_01',
      reason: LoyaltyClaimReason.missingPoints,
      note: 'Example note',
    );

    expect(redemption.toJson(), <String, Object?>{'rewardId': 'reward_01'});
    expect(claim.toJson(), <String, Object?>{
      'orderId': 'order_01',
      'reason': 'missing_points',
      'note': 'Example note',
    });
    expect(claim.toJson(), isNot(contains('points')));
    expect(claim.toJson(), isNot(contains('customerId')));
  });

  test('decodes claim submission and extensible claim status/reason', () {
    final submission = LoyaltyClaimSubmission.fromJson(<String, Object?>{
      'claimId': 'claim_01',
      'status': 'queued',
      'submittedAt': '2026-08-10T12:00:00.000Z',
    });
    final claims = LoyaltyClaims.fromJson(<String, Object?>{
      'claims': <Object?>[
        <String, Object?>{
          'claimId': 'claim_01',
          'status': 'queued',
          'submittedAt': '2026-08-10T12:00:00.000Z',
          'reason': 'provider_adjustment',
          'note': null,
          'points': null,
          'updatedAt': '2026-08-10T12:01:00.000Z',
        },
      ],
    });

    expect(submission.status, 'queued');
    expect(claims.claims.single.reason, 'provider_adjustment');
    expect(claims.claims.single.points, isNull);
  });
}
