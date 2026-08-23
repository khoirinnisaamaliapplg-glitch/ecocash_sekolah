class ApiConfig {
  // ============================================================
  // BASE URL
  // ============================================================

  // LOCAL
  static const String baseUrl = 'http://localhost:3000/api/v1';

  // PRODUCTION
  // static const String baseUrl = 'https://api.ecocash.id/api/v1';

  // ============================================================
  // AUTHENTICATION
  // ============================================================

  static String get login {
    return '$baseUrl/auth/login';
  }

  static String get register {
    return '$baseUrl/auth';
  }

  // ============================================================
  // USER
  // ============================================================

  static String get getUserProfile {
    return '$baseUrl/users/me';
  }

  static String get updateProfile {
    return '$baseUrl/users/me';
  }

  static String get getMyCarbon {
    return '$baseUrl/users/me/carbon';
  }

  // ============================================================
  // USER QR
  // ============================================================

  /// QR PERMANEN
  ///
  /// GET /users/me/credential-qr
  ///
  /// Digunakan oleh ScanPage EcoCash Sekolah.
  static String get getMyCredentialQr {
    return '$baseUrl/users/me/credential-qr';
  }

  /// Regenerate QR permanen.
  ///
  /// POST /users/me/credential-qr/regenerate
  ///
  /// QR lama akan direvoke oleh backend.
  static String get regenerateMyCredentialQr {
    return '$baseUrl/users/me/credential-qr/regenerate';
  }

  /// QR dynamic versi lama.
  ///
  /// GET /users/me/qr
  ///
  /// Jangan digunakan untuk alur QR permanen.
  static String get getMyDynamicQr {
    return '$baseUrl/users/me/qr';
  }

  // ============================================================
  // MACHINE
  // ============================================================

  static String getNearestMachines(double latitude, double longitude) {
    return '$baseUrl/machines/nearest'
        '?latitude=$latitude'
        '&longitude=$longitude';
  }

  static String getMachineById(int id) {
    return '$baseUrl/machines/$id';
  }

  // ============================================================
  // MACHINE SESSION
  // ============================================================

  /// Memulai machine session.
  ///
  /// POST /machine-sessions/start
  static String get startSession {
    return '$baseUrl/machine-sessions/start';
  }

  /// Session milik user.
  ///
  /// GET /machine-sessions/my
  ///
  /// Digunakan ScanPage untuk mendeteksi session baru
  /// setelah mesin membaca QR permanen.
  static String get getMySessionHistory {
    return '$baseUrl/machine-sessions/my';
  }

  /// Detail session.
  ///
  /// GET /machine-sessions/:id
  static String getSessionDetail(String id) {
    return '$baseUrl/machine-sessions/$id';
  }

  /// Complete session.
  ///
  /// POST /machine-sessions/:id/complete
  static String completeSession(String id) {
    return '$baseUrl/machine-sessions/$id/complete';
  }

  /// Confirm session.
  ///
  /// POST /machine-sessions/:id/confirm
  static String confirmSession(String id) {
    return '$baseUrl/machine-sessions/$id/confirm';
  }

  // ============================================================
  // VOUCHERS
  // ============================================================

  /// GET /vouchers/available
  ///
  /// Voucher yang tersedia untuk user.
  static String get getAvailableVouchers {
    return '$baseUrl/vouchers/available';
  }

  /// GET /vouchers/:id
  static String getVoucherById(int id) {
    return '$baseUrl/vouchers/$id';
  }

  // ============================================================
  // LEGACY ACCESS TOKEN
  // ============================================================

  /// Endpoint access-token dynamic QR lama.
  ///
  /// GET /users/access-tokens/:id
  ///
  /// Tidak digunakan oleh ScanPage QR permanen.
  static String getAccessTokenStatus(String id) {
    return '$baseUrl/users/access-tokens/$id';
  }

  // ============================================================
  // PRODUCTS
  // ============================================================

  /// Produk marketplace.
  ///
  /// GET /products/marketplace
  static String get getProducts {
    return '$baseUrl/products/marketplace';
  }

  // ============================================================
  // ORDERS
  // ============================================================

  /// Buat order.
  ///
  /// POST /orders
  static String get createOrder {
    return '$baseUrl/orders';
  }

  /// Order milik user.
  ///
  /// GET /orders/my
  static String get getMyOrders {
    return '$baseUrl/orders/my';
  }

  /// Detail order.
  ///
  /// GET /orders/:id
  static String getOrderById(String id) {
    return '$baseUrl/orders/$id';
  }

  // ============================================================
  // CART
  // ============================================================

  /// GET /cart
  static String get getCart {
    return '$baseUrl/cart';
  }

  /// DELETE /cart
  static String get clearCart {
    return '$baseUrl/cart';
  }

  /// POST /cart/items
  static String get addCartItem {
    return '$baseUrl/cart/items';
  }

  /// PUT /cart/items/:id
  static String updateCartItem(int id) {
    return '$baseUrl/cart/items/$id';
  }

  /// DELETE /cart/items/:id
  static String removeCartItem(int id) {
    return '$baseUrl/cart/items/$id';
  }

  /// GET /cart/preview
  static String get previewCart {
    return '$baseUrl/cart/preview';
  }

  /// POST /cart/checkout
  static String get checkoutCart {
    return '$baseUrl/cart/checkout';
  }

  // ============================================================
  // WALLET
  // ============================================================

  /// Wallet user.
  ///
  /// GET /wallets/me
  static String get getMyWallet {
    return '$baseUrl/wallets/me';
  }

  /// Riwayat transaksi wallet.
  ///
  /// GET /wallets/me/transactions
  static String get getTransactions {
    return '$baseUrl/wallets/me/transactions';
  }

  // ============================================================
  // WALLET TOP UP
  // ============================================================

  /// POST /wallets/topup
  static String get createTopUp {
    return '$baseUrl/wallets/topup';
  }

  /// GET /wallets/topup
  static String get getMyTopUps {
    return '$baseUrl/wallets/topup';
  }

  /// GET /wallets/topup/:id
  static String getTopUpById(int id) {
    return '$baseUrl/wallets/topup/$id';
  }

  /// POST /wallets/topup/:id/mock-pay
  ///
  /// Hanya digunakan untuk local development.
  static String mockPayTopUp(int id) {
    return '$baseUrl/wallets/topup/$id/mock-pay';
  }

  /// POST /wallets/topup/:id/check-status
  static String checkTopUpStatus(int id) {
    return '$baseUrl/wallets/topup/$id/check-status';
  }

  // ============================================================
  // CHARITY & DONATION
  // ============================================================

  /// GET /charities/public
  static String get getPublicCharities {
    return '$baseUrl/charities/public';
  }

  /// GET /donations/me
  static String get getMyDonations {
    return '$baseUrl/donations/me';
  }

  /// GET /charities/:id
  static String getCharityById(int id) {
    return '$baseUrl/charities/$id';
  }

  /// POST /charities/:id/donate
  static String donateToCharity(int id) {
    return '$baseUrl/charities/$id/donate';
  }

  // ============================================================
  // AUTH TOKEN
  // ============================================================

  static String? userToken;

  /// Simpan JWT setelah login berhasil.
  ///
  /// Fungsi ini juga membersihkan prefix "Bearer"
  /// apabila backend secara tidak sengaja mengirim:
  ///
  /// Bearer eyJ...
  ///
  /// sehingga yang disimpan hanya JWT-nya.
  static void setToken(String token) {
    userToken = token
        .replaceFirst(RegExp(r'^Bearer\s+', caseSensitive: false), '')
        .trim();
  }

  /// Hapus token ketika logout
  /// atau ketika token tidak valid.
  static void clearToken() {
    userToken = null;
  }

  /// Mengecek apakah token tersedia.
  static bool get hasToken {
    return userToken != null && userToken!.trim().isNotEmpty;
  }

  // ============================================================
  // HEADERS
  // ============================================================

  /// Header default untuk request setelah login.
  ///
  /// Jika token tersedia:
  ///
  /// Authorization: Bearer <JWT>
  ///
  /// akan otomatis ditambahkan.
  static Map<String, String> get headers {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',

      if (hasToken) 'Authorization': 'Bearer ${userToken!.trim()}',
    };
  }
}
