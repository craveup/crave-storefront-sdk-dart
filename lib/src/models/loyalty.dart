import '../json/json_reader.dart';

/// Loyalty availability and rewards for a cart.
final class LoyaltyQuote {
  /// Creates an immutable loyalty quote.
  const LoyaltyQuote({
    required this.enabled,
    required this.rewards,
    this.available,
    this.pointsToEarn,
    this.balance,
    this.appliedRewardId,
  });

  /// Decodes a loyalty quote.
  factory LoyaltyQuote.fromJson(Map<String, Object?> json) {
    final reader = JsonReader.fromObject(json, context: 'loyaltyQuote');
    final balance = reader.nullableObject('balance');
    return LoyaltyQuote(
      enabled: reader.boolean('enabled'),
      available: reader.nullableBoolean('available'),
      pointsToEarn: reader.nullableNumber('pointsToEarn'),
      balance: balance == null ? null : LoyaltyPointBalance.fromReader(balance),
      rewards: List<LoyaltyReward>.unmodifiable(
        reader.optionalObjectList('rewards').map(LoyaltyReward.fromReader),
      ),
      appliedRewardId: reader.nullableString('appliedRewardId'),
    );
  }

  /// Whether the merchant has loyalty enabled.
  final bool enabled;

  /// Whether loyalty is currently available for this cart.
  final bool? available;

  /// Points expected from this cart.
  final double? pointsToEarn;

  /// Customer point balance.
  final LoyaltyPointBalance? balance;

  /// Rewards considered for this cart.
  final List<LoyaltyReward> rewards;

  /// Applied reward identifier.
  final String? appliedRewardId;
}

/// Posted, reserved, and available loyalty points.
final class LoyaltyPointBalance {
  /// Creates an immutable point balance.
  const LoyaltyPointBalance({
    required this.posted,
    required this.available,
    required this.reserved,
  });

  /// Decodes a point balance from an existing reader.
  factory LoyaltyPointBalance.fromReader(JsonReader reader) =>
      LoyaltyPointBalance(
        posted: reader.number('posted'),
        available: reader.number('available'),
        reserved: reader.number('reserved'),
      );

  /// Posted point balance.
  final double posted;

  /// Currently available point balance.
  final double available;

  /// Reserved point balance.
  final double reserved;
}

/// A loyalty reward quoted for a cart.
final class LoyaltyReward {
  /// Creates an immutable loyalty reward.
  const LoyaltyReward({
    required this.id,
    required this.name,
    required this.status,
    required this.unavailableReasons,
    required this.pointsCost,
    required this.redeemable,
    this.amountOff,
  });

  /// Decodes a loyalty reward from an existing reader.
  factory LoyaltyReward.fromReader(JsonReader reader) => LoyaltyReward(
        id: reader.string('id'),
        name: reader.string('name'),
        status: reader.string('status'),
        unavailableReasons: reader.optionalStringList('unavailableReasons'),
        pointsCost: reader.number('pointsCost'),
        amountOff: reader.nullableNumber('amountOff'),
        redeemable: reader.boolean('redeemable'),
      );

  /// Stable reward identifier.
  final String id;

  /// Customer-facing reward name.
  final String name;

  /// Reward status wire value, including future values.
  final String status;

  /// Safe reasons the reward cannot be redeemed.
  final List<String> unavailableReasons;

  /// Point cost.
  final double pointsCost;

  /// Provider amount-off value when supplied.
  final double? amountOff;

  /// Whether the reward can be redeemed for this cart.
  final bool redeemable;
}

/// Applies a loyalty reward to a cart.
final class RedeemLoyaltyRequest {
  /// Creates an immutable redemption request.
  const RedeemLoyaltyRequest({required this.rewardId});

  /// Reward identifier from [LoyaltyQuote].
  final String rewardId;

  /// Serializes only fields accepted by the redemption endpoint.
  Map<String, Object?> toJson() => <String, Object?>{'rewardId': rewardId};
}

/// Customer loyalty balances and ledger entries.
final class LoyaltyLedger {
  /// Creates an immutable loyalty ledger.
  const LoyaltyLedger({
    required this.enabled,
    required this.balances,
    required this.entries,
    this.nextCursor,
  });

  /// Decodes a loyalty ledger.
  factory LoyaltyLedger.fromJson(Map<String, Object?> json) {
    final reader = JsonReader.fromObject(json, context: 'loyaltyLedger');
    return LoyaltyLedger(
      enabled: reader.boolean('enabled'),
      balances: List<LoyaltyLedgerBalance>.unmodifiable(
        reader
            .optionalObjectList('balances')
            .map(LoyaltyLedgerBalance.fromReader),
      ),
      entries: List<LoyaltyLedgerEntry>.unmodifiable(
        reader.optionalObjectList('entries').map(LoyaltyLedgerEntry.fromReader),
      ),
      nextCursor: reader.nullableString('nextCursor'),
    );
  }

  /// Whether the merchant has loyalty enabled.
  final bool enabled;

  /// Balances by loyalty unit.
  final List<LoyaltyLedgerBalance> balances;

  /// Ledger entries in server order.
  final List<LoyaltyLedgerEntry> entries;

  /// Cursor for the next page.
  final String? nextCursor;
}

/// One balance in a loyalty ledger.
final class LoyaltyLedgerBalance {
  /// Creates an immutable ledger balance.
  const LoyaltyLedgerBalance({
    required this.unit,
    required this.posted,
    required this.reserved,
    required this.available,
    required this.asOf,
    this.label,
  });

  /// Decodes a ledger balance from an existing reader.
  factory LoyaltyLedgerBalance.fromReader(JsonReader reader) =>
      LoyaltyLedgerBalance(
        unit: reader.string('unit'),
        label: reader.nullableString('label'),
        posted: reader.number('posted'),
        reserved: reader.number('reserved'),
        available: reader.number('available'),
        asOf: reader.timestamp('asOf'),
      );

  /// Loyalty unit wire value.
  final String unit;

  /// Customer-facing unit label.
  final String? label;

  /// Posted balance.
  final double posted;

  /// Reserved balance.
  final double reserved;

  /// Available balance.
  final double available;

  /// ISO-8601 balance timestamp wire value.
  final String asOf;
}

/// One loyalty ledger operation.
final class LoyaltyLedgerEntry {
  /// Creates an immutable ledger entry.
  const LoyaltyLedgerEntry({
    required this.operation,
    required this.amount,
    required this.unit,
    required this.occurredAt,
    this.classification,
    this.orderReference,
    this.expiresAt,
  });

  /// Decodes a ledger entry from an existing reader.
  factory LoyaltyLedgerEntry.fromReader(JsonReader reader) =>
      LoyaltyLedgerEntry(
        operation: reader.string('operation'),
        amount: reader.number('amount'),
        unit: reader.string('unit'),
        classification: reader.nullableString('classification'),
        orderReference: reader.nullableString('orderReference'),
        expiresAt: reader.nullableTimestamp('expiresAt'),
        occurredAt: reader.timestamp('occurredAt'),
      );

  /// Operation wire value, including future values.
  final String operation;

  /// Signed operation amount.
  final double amount;

  /// Loyalty unit wire value.
  final String unit;

  /// Optional classification wire value.
  final String? classification;

  /// Optional customer-facing order reference.
  final String? orderReference;

  /// ISO-8601 expiration timestamp wire value.
  final String? expiresAt;

  /// ISO-8601 occurrence timestamp wire value.
  final String occurredAt;
}

/// Reason accepted when a customer submits a loyalty claim.
enum LoyaltyClaimReason {
  /// Points were not awarded.
  missingPoints('missing_points'),

  /// An incorrect number of points was awarded.
  incorrectPoints('incorrect_points'),

  /// Another customer-described issue.
  other('other');

  const LoyaltyClaimReason(this.wireValue);

  /// Value sent to the Storefront API.
  final String wireValue;
}

/// Submits a customer loyalty claim for an order.
final class SubmitLoyaltyClaimRequest {
  /// Creates an immutable loyalty-claim request.
  const SubmitLoyaltyClaimRequest({
    required this.orderId,
    required this.reason,
    this.note,
  });

  /// Customer-owned order identifier.
  final String orderId;

  /// Claim reason accepted by the API.
  final LoyaltyClaimReason reason;

  /// Optional customer note.
  final String? note;

  /// Serializes only fields accepted by the claim endpoint.
  Map<String, Object?> toJson() => <String, Object?>{
        'orderId': orderId,
        'reason': reason.wireValue,
        if (note != null) 'note': note,
      };
}

/// Result returned after submitting a loyalty claim.
final class LoyaltyClaimSubmission {
  /// Creates an immutable claim submission.
  const LoyaltyClaimSubmission({
    required this.claimId,
    required this.status,
    required this.submittedAt,
  });

  /// Decodes a claim-submission response.
  factory LoyaltyClaimSubmission.fromJson(Map<String, Object?> json) =>
      LoyaltyClaimSubmission.fromReader(
        JsonReader.fromObject(json, context: 'loyaltyClaimSubmission'),
      );

  /// Decodes a claim submission from an existing reader.
  factory LoyaltyClaimSubmission.fromReader(JsonReader reader) =>
      LoyaltyClaimSubmission(
        claimId: reader.string('claimId'),
        status: reader.string('status'),
        submittedAt: reader.timestamp('submittedAt'),
      );

  /// Stable public claim identifier.
  final String claimId;

  /// Claim status wire value, including future values.
  final String status;

  /// ISO-8601 submission timestamp wire value.
  final String submittedAt;
}

/// A customer-visible loyalty claim.
final class LoyaltyClaim {
  /// Creates an immutable loyalty claim.
  const LoyaltyClaim({
    required this.claimId,
    required this.status,
    required this.submittedAt,
    required this.reason,
    required this.updatedAt,
    this.note,
    this.points,
  });

  /// Decodes a loyalty claim from an existing reader.
  factory LoyaltyClaim.fromReader(JsonReader reader) => LoyaltyClaim(
        claimId: reader.string('claimId'),
        status: reader.string('status'),
        submittedAt: reader.timestamp('submittedAt'),
        reason: reader.string('reason'),
        note: reader.nullableString('note'),
        points: reader.nullableNumber('points'),
        updatedAt: reader.timestamp('updatedAt'),
      );

  /// Stable public claim identifier.
  final String claimId;

  /// Claim status wire value, including future values.
  final String status;

  /// ISO-8601 submission timestamp wire value.
  final String submittedAt;

  /// Claim reason wire value, including future values.
  final String reason;

  /// Optional customer note.
  final String? note;

  /// Point adjustment, when known.
  final double? points;

  /// ISO-8601 update timestamp wire value.
  final String updatedAt;
}

/// Wrapper returned when listing customer loyalty claims.
final class LoyaltyClaims {
  /// Creates an immutable claims result.
  const LoyaltyClaims({required this.claims});

  /// Decodes a claims-list response.
  factory LoyaltyClaims.fromJson(Map<String, Object?> json) {
    final reader = JsonReader.fromObject(json, context: 'loyaltyClaims');
    return LoyaltyClaims(
      claims: List<LoyaltyClaim>.unmodifiable(
        reader.optionalObjectList('claims').map(LoyaltyClaim.fromReader),
      ),
    );
  }

  /// Customer claims.
  final List<LoyaltyClaim> claims;
}
