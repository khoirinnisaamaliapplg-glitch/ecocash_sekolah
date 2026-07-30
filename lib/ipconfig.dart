// import 'dart:io' show Platform;

// class ApiConfig {
//   /// Isi IP komputer ketika menggunakan perangkat Android fisik.
//   ///
//   /// Contoh:
//   /// ApiConfig.customHost = "192.168.1.10";
//   static String? customHost;

//   static const int port = 3000;

//   static String get _host {
//     if (customHost != null &&
//         customHost!.trim().isNotEmpty) {
//       return customHost!.trim();
//     }

//     try {
//       if (Platform.isAndroid) {
//         // Android Emulator mengakses localhost komputer
//         // melalui alamat 10.0.2.2.
//         return '10.0.2.2';
//       }
//     } catch (_) {
//       // Platform tidak tersedia pada Flutter Web.
//     }

//     // Flutter Web, Windows, macOS, dan iOS Simulator.
//     return 'localhost';
//   }

//   static String get baseUrl {
//     return 'http://$_host:$port/api/v1';
//   }

//   // ============================================================
//   // AUTHENTICATION
//   // ============================================================

//   static String get login {
//     return '$baseUrl/auth/login';
//   }

//   static String get register {
//     return '$baseUrl/auth';
//   }

//   // ============================================================
//   // USER
//   // ============================================================

//   static String get getUserProfile {
//     return '$baseUrl/users/me';
//   }

//   static String get updateProfile {
//     return '$baseUrl/users/me';
//   }

//   static String get getMyQr {
//     return '$baseUrl/users/me/qr';
//   }

//   // ============================================================
//   // MACHINE
//   // ============================================================

//   static String getNearestMachines(
//     double latitude,
//     double longitude,
//   ) {
//     return '$baseUrl/machines/nearest'
//         '?latitude=$latitude'
//         '&longitude=$longitude';
//   }

//   static String getMachineById(int id) {
//     return '$baseUrl/machines/$id';
//   }

//   // ============================================================
//   // MACHINE SESSION
//   // ============================================================

//   static String get startSession {
//     return '$baseUrl/machine-sessions/start';
//   }

//   static String get getMySessionHistory {
//     return '$baseUrl/machine-sessions/my';
//   }

//   static String getSessionDetail(String id) {
//     return '$baseUrl/machine-sessions/$id';
//   }

//   static String completeSession(String id) {
//     return '$baseUrl/machine-sessions/$id/complete';
//   }

//   static String confirmSession(String id) {
//     return '$baseUrl/machine-sessions/$id/confirm';
//   }

//   static String getSessionStatus(String id) {
//     return '$baseUrl/users/access-tokens/$id';
//   }

//   // ============================================================
//   // PRODUCTS
//   // ============================================================

//   static String get getProducts {
//     return '$baseUrl/products/marketplace';
//   }

//   // ============================================================
//   // ORDERS
//   // ============================================================

//   static String get createOrder {
//     return '$baseUrl/orders';
//   }

//   static String get getMyOrders {
//     return '$baseUrl/orders/my';
//   }

//   static String getOrderById(String id) {
//     return '$baseUrl/orders/$id';
//   }

//   // ============================================================
//   // CART
//   // ============================================================

//   static String get getCart {
//     return '$baseUrl/cart';
//   }

//   static String get clearCart {
//     return '$baseUrl/cart';
//   }

//   static String get addToCart {
//     return '$baseUrl/cart/items';
//   }

//   static String updateCartItem(int id) {
//     return '$baseUrl/cart/items/$id';
//   }

//   static String removeCartItem(int id) {
//     return '$baseUrl/cart/items/$id';
//   }

//   static String get checkoutCart {
//     return '$baseUrl/cart/checkout';
//   }

//   // ============================================================
//   // WALLET
//   // ============================================================

//   static String get getMyWallet {
//     return '$baseUrl/wallets/me';
//   }

//   static String get getTransactions {
//     return '$baseUrl/wallets/me/transactions';
//   }

//   // ============================================================
//   // TOKEN
//   // ============================================================

//   static String? userToken;

//   static Map<String, String> get headers {
//     return {
//       'Content-Type': 'application/json',
//       'Accept': 'application/json',
//       if (userToken != null &&
//           userToken!.trim().isNotEmpty)
//         'Authorization': 'Bearer ${userToken!.trim()}',
//     };
//   }
// }
class ApiConfig {
  // ============================================================
  // BASE URL PRODUCTION
  // ============================================================

  static const String baseUrl = 'https://api.ecocash.id/api/v1';

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

  static String get getMyQr {
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

  static String get startSession {
    return '$baseUrl/machine-sessions/start';
  }

  static String get getMySessionHistory {
    return '$baseUrl/machine-sessions/my';
  }

  static String getSessionDetail(String id) {
    return '$baseUrl/machine-sessions/$id';
  }

  static String completeSession(String id) {
    return '$baseUrl/machine-sessions/$id/complete';
  }

  static String confirmSession(String id) {
    return '$baseUrl/machine-sessions/$id/confirm';
  }

  static String getSessionStatus(String id) {
    return '$baseUrl/users/access-tokens/$id';
  }

  // ============================================================
  // PRODUCTS
  // ============================================================

  static String get getProducts {
    return '$baseUrl/products/marketplace';
  }

  // ============================================================
  // ORDERS
  // ============================================================

  static String get createOrder {
    return '$baseUrl/orders';
  }

  static String get getMyOrders {
    return '$baseUrl/orders/my';
  }

  static String getOrderById(String id) {
    return '$baseUrl/orders/$id';
  }

  // ============================================================
  // CART
  // ============================================================

  static String get getCart {
    return '$baseUrl/cart';
  }

  static String get clearCart {
    return '$baseUrl/cart';
  }

  static String get addToCart {
    return '$baseUrl/cart/items';
  }

  static String updateCartItem(int id) {
    return '$baseUrl/cart/items/$id';
  }

  static String removeCartItem(int id) {
    return '$baseUrl/cart/items/$id';
  }

  static String get checkoutCart {
    return '$baseUrl/cart/checkout';
  }

  // ============================================================
  // WALLET
  // ============================================================

  static String get getMyWallet {
    return '$baseUrl/wallets/me';
  }

  static String get getTransactions {
    return '$baseUrl/wallets/me/transactions';
  }

  // ============================================================
  // TOKEN
  // ============================================================

  static String? userToken;

  static void setToken(String? token) {
    userToken = token?.trim();
  }

  static void clearToken() {
    userToken = null;
  }

  static Map<String, String> get headers {
    final token = userToken?.trim();

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }
}
