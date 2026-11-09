class ApiConfig {
  // ============================================================
  // BASE URL
  // ============================================================

  // PRODUCTION
  static const String baseUrl = 'https://api.ecocash.id/api/v1';
  static const String socketUrl = 'https://api.ecocash.id/sessions';

  // LOCAL (Aktif untuk pengujian lokal)
  // static const String baseUrl = 'http://localhost:3000/api/v1';
  // static const String socketUrl = 'http://localhost:3000/sessions';

  // ============================================================
  // AUTHENTICATION
  // ============================================================

  static String get login => '$baseUrl/auth/login';
  static String get register => '$baseUrl/auth';

  // ============================================================
  // EMAIL VERIFICATION
  // ============================================================

  static String get sendEmailVerification =>
      '$baseUrl/auth/email-verification/send';
  static String get confirmEmailVerification =>
      '$baseUrl/auth/email-verification/confirm';

  // ============================================================
  // PASSWORD RESET
  // ============================================================

  static String get forgotPassword => '$baseUrl/auth/forgot-password';
  static String get resetPassword => '$baseUrl/auth/reset-password';

  // ============================================================
  // USER
  // ============================================================

  static String get getUserProfile => '$baseUrl/users/me';
  static String get updateProfile => '$baseUrl/users/me';
  static String get getMyProfile => getUserProfile;
  static String get getMyQr => getMyDynamicQr;
  static String get getMyCarbon => '$baseUrl/users/me/carbon';

  // ============================================================
  // USER QR CREDENTIAL
  // ============================================================

  static String get getMyCredentialQr => '$baseUrl/users/me/credential-qr';
  static String get regenerateMyCredentialQr =>
      '$baseUrl/users/me/credential-qr/regenerate';
  static String get getMyDynamicQr => '$baseUrl/users/me/qr';

  // ============================================================
  // MACHINE & SESSION (V2 SPECIFICATION)
  // ============================================================

  static String getNearestMachines(double latitude, double longitude) {
    return '$baseUrl/machines/nearest?latitude=$latitude&longitude=$longitude';
  }

  static String getMachineById(int id) => '$baseUrl/machines/$id';
  static String get startSession => '$baseUrl/machine-sessions/start';
  static String get getCurrentSession =>
      '$baseUrl/machine-sessions/current'; // Penambahan V2
  static String get getMySessionHistory => '$baseUrl/machine-sessions/my';
  static String getSessionDetail(String id) => '$baseUrl/machine-sessions/$id';
  static String completeSession(String id) =>
      '$baseUrl/machine-sessions/$id/complete';
  static String confirmSession(String id) =>
      '$baseUrl/machine-sessions/$id/confirm';

  // ============================================================
  // PUBLIC & PARTNER DISCOVERY (JEMPUT SAMPAH)
  // ============================================================

  static String get getPublicMachines => '$baseUrl/machines/public';
  static String get getAvailableCollectors =>
      '$baseUrl/partners/available-collectors';
  static String get createPickupOrder => '$baseUrl/jobs/pickup-orders';

  // ============================================================
  // VOUCHERS
  // ============================================================

  static String get getAvailableVouchers => '$baseUrl/vouchers/available';
  static String getVoucherById(int id) => '$baseUrl/vouchers/$id';

  // ============================================================
  // LEGACY ACCESS TOKEN
  // ============================================================

  static String getAccessTokenStatus(String id) =>
      '$baseUrl/users/access-tokens/$id';

  // ============================================================
  // PRODUCTS & ORDERS & CART
  // ============================================================

  static String get getProducts => '$baseUrl/products/marketplace';
  static String get createOrder => '$baseUrl/orders';
  static String get getMyOrders => '$baseUrl/orders/my';
  static String getOrderById(String id) => '$baseUrl/orders/$id';

  static String get getCart => '$baseUrl/cart';
  static String get clearCart => '$baseUrl/cart';
  static String get addCartItem => '$baseUrl/cart/items';
  static String updateCartItem(int id) => '$baseUrl/cart/items/$id';
  static String removeCartItem(int id) => '$baseUrl/cart/items/$id';
  static String get previewCart => '$baseUrl/cart/preview';
  static String get checkoutCart => '$baseUrl/cart/checkout';

  // ============================================================
  // WALLET
  // ============================================================

  static String get getMyWallet => '$baseUrl/wallets/me';
  static String get getTransactions => '$baseUrl/wallets/me/transactions';
  static String get getMyWalletTransactions =>
      "$baseUrl/wallets/me/transactions";
  static String get createTopUp => '$baseUrl/wallets/topup';
  static String get getMyTopUps => '$baseUrl/wallets/topup';
  static String getTopUpById(int id) => '$baseUrl/wallets/topup/$id';
  static String mockPayTopUp(int id) => '$baseUrl/wallets/topup/$id/mock-pay';
  static String checkTopUpStatus(int id) =>
      '$baseUrl/wallets/topup/$id/check-status';

  // ============================================================
  // CHARITY & DONATION
  // ============================================================

  static String get getPublicCharities => '$baseUrl/charities/public';
  static String get getMyDonations => '$baseUrl/donations/me';
  static String getCharityById(int id) => '$baseUrl/charities/$id';
  static String donateToCharity(int id) => '$baseUrl/charities/$id/donate';

  // ============================================================
  // AUTH TOKEN & HEADERS
  // ============================================================

  static String? userToken;

  static void setToken(String token) {
    userToken = token
        .replaceFirst(RegExp(r'^Bearer\s+', caseSensitive: false), '')
        .trim();
  }

  static void clearToken() {
    userToken = null;
  }

  static bool get hasToken => userToken != null && userToken!.trim().isNotEmpty;

  static Map<String, String> get headers {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (hasToken) 'Authorization': 'Bearer ${userToken!.trim()}',
    };
  }

  // ============================================================
  // USER ADDRESSES
  // ============================================================

  static String get getUserAddresses => '$baseUrl/addresses';
  static String updateAddress(dynamic id) => '$baseUrl/addresses/$id';
  static String setDefaultAddress(dynamic id) =>
      '$baseUrl/addresses/$id/default';
  static String deleteUserAddress(dynamic id) => '$baseUrl/addresses/$id';

  // ============================================================
  // RIWAYAT PENJEMPUTAN WARGA
  // ============================================================

  static String get getMyPickupOrders => '$baseUrl/jobs/my-pickup-orders';

  // ============================================================
  // WASTE TYPES & MASTER DATA
  // ============================================================

  static String get getWasteTypes => '$baseUrl/waste-types';
  static String get getMachineWasteTypes =>
      '$baseUrl/waste-types/machine?limit=100';

  // ============================================================
  // LIVE CHAT DRIVER PARTNER (JOB MESSAGES)
  // ============================================================

  static String getJobChat(dynamic jobId) => '$baseUrl/jobs/$jobId/messages';
  static String sendJobChat(dynamic jobId) => '$baseUrl/jobs/$jobId/messages';
}
