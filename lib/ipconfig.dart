class ApiConfig {
  static const String baseUrl =
      "http://localhost:3000/api/v1"; // GANTI KE IP LAPTOP KAMU

  static const String login = "$baseUrl/auth/login";
  static const String getMyQr = "$baseUrl/users/me/qr";
  static String confirmSession(String id) =>
      "$baseUrl/machine-sessions/$id/confirm";
  static String getSessionDetail(String token) =>
      "$baseUrl/users/access-tokens/$token";

  static const String getMyWallet = "$baseUrl/wallets/me";
  static const String getTransactions = "$baseUrl/wallets/me/transactions";
  // Variabel untuk menyimpan token setelah login
  static String? userToken;

  static Map<String, String> get headers {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (userToken != null) 'Authorization': 'Bearer $userToken',
    };
  }
}
