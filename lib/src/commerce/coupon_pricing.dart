/// Calculates a coupon discount if the stored coupon is eligible for a cart.
int? calculateCouponDiscount(
  Map<String, dynamic>? coupon,
  int subtotal,
  String? currency,
  DateTime now,
) {
  if (coupon == null || currency == null || subtotal <= 0) return null;
  final kind = coupon['kind'];
  final value = coupon['value'];
  final isActive = coupon['isActive'];
  final usageCount = coupon['usageCount'];
  if (isActive != true ||
      value is! num ||
      value <= 0 ||
      value != value.toInt() ||
      usageCount is! num ||
      usageCount < 0 ||
      usageCount != usageCount.toInt()) {
    return null;
  }
  final startsAt = coupon['startsAt'];
  final expiresAt = coupon['expiresAt'];
  if (startsAt != null && (startsAt is! DateTime || startsAt.isAfter(now))) {
    return null;
  }
  if (expiresAt != null &&
      (expiresAt is! DateTime || !expiresAt.isAfter(now))) {
    return null;
  }
  final minimum = coupon['minimumSubtotalMinor'];
  if (minimum != null) {
    if (minimum is! num ||
        minimum < 0 ||
        minimum != minimum.toInt() ||
        subtotal < minimum) {
      return null;
    }
  }
  final usageLimit = coupon['usageLimit'];
  if (usageLimit != null) {
    if (usageLimit is! num ||
        usageLimit <= 0 ||
        usageLimit != usageLimit.toInt() ||
        usageCount >= usageLimit) {
      return null;
    }
  }
  final int discount;
  if (kind == 'percent' && value <= 100) {
    discount = subtotal * value.toInt() ~/ 100;
  } else if (kind == 'fixed' && coupon['currency'] == currency) {
    discount = value.toInt();
  } else {
    return null;
  }

  final maximum = coupon['maximumDiscountMinor'];
  int? maximumInteger;
  if (maximum != null) {
    if (maximum is! num) return null;
    maximumInteger = maximum.toInt();
    if (maximum < 0 || maximum != maximumInteger) return null;
  }
  final maximumDiscount = maximumInteger != null && discount > maximumInteger
      ? maximumInteger
      : discount;
  return maximumDiscount > subtotal ? subtotal : maximumDiscount;
}
