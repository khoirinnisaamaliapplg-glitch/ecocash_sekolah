class ApiConfig {
  static const String baseUrl = "http://localhost:3000/api/v1";

  // --- Auth ---
  static const String login = "$baseUrl/auth/login";
  static const String register = "$baseUrl/auth";

  // --- Machine Sessions ---
  static const String startSession = "$baseUrl/machine-sessions/start";
  static const String getMySessionHistory = "$baseUrl/machine-sessions/my";

  static String getSessionDetail(String id) => "$baseUrl/machine-sessions/$id";
  static String completeSession(String id) =>
      "$baseUrl/machine-sessions/$id/complete";
  static String confirmSession(String id) =>
      "$baseUrl/machine-sessions/$id/confirm";

  // --- Wallet & Transactions ---
  static const String getMyQr = "$baseUrl/users/me/qr";
  static const String getMyWallet = "$baseUrl/wallets/me";
  static const String getTransactions = "$baseUrl/wallets/me/transactions";

  // --- Cart ---
  // static const String getCart = "$baseUrl/cart";
  // static const String clearCart = "$baseUrl/cart";
  // static const String addToCart = "$baseUrl/cart/items";
  // static String updateCartItem(int id) => "$baseUrl/cart/items/$id";
  // static String removeCartItem(int id) => "$baseUrl/cart/items/$id";
  // static const String checkoutCart = "$baseUrl/cart/checkout";

  // --- Order ---
  // static const String createOrder = "$baseUrl/orders";
  // static const String getMyOrders = "$baseUrl/orders/my";
  // static String getOrderById(String id) => "$baseUrl/orders/$id";

  // --- Product ---
  // static const String getProducts = "$baseUrl/products/marketplace";

  // --- Utility ---
  static String? userToken;

  static Map<String, String> get headers {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (userToken != null) 'Authorization': 'Bearer $userToken',
    };
  }
}
