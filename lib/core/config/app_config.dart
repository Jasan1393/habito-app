class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'HABITO_API_BASE_URL',
    defaultValue: 'https://habitobarberia.com/wp-json/habito/v1',
  );

  static const String wooStoreBaseUrl = String.fromEnvironment(
    'HABITO_WOO_STORE_BASE_URL',
    defaultValue: 'https://habitobarberia.com/wp-json/wc/store/v1',
  );

  static const int authTimeoutSeconds = int.fromEnvironment(
    'HABITO_AUTH_TIMEOUT_SECONDS',
    defaultValue: 20,
  );

  static const int bookingTimeoutSeconds = int.fromEnvironment(
    'HABITO_BOOKING_TIMEOUT_SECONDS',
    defaultValue: 20,
  );

  static const int myBookingsTimeoutSeconds = int.fromEnvironment(
    'HABITO_MY_BOOKINGS_TIMEOUT_SECONDS',
    defaultValue: 35,
  );

  static const int shopTimeoutSeconds = int.fromEnvironment(
    'HABITO_SHOP_TIMEOUT_SECONDS',
    defaultValue: 25,
  );

  static const Duration authTimeout = Duration(seconds: authTimeoutSeconds);
  static const Duration bookingTimeout = Duration(
    seconds: bookingTimeoutSeconds,
  );
  static const Duration myBookingsTimeout = Duration(
    seconds: myBookingsTimeoutSeconds,
  );
  static const Duration shopTimeout = Duration(seconds: shopTimeoutSeconds);
}
