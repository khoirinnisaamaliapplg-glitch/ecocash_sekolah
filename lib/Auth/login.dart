import 'dart:convert';
import 'dart:ui';

import 'package:ecocash_sekolah/Auth/forgot_password.dart';
import 'package:ecocash_sekolah/home.dart';
import 'package:ecocash_sekolah/ipconfig.dart';
import 'package:ecocash_sekolah/app_footer.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // ============================================================
  // PALET WARNA & KONSTANTA STYLING (CRIMSON THEME)
  // ============================================================

  static const Color _primaryCrimson = Color(0xFFA6192E);
  static const Color _primaryCrimsonDark = Color(0xFF8C0D1E);
  static const Color _primaryCrimsonLight = Color(0xFFBA1C30);
  static const Color _textPrimary = Color(0xFF231F20);
  static const Color _textSecondary = Color(0xFF3F3537);
  static const Color _textMuted = Color(0xFF7A6F71);
  static const Color _iconMuted = Color(0xFF8E777A);
  static const Color _inputFill = Color(0xFFFCF7F7);
  static const Color _inputBorder = Color(0xFFE6D5D7);
  static const Color _errorBanner = Color(0xFFC93B3B);

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

    final bool isError = color == Colors.red;
    final bool isWarning = color == Colors.orange;
    final Color resolvedBgColor = isError
        ? _errorBanner
        : isWarning
        ? const Color(0xFFD97706)
        : const Color(0xFF16A34A);

    final IconData statusIcon = isError
        ? Icons.warning_amber_rounded
        : isWarning
        ? Icons.info_outline_rounded
        : Icons.check_circle_outline_rounded;

    final bool showOfflineBadge = message.toLowerCase().contains(
      'tidak dapat terhubung',
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(statusIcon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (showOfflineBadge) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF991B1B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'OFFLINE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ],
          ),
          backgroundColor: resolvedBgColor,
          behavior: SnackBarBehavior.floating,
          elevation: 4,
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 18),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
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
  // INPUT DECORATION HELPER
  // ============================================================

  InputDecoration _buildInputDecoration({
    required String hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFFA89B9D),
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _inputFill,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(26),
        borderSide: const BorderSide(color: _inputBorder, width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(26),
        borderSide: const BorderSide(color: _inputBorder, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(26),
        borderSide: const BorderSide(color: _primaryCrimson, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(26),
        borderSide: const BorderSide(color: _errorBanner, width: 1.2),
      ),
    );
  }

  // ============================================================
  // HEADER BRANDING DENGAN GELOMBANG MERAH
  // ============================================================

  Widget _buildBrandHeader({
    required double topInset,
    required double headerHeight,
    required double logoSize,
  }) {
    return ClipPath(
      clipper: _HeaderWaveClipper(),
      child: Container(
        width: double.infinity,
        height: headerHeight + topInset,
        padding: EdgeInsets.only(top: topInset + 4, bottom: 30),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _primaryCrimsonDark,
              _primaryCrimson,
              _primaryCrimsonLight,
            ],
          ),
        ),
        child: Center(
          child: _InteractiveBrandLogo(
            size: logoSize,
            // Sesuaikan nama file PNG transparan Anda di folder assets/
            assetPath: 'assets/Logo-EcoCashKids-New (2).png',
          ),
        ),
      ),
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
          backgroundColor: Colors.white,
          foregroundColor: _textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          side: const BorderSide(color: Color(0xFFE2D6D8), width: 1.2),
          shape: const StadiumBorder(),
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
                  return Icon(Icons.account_circle, size: 20, color: color);
                },
              )
            else
              Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
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
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              setState(() {
                _rememberMe = !_rememberMe;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Checkbox(
                      value: _rememberMe,
                      activeColor: _primaryCrimson,
                      checkColor: Colors.white,
                      side: const BorderSide(
                        color: Color(0xFFD5C4C6),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                      style: TextStyle(
                        fontSize: 13.5,
                        color: _textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        TextButton(
          onPressed: _openForgotPassword,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Lupa Password?',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: _primaryCrimson,
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
            color: const Color(0xFF1877F2),
          ),
          const SizedBox(height: 12),
          _socialButton(
            label: 'Google',
            imagePath: 'assets/google.png',
            color: const Color(0xFFEA4335),
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
            color: const Color(0xFF1877F2),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _socialButton(
            label: 'Google',
            imagePath: 'assets/google.png',
            color: const Color(0xFFEA4335),
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
          'ATAU MASUK DENGAN',
          style: TextStyle(
            color: _textMuted,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
      );
    }

    return const Row(
      children: [
        Expanded(child: Divider(color: Color(0xFFECE2E3), thickness: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'ATAU MASUK DENGAN',
            style: TextStyle(
              color: _textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Expanded(child: Divider(color: Color(0xFFECE2E3), thickness: 1)),
      ],
    );
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final double topInset = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final double screenWidth = constraints.maxWidth;
            final double screenHeight = constraints.maxHeight;

            final bool compactLayout = screenWidth < 360 || screenHeight < 700;

            final double horizontalPadding = screenWidth < 220
                ? 12
                : screenWidth < 360
                ? 18
                : 24;

            final double headerHeight = screenHeight < 650
                ? 175
                : compactLayout
                ? 200
                : 235;

            final double logoSize = screenHeight < 650
                ? 92
                : compactLayout
                ? 106
                : 120;

            final double titleSize = screenWidth < 300 ? 24 : 28;

            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: screenHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // =========================================
                    // LOGO ECOCASH SEKOLAH (HERO MERAH)
                    // =========================================
                    _buildBrandHeader(
                      topInset: topInset,
                      headerHeight: headerHeight,
                      logoSize: logoSize,
                    ),

                    // =========================================
                    // FORM CONTAINER
                    // =========================================
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: compactLayout ? 10 : 16),

                          // =========================================
                          // TITLE
                          // =========================================
                          Text(
                            'Masuk',
                            style: TextStyle(
                              fontSize: titleSize,
                              fontWeight: FontWeight.w800,
                              color: _textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Sign in to continue',
                            style: TextStyle(
                              fontSize: 14,
                              color: _textMuted,
                              fontWeight: FontWeight.w400,
                            ),
                          ),

                          SizedBox(height: compactLayout ? 18 : 24),

                          // =========================================
                          // EMAIL / USERNAME
                          // =========================================
                          const Text(
                            'Email atau Username',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: _textSecondary,
                            ),
                          ),

                          const SizedBox(height: 8),

                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(
                              fontSize: 14.5,
                              color: _textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: _buildInputDecoration(
                              hintText: 'email atau username',
                              prefixIcon: screenWidth < 220
                                  ? null
                                  : const Icon(
                                      Icons.person_outline_rounded,
                                      color: _iconMuted,
                                      size: 21,
                                    ),
                            ),
                          ),

                          SizedBox(height: compactLayout ? 14 : 18),

                          // =========================================
                          // PASSWORD
                          // =========================================
                          const Text(
                            'Password',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: _textSecondary,
                            ),
                          ),

                          const SizedBox(height: 8),

                          TextField(
                            controller: _passwordController,
                            obscureText: _obscureText,
                            textInputAction: TextInputAction.done,
                            style: const TextStyle(
                              fontSize: 14.5,
                              color: _textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                            onSubmitted: (_) {
                              if (!_isLoading) {
                                _handleLogin();
                              }
                            },
                            decoration: _buildInputDecoration(
                              hintText: '••••••••••••',
                              prefixIcon: screenWidth < 220
                                  ? null
                                  : const Icon(
                                      Icons.lock_outline_rounded,
                                      color: _iconMuted,
                                      size: 21,
                                    ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureText
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: _iconMuted,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureText = !_obscureText;
                                  });
                                },
                              ),
                            ),
                          ),

                          SizedBox(height: compactLayout ? 8 : 12),

                          _buildRememberForgot(screenWidth),

                          SizedBox(height: compactLayout ? 16 : 22),

                          // =========================================
                          // LOGIN BUTTON
                          // =========================================
                          Container(
                            width: double.infinity,
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(26),
                              gradient: _isLoading
                                  ? null
                                  : const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        _primaryCrimsonLight,
                                        _primaryCrimsonDark,
                                      ],
                                    ),
                              boxShadow: _isLoading
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: _primaryCrimsonDark.withValues(
                                          alpha: 0.28,
                                        ),
                                        blurRadius: 14,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                disabledBackgroundColor: _primaryCrimson
                                    .withValues(alpha: 0.5),
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(26),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Masuk',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                            ),
                          ),

                          SizedBox(height: compactLayout ? 20 : 28),

                          _buildDivider(screenWidth),

                          SizedBox(height: compactLayout ? 16 : 22),

                          _buildSocialLogin(screenWidth),

                          // No self-registration here on purpose: school member
                          // accounts are created by the school organization admin
                          // through the admin panel, not from this app.
                          SizedBox(height: compactLayout ? 22 : 32),

                          // =========================================
                          // FOOTER ECOCASH SEKOLAH
                          // =========================================
                          const AppFooter(),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ============================================================
// WIDGET LOGO MELINGKAR + AURA & SHADOW MERAH HALUS
// ============================================================

class _InteractiveBrandLogo extends StatefulWidget {
  final double size;
  final String assetPath;

  const _InteractiveBrandLogo({required this.size, required this.assetPath});

  @override
  State<_InteractiveBrandLogo> createState() => _InteractiveBrandLogoState();
}

class _InteractiveBrandLogoState extends State<_InteractiveBrandLogo> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bool isActive = _isHovered || _isPressed;
    final double targetScale = _isPressed
        ? 0.95
        : _isHovered
        ? 1.05
        : 1.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isPressed = _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: targetScale,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // Pendaran merah gelap transparan tanpa garis lingkar putih
              // agar logo menyatu alami dengan latar hero merah
              color: const Color(
                0xFF4E0510,
              ).withValues(alpha: isActive ? 0.30 : 0.22),
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0xFF45030D,
                  ).withValues(alpha: isActive ? 0.42 : 0.30),
                  blurRadius: isActive ? 22 : 16,
                  spreadRadius: isActive ? 2 : 0,
                  offset: Offset(0, isActive ? 8 : 5),
                ),
              ],
            ),
            child: ClipOval(
              child: Padding(
                padding: EdgeInsets.all(widget.size * 0.05),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Bayangan merah tipis mengikuti kontur asli logo
                    Transform.translate(
                      offset: Offset(0, isActive ? 4 : 2.5),
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(
                          sigmaX: isActive ? 5 : 3.5,
                          sigmaY: isActive ? 5 : 3.5,
                        ),
                        child: ColorFiltered(
                          colorFilter: ColorFilter.mode(
                            const Color(
                              0xFF3B020A,
                            ).withValues(alpha: isActive ? 0.34 : 0.24),
                            BlendMode.srcIn,
                          ),
                          child: Image.asset(
                            widget.assetPath,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),

                    // Gambar logo utama (fallback ke logokids.jpeg jika perlu)
                    Image.asset(
                      widget.assetPath,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Image.asset(
                          'assets/logokids.jpeg',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.eco_rounded,
                            size: widget.size * 0.5,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// CUSTOM CLIPPER UNTUK GELOMBANG HEADER MERAH
// ============================================================

class _HeaderWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final Path path = Path();
    path.lineTo(0, size.height - 26);

    // Lengkungan gelombang pertama (turun halus di kiri-tengah)
    path.quadraticBezierTo(
      size.width * 0.28,
      size.height,
      size.width * 0.55,
      size.height - 14,
    );

    // Lengkungan gelombang kedua (naik halus ke kanan)
    path.quadraticBezierTo(
      size.width * 0.80,
      size.height - 28,
      size.width,
      size.height - 12,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
