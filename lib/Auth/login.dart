import 'dart:convert';

import 'package:ecocash_sekolah/home.dart';
import 'package:ecocash_sekolah/Auth/registrasi.dart';
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

      final response = await http.post(
        Uri.parse(ApiConfig.login),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'identifier': identifier, 'password': password}),
      );

      debugPrint('');
      debugPrint('LOGIN STATUS : ${response.statusCode}');
      debugPrint('LOGIN BODY   : ${response.body}');
      debugPrint('');

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
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 50),

              // ==================================================
              // LOGO ECOCASH SEKOLAH
              // ==================================================
              Center(
                child: Image.asset(
                  'assets/logokids.jpeg',
                  height: 150,

                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.eco_rounded,
                      size: 100,
                      color: Colors.green,
                    );
                  },
                ),
              ),

              const SizedBox(height: 40),

              // ==================================================
              // SIGN IN
              // ==================================================
              const Text(
                'Sign In',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1D2939),
                ),
              ),

              const SizedBox(height: 24),

              // ==================================================
              // USERNAME / EMAIL LABEL
              // ==================================================
              const Text(
                'Username or Email',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF344054),
                ),
              ),

              const SizedBox(height: 8),

              // ==================================================
              // USERNAME / EMAIL FIELD
              // ==================================================
              TextField(
                controller: _emailController,

                keyboardType: TextInputType.text,

                textInputAction: TextInputAction.next,

                decoration: InputDecoration(
                  hintText: 'username',

                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ==================================================
              // PASSWORD LABEL
              // ==================================================
              const Text(
                'Password',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF344054),
                ),
              ),

              const SizedBox(height: 8),

              // ==================================================
              // PASSWORD FIELD
              // ==================================================
              TextField(
                controller: _passwordController,

                obscureText: _obscureText,

                textInputAction: TextInputAction.done,

                /*
                 * User bisa tekan Enter
                 * untuk login.
                 */
                onSubmitted: (_) {
                  if (!_isLoading) {
                    _handleLogin();
                  }
                },

                decoration: InputDecoration(
                  hintText: '************',

                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureText
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),

                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  ),

                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ==================================================
              // REMEMBER + FORGOT PASSWORD
              // ==================================================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,

                        onChanged: (value) {
                          setState(() {
                            _rememberMe = value ?? false;
                          });
                        },
                      ),

                      const Text('Remember me'),
                    ],
                  ),

                  TextButton(
                    onPressed: () {},

                    child: const Text('Forgot password?'),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ==================================================
              // LOGIN BUTTON
              // ==================================================
              SizedBox(
                width: double.infinity,
                height: 52,

                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,

                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
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
                          'Login',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 30),

              // ==================================================
              // DIVIDER
              // ==================================================
              const Row(
                children: [
                  Expanded(child: Divider()),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),

                    child: Text(
                      'Or Sign In with',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),

                  Expanded(child: Divider()),
                ],
              ),

              const SizedBox(height: 24),

              // ==================================================
              // SOCIAL LOGIN
              // ==================================================
              Row(
                children: [
                  Expanded(
                    child: _socialButton(
                      'Facebook',

                      Image.asset(
                        'assets/facebook.png',
                        height: 24.0,
                        width: 24.0,
                      ),

                      Colors.blue,
                    ),
                  ),

                  const SizedBox(width: 16),

                  Expanded(
                    child: _socialButton(
                      'Google',

                      Image.asset(
                        'assets/google.png',
                        height: 24.0,
                        width: 24.0,
                      ),

                      Colors.red,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // ==================================================
              // REGISTER
              // ==================================================
              Center(
                child: Wrap(
                  children: [
                    const Text("Don't have an account? "),

                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,

                          MaterialPageRoute(
                            builder: (context) => const RegisterPage(),
                          ),
                        );
                      },

                      child: const Text(
                        'Sign Up',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ==================================================
              // FOOTER ECOCASH SEKOLAH
              // ==================================================
              const AppFooter(),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SOCIAL BUTTON
  // ============================================================

  Widget _socialButton(String label, Widget iconWidget, Color color) {
    return OutlinedButton.icon(
      onPressed: () {},

      icon: iconWidget,

      label: Text(label, style: const TextStyle(color: Color(0xFF344054))),

      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
