import 'dart:convert';

import 'package:ecocash_sekolah/Auth/forgot_password.dart';
import 'package:ecocash_sekolah/home.dart';
import 'package:ecocash_sekolah/ipconfig.dart';
import 'package:ecocash_sekolah/app_footer.dart';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // ============================================================
  // CONTROLLER
  // ============================================================

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // ============================================================
  // STATE
  // ============================================================

  bool _rememberMe = true;
  bool _obscureText = true;
  bool _isLoading = false;

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<void> _handleLogin() async {
    final String identifier = _emailController.text.trim();
    final String password = _passwordController.text;

    // ==========================================================
    // VALIDATION
    // ==========================================================

    if (identifier.isEmpty || password.isEmpty) {
      _showSnackBar('Username/Email dan Password wajib diisi', Colors.orange);

      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('');
      debugPrint('========================================');
      debugPrint('LOGIN ECOCASH SEKOLAH');
      debugPrint('URL        : ${ApiConfig.login}');
      debugPrint('IDENTIFIER : $identifier');
      debugPrint('========================================');
      debugPrint('');

      // ========================================================
      // REQUEST LOGIN
      // ========================================================

      /*
       * Untuk login jangan menggunakan ApiConfig.headers.
       *
       * Alasannya:
       * ApiConfig.headers kemungkinan memasukkan Authorization
       * dari token login sebelumnya.
       *
       * Login cukup menggunakan Content-Type dan Accept.
       */

      final response = await http
          .post(
            Uri.parse(ApiConfig.login),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'identifier': identifier,
              'password': password,
              // Identifies this client: the API only admits members of a SCHOOL
              // organization when `app` is SCHOOL, and answers
              // 403 SCHOOL_MEMBER_REQUIRED otherwise.
              'app': 'SCHOOL',
            }),
          )
          // Without a timeout a stopped/unreachable API leaves the login button
          // spinning forever; this makes the existing catch block report it.
          .timeout(const Duration(seconds: 15));

      // Only the status is logged. The response body contains the JWT, and
      // debugPrint output ends up in logcat / the IDE console, where the token
      // would be readable by anyone with access to the device's logs.
      debugPrint('LOGIN STATUS : ${response.statusCode}');

      // ========================================================
      // PARSE RESPONSE
      // ========================================================

      dynamic responseData;

      try {
        responseData = jsonDecode(response.body);
      } catch (error) {
        debugPrint('LOGIN RESPONSE BUKAN JSON: $error');

        if (!mounted) {
          return;
        }

        _showSnackBar('Response server tidak valid.', Colors.red);

        return;
      }

      // ========================================================
      // LOGIN SUCCESS
      // ========================================================

      if (response.statusCode == 200) {
        // ======================================================
        // VALIDATE RESPONSE DATA
        // ======================================================

        if (responseData is! Map) {
          if (!mounted) {
            return;
          }

          _showSnackBar('Format response login tidak valid.', Colors.red);

          return;
        }

        final dynamic data = responseData['data'];

        if (data == null || data is! Map) {
          if (!mounted) {
            return;
          }

          _showSnackBar('Data login tidak ditemukan.', Colors.red);

          return;
        }

        // ======================================================
        // GET TOKEN
        // ======================================================

        final String? token = data['token']?.toString().trim();

        if (token == null || token.isEmpty) {
          debugPrint('');
          debugPrint('ERROR LOGIN: TOKEN TIDAK DITEMUKAN');
          debugPrint('');

          if (!mounted) {
            return;
          }

          _showSnackBar('Token login tidak ditemukan.', Colors.red);

          return;
        }

        // ======================================================
        // SAVE TOKEN
        // ======================================================

        /*
         * SAMA DENGAN ECOCASH INDONESIA.
         *
         * Jangan:
         *
         * ApiConfig.userToken = token;
         *
         * Sebaiknya:
         *
         * ApiConfig.setToken(token);
         *
         * Supaya seluruh request:
         *
         * users/me
         * credential-qr
         * machine-sessions/my
         * wallet
         * carbon
         *
         * otomatis memperoleh Authorization:
         *
         * Bearer TOKEN
         */

        ApiConfig.setToken(token);

        /*
         * Respons login adalah satu-satunya sumber data organisasi (sekolah)
         * pengguna; simpan untuk profil. `clearToken()` membersihkannya lagi,
         * termasuk saat token kedaluwarsa atau ditolak server.
         */
        ApiConfig.setCurrentUser(data['user']);

        debugPrint('');
        debugPrint('========== TOKEN LOGIN SEKOLAH ==========');
        debugPrint('TOKEN SAVED : ${ApiConfig.hasToken}');
        debugPrint('TOKEN LENGTH: ${ApiConfig.userToken?.length}');
        debugPrint(
          'AUTH HEADER : '
          '${ApiConfig.headers.containsKey('Authorization')}',
        );
        debugPrint('==========================================');
        debugPrint('');

        // ======================================================
        // CHECK TOKEN EXPIRED
        // ======================================================

        try {
          if (JwtDecoder.isExpired(token)) {
            ApiConfig.clearToken();

            if (!mounted) {
              return;
            }

            _showSnackBar('Token login sudah kedaluwarsa.', Colors.red);

            return;
          }
        } catch (error) {
          debugPrint('JWT EXPIRED CHECK ERROR: $error');

          ApiConfig.clearToken();

          if (!mounted) {
            return;
          }

          _showSnackBar('Token login tidak valid.', Colors.red);

          return;
        }

        // ======================================================
        // DECODE JWT
        // ======================================================

        Map<String, dynamic> decodedToken;

        try {
          decodedToken = JwtDecoder.decode(token);
        } catch (error) {
          debugPrint('');
          debugPrint('JWT DECODE ERROR: $error');
          debugPrint('');

          /*
           * Token gagal decode berarti jangan disimpan.
           */
          ApiConfig.clearToken();

          if (!mounted) {
            return;
          }

          _showSnackBar('Token login tidak valid.', Colors.red);

          return;
        }

        debugPrint('');
        debugPrint('========================================');
        debugPrint('DECODED TOKEN');
        debugPrint('$decodedToken');
        debugPrint('========================================');
        debugPrint('');

        // ======================================================
        // GET ROLE
        // ======================================================

        final String role = (decodedToken['role'] ?? '')
            .toString()
            .toUpperCase()
            .trim();

        debugPrint('USER ROLE SEKOLAH: $role');

        // ======================================================
        // ROLE VALIDATION
        // ======================================================

        /*
         * Sementara disamakan dengan EcoCash Indonesia:
         *
         * Mobile app hanya menerima REGULAR_USER.
         *
         * Kalau backend EcoCash Sekolah nanti memiliki role:
         *
         * STUDENT
         * TEACHER
         * SCHOOL_ADMIN
         *
         * bagian ini bisa disesuaikan.
         */

        if (role == 'REGULAR_USER') {
          if (!mounted) {
            return;
          }

          // ====================================================
          // LOGIN SUCCESS
          // ====================================================

          _showSnackBar('Selamat Datang!', Colors.green);

          /*
           * Tidak perlu Future.delayed.
           *
           * Setelah token valid langsung masuk Home.
           */

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );

          return;
        }

        // ======================================================
        // INVALID ROLE
        // ======================================================

        /*
         * Jika role bukan mobile user,
         * token harus dihapus kembali.
         */

        ApiConfig.clearToken();

        if (!mounted) {
          return;
        }

        _showSnackBar("Role '$role' tidak memiliki akses mobile.", Colors.red);

        return;
      }

      // ========================================================
      // LOGIN FAILED
      // ========================================================

      String errorMessage = 'Login gagal';

      if (responseData is Map) {
        final dynamic message = responseData['message'];

        if (message != null && message.toString().trim().isNotEmpty) {
          errorMessage = message.toString();
        }

        /*
         * Beberapa backend menggunakan:
         *
         * error
         * errors
         *
         * sebagai pesan error.
         */

        if (errorMessage == 'Login gagal') {
          final dynamic error = responseData['error'];

          if (error != null && error.toString().trim().isNotEmpty) {
            errorMessage = error.toString();
          }
        }
      }

      // ========================================================
      // STATUS ERROR
      // ========================================================

      debugPrint('');
      debugPrint('========================================');
      debugPrint('LOGIN GAGAL');
      debugPrint('STATUS  : ${response.statusCode}');
      debugPrint('MESSAGE : $errorMessage');
      debugPrint('========================================');
      debugPrint('');

      if (!mounted) {
        return;
      }

      // ========================================================
      // SPECIAL STATUS
      // ========================================================

      if (response.statusCode == 401) {
        _showSnackBar(
          errorMessage.isNotEmpty
              ? errorMessage
              : 'Username/Email atau Password salah.',
          Colors.red,
        );

        return;
      }

      if (response.statusCode == 403) {
        _showSnackBar(
          errorMessage.isNotEmpty ? errorMessage : 'Akun tidak memiliki akses.',
          Colors.red,
        );

        return;
      }

      if (response.statusCode == 404) {
        _showSnackBar(
          errorMessage.isNotEmpty ? errorMessage : 'Akun tidak ditemukan.',
          Colors.red,
        );

        return;
      }

      if (response.statusCode >= 500) {
        _showSnackBar('Server EcoCash sedang mengalami gangguan.', Colors.red);

        return;
      }

      _showSnackBar(errorMessage, Colors.red);
    } catch (error, stackTrace) {
      // ========================================================
      // NETWORK / SERVER ERROR
      // ========================================================

      debugPrint('');
      debugPrint('========== LOGIN ERROR ==========');
      debugPrint('$error');
      debugPrintStack(stackTrace: stackTrace);
      debugPrint('=================================');
      debugPrint('');

      if (!mounted) {
        return;
      }

      _showSnackBar('Tidak dapat terhubung ke server EcoCash.', Colors.red);
    } finally {
      // ========================================================
      // STOP LOADING
      // ========================================================

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _showSnackBar(String message, Color color) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ============================================================
  // FORGOT PASSWORD
  // ============================================================

  void _openForgotPassword() {
    // `POST /auth/forgot-password` mengirim tautan reset ke email pengguna.
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
    );
  }

  // ============================================================
  // SOCIAL BUTTON
  // ============================================================

  Widget _socialButton({
    required String label,
    IconData? icon,
    String? imagePath,
    required Color color,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          side: const BorderSide(color: Color(0xFFD0D5DD)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imagePath != null)
              Image.asset(
                imagePath,
                height: 20,
                width: 20,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.account_circle,
                    size: 20,
                  );
                },
              )
            else
              Icon(
                icon,
                color: color,
                size: 20,
              ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF344054),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // REMEMBER + FORGOT
  // ============================================================

  Widget _buildRememberForgot(double width) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _rememberMe,
                  materialTapTargetSize:
                      MaterialTapTargetSize.shrinkWrap,
                  onChanged: (value) {
                    setState(() {
                      _rememberMe = value ?? false;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  'Ingat Saya',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: _openForgotPassword,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Lupa Password?',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF2E7D32),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SOCIAL LOGIN
  // ============================================================

  Widget _buildSocialLogin(double width) {
    if (width < 360) {
      return Column(
        children: [
          _socialButton(
            label: 'Facebook',
            imagePath: 'assets/facebook.png',
            color: Colors.blue,
          ),
          const SizedBox(height: 12),
          _socialButton(
            label: 'Google',
            imagePath: 'assets/google.png',
            color: Colors.red,
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _socialButton(
            label: 'Facebook',
            imagePath: 'assets/facebook.png',
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _socialButton(
            label: 'Google',
            imagePath: 'assets/google.png',
            color: Colors.red,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // DIVIDER
  // ============================================================

  Widget _buildDivider(double width) {
    if (width < 220) {
      return const Center(
        child: Text(
          'Atau Masuk Dengan',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 11,
          ),
        ),
      );
    }

    return const Row(
      children: [
        Expanded(child: Divider()),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'Atau Masuk Dengan',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(child: Divider()),
      ],
    );
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double screenWidth = constraints.maxWidth;
            final double screenHeight = constraints.maxHeight;

            final bool compactLayout =
                screenWidth < 360 || screenHeight < 700;

            final double horizontalPadding = screenWidth < 220
                ? 10
                : screenWidth < 360
                    ? 16
                    : 24;

            final double logoHeight =
                screenWidth < 220 || screenHeight < 600
                    ? 80
                    : screenWidth < 360
                        ? 100
                        : 150;

            final double topSpacing = screenHeight < 600
                ? 12
                : screenWidth < 360
                    ? 24
                    : 50;

            final double titleSize =
                screenWidth < 300 ? 22 : 24;

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: topSpacing),

                      // =========================================
                      // LOGO ECOCASH SEKOLAH
                      // =========================================
                      Center(
                        child: Image.asset(
                          'assets/logokids.jpeg',
                          height: logoHeight,
                          fit: BoxFit.contain,
                          errorBuilder:
                              (context, error, stackTrace) {
                            return Icon(
                              Icons.eco_rounded,
                              size: logoHeight * 0.7,
                              color: const Color(0xFF2E7D32),
                            );
                          },
                        ),
                      ),

                      SizedBox(
                        height: compactLayout ? 20 : 40,
                      ),

                      // =========================================
                      // TITLE
                      // =========================================
                      Text(
                        'Masuk',
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1D2939),
                        ),
                      ),

                      SizedBox(
                        height: compactLayout ? 16 : 24,
                      ),

                      // =========================================
                      // EMAIL / USERNAME
                      // =========================================
                      const Text(
                        'Email atau Username',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF344054),
                        ),
                      ),

                      const SizedBox(height: 8),

                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: 'email atau username',
                          prefixIcon: screenWidth < 220
                              ? null
                              : const Icon(
                                  Icons.person_outline,
                                ),
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(8),
                          ),
                        ),
                      ),

                      SizedBox(
                        height: compactLayout ? 14 : 20,
                      ),

                      // =========================================
                      // PASSWORD
                      // =========================================
                      const Text(
                        'Password',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF344054),
                        ),
                      ),

                      const SizedBox(height: 8),

                      TextField(
                        controller: _passwordController,
                        obscureText: _obscureText,
                        textInputAction:
                            TextInputAction.done,
                        onSubmitted: (_) {
                          if (!_isLoading) {
                            _handleLogin();
                          }
                        },
                        decoration: InputDecoration(
                          hintText: '************',
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 16,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureText
                                  ? Icons.visibility_outlined
                                  : Icons
                                      .visibility_off_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureText =
                                    !_obscureText;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(8),
                          ),
                        ),
                      ),

                      SizedBox(
                        height: compactLayout ? 6 : 10,
                      ),

                      _buildRememberForgot(screenWidth),

                      SizedBox(
                        height: compactLayout ? 14 : 22,
                      ),

                      // =========================================
                      // LOGIN BUTTON
                      // =========================================
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : _handleLogin,
                          style:
                              ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(0xFF2E7D32),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Masuk',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),

                      SizedBox(
                        height: compactLayout ? 20 : 30,
                      ),

                      _buildDivider(screenWidth),

                      SizedBox(
                        height: compactLayout ? 16 : 24,
                      ),

                      _buildSocialLogin(screenWidth),

                      // No self-registration here on purpose: school member
                      // accounts are created by the school organization admin
                      // through the admin panel, not from this app.
                      SizedBox(
                        height: compactLayout ? 24 : 38,
                      ),

                      // =========================================
                      // FOOTER ECOCASH SEKOLAH
                      // =========================================
                      const AppFooter(),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
