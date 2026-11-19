/// MongoDB collection names used by the ShopEase backend.
abstract final class CollectionNames {
  /// User accounts and authentication metadata.
  static const users = 'users';

  /// Revocable authenticated access sessions.
  static const userSessions = 'user_sessions';

  /// Product categories.
  static const categories = 'categories';

  /// Catalog products.
  static const products = 'products';

  /// Product ratings and reviews.
  static const reviews = 'reviews';

  /// Per-user shopping carts.
  static const carts = 'carts';

  /// Promotional coupons.
  static const coupons = 'coupons';

  /// User-owned delivery addresses.
  static const addresses = 'addresses';

  /// Available shipping methods.
  static const shippingMethods = 'shipping_methods';

  /// Customer orders.
  static const orders = 'orders';

  /// Order shipment tracking history.
  static const orderTrackingEvents = 'order_tracking_events';

  /// Bakong payments and server-side verification state.
  static const payments = 'payments';

  /// User/product wishlist entries.
  static const wishlists = 'wishlists';

  /// User preferences and settings.
  static const userSettings = 'user_settings';
}
