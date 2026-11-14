class ApiConfig {
  // ============================================================
  // BASE URL
  // ============================================================
  //
  // The default stays local for development. Override it without editing code:
  //
  //   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1 \
  //               --dart-define=API_SOCKET_URL=http://10.0.2.2:3000/sessions
  //
  // Notes:
  //  - Android emulator: `localhost` is the emulator itself, use 10.0.2.2.
  //  - Physical device: use the machine's LAN IP (or the WSL IP if the API runs
  //    in WSL), and make sure the phone is on the same network.
  //  - Release builds against a real server must use https, because Android
  //    blocks cleartext HTTP by default (API 28+).

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api/v1',
  );

  static const String socketUrl = String.fromEnvironment(
    'API_SOCKET_URL',
    defaultValue: 'http://localhost:3000/sessions',
  );

  /// Halaman akun berbasis web (reset kata sandi & verifikasi email).
  ///
  /// Kedua alur itu **tidak** diimplementasikan di aplikasi: tautan di email
  /// mengarah ke sini, dan pengguna menyelesaikannya di browser.
  static const String accountUrl = 'https://account.ecocash.id';

  // ============================================================
  // AUTHENTICATION
  // ============================================================

  static String get login => '$baseUrl/auth/login';
  static String get register => '$baseUrl/auth';
  static String get logout => '$baseUrl/auth/logout';

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

  /// `POST /upload/single` (multipart) — dipakai untuk foto profil.
  /// Field `category` HARUS dikirim sebelum file (folder tujuan di server).
  static String get uploadSingle => '$baseUrl/upload/single';

  static String get getUserProfile => '$baseUrl/users/me';

  /// Organisasi (sekolah) pengguna + admin yang mengelolanya:
  /// `{ organization: {...}, admin: { id, name, phoneNumber, avatarUrl } }`.
  static String get myOrganization => '$baseUrl/users/me/organization';
  static String get updateProfile => '$baseUrl/users/me';
  static String get getMyProfile => getUserProfile;

  /// Email has its own endpoint: `PATCH /users/me` only accepts name/username,
  /// and this one is refused once the address is verified
  /// (400 `EMAIL_ALREADY_VERIFIED`).
  static String get changeEmail => '$baseUrl/users/me/email';

  /// `PATCH /users/me/password` → body `{ currentPassword, newPassword }`.
  static String get changePassword => '$baseUrl/users/me/password';

  static String get getMyCarbon => '$baseUrl/users/me/carbon';

  // ============================================================
  // NOTIFICATIONS (in-app)
  // ============================================================

  /// `GET /notifications?page&limit&isRead` →
  /// `{ notifications, unreadCount, meta }`.
  static String get notifications => '$baseUrl/notifications';

  static String notificationRead(int id) => '$baseUrl/notifications/$id/read';

  static String get notificationsReadAll => '$baseUrl/notifications/read-all';

  // ============================================================
  // USER QR CREDENTIAL
  // ============================================================

  // The QR a user shows is the persistent credential below. The old 30-second
  // dynamic QR (`/users/me/qr`) was removed from the API, so its entry here is
  // gone too - calling it would only produce a 404.
  static String get getMyCredentialQr => '$baseUrl/users/me/credential-qr';
  static String get regenerateMyCredentialQr =>
      '$baseUrl/users/me/credential-qr/regenerate';

  // ============================================================
  // MACHINE & SESSION (V2 SPECIFICATION)
  // ============================================================

  static String getNearestMachines(double latitude, double longitude) {
    return '$baseUrl/machines/nearest?latitude=$latitude&longitude=$longitude';
  }

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
  // PRODUCTS & ORDERS & CART
  // ============================================================
  // NOTE: the legacy `/users/access-tokens/:id` helper was removed from the API
  // together with the dynamic QR flow, so it is no longer configured here.

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

  /*
   * Data pengguna dari respons login.
   *
   * `GET /users/me` tidak menyertakan organisasi, sedangkan login
   * menyertakannya (`user.organization = { id, name, type }`). Nilainya
   * disimpan di memori - seumur sesi, sama seperti token - supaya Profil bisa
   * menampilkan sekolah pengguna tanpa perubahan backend.
   *
   * Catatan: kalau nanti sesi dipulihkan dari penyimpanan aman saat app dibuka
   * ulang, simpan juga organisasinya; kalau tidak, baris sekolah akan kosong
   * sampai pengguna login kembali.
   */
  static Map<String, dynamic>? currentUser;
  static Map<String, dynamic>? currentOrganization;

  static void setCurrentUser(dynamic user) {
    if (user is! Map) {
      currentUser = null;
      currentOrganization = null;
      return;
    }

    currentUser = Map<String, dynamic>.from(user);

    final dynamic organization = currentUser?['organization'];

    currentOrganization = organization is Map
        ? Map<String, dynamic>.from(organization)
        : null;
  }

  static void clearToken() {
    userToken = null;
    currentUser = null;
    currentOrganization = null;
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
