import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../utils/error_messages.dart';
import '../utils/platform_helper.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _auth = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  
  bool _isLoading = false;
  String? _error;
  bool _showForgotPassword = false;
  bool _showForgotEmail = false;

  // Yeni Durumlar
  bool _isPhoneLogin = false; // Varsayılan artık e-posta girişi
  bool _isCodeSent = false;
  String? _verificationId;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 10) {
      setState(() => _error = 'Lütfen geçerli bir telefon numarası girin.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (await _auth.isDeviceBanned()) {
        setState(() {
          _isLoading = false;
          _error = 'Güvenlik Protokolü: Bu cihaz engellenmiştir.';
        });
        return;
      }

      // Başına +90 ekle (Eğer yoksa)
      String formattedPhone = phone;
      if (!phone.startsWith('+')) {
        formattedPhone = '+90${phone.startsWith('0') ? phone.substring(1) : phone}';
      }

      await _auth.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Otomatik doğrulama (Android için bazen)
          await _auth.signInWithPhoneCredential(credential.verificationId!, credential.smsCode!);
          if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _isLoading = false;
            _error = ErrorMessages.parseAuthError(e);
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _isLoading = false;
            _isCodeSent = true;
            _verificationId = verificationId;
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Bir hata oluştu. Lütfen tekrar deneyin.';
      });
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.length < 6) {
      setState(() => _error = 'Lütfen 6 haneli kodu girin.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final credential = await _auth.signInWithPhoneCredential(_verificationId!, code);
      if (credential != null && mounted) {
        // Yeni kullanıcı mı kontrol et? AuthWrapper hallediyor ama pre-fill için:
        if (credential.additionalUserInfo?.isNewUser ?? false) {
           AuthService.pendingData = {
             'phone': _phoneController.text.trim(),
           };
        }
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Hatalı kod. Lütfen tekrar deneyin.';
      });
    }
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Lütfen e-posta ve şifrenizi girin.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _showForgotPassword = false;
      _showForgotEmail = false;
    });

    try {
      if (await _auth.isDeviceBanned()) {
        setState(() {
          _isLoading = false;
          _error = 'Güvenlik Protokolü: Bu cihaz üzerinden erişim kalıcı olarak engellenmiştir.';
        });
        return;
      }
      await _auth.signInWithEmailAndPassword(email, password);
      
      if (mounted) {
        // Giriş başarılı, dialogdan gelmişsek dialogu kapat, 
        // ana sayfaya yönlendirmeyi AuthWrapper otomatik yapacak.
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = ErrorMessages.parseAuthError(e);
        bool isRegistered = await _auth.isEmailRegistered(email);
        
        setState(() {
          _isLoading = false;
          _error = errorMessage;
          if ((errorMessage.contains('hatalı') || errorMessage.contains('credential')) && isRegistered) {
             _showForgotPassword = true;
          } else if (!isRegistered && (errorMessage.contains('hatalı') || errorMessage.contains('credential'))) {
            _error = 'Bu e-posta adresi ile kayıtlı bir hesap bulunamadı.';
            _showForgotEmail = true;
          }
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen e-posta adresinizi girin.')),
      );
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Şifre sıfırlama bağlantısı e-posta adresinize gönderildi.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  Future<void> _forgotEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'eventful@eventfulapp.com',
      queryParameters: {
        'subject': 'Hesap Erişimi / E-posta Hatırlatma Talebi',
        'body': 'Merhaba Eventful Destek Ekibi,\n\nHesabıma kayıtlı e-posta adresimi hatırlayamıyorum. Yardımcı olabilir misiniz?'
      },
    );

    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
      } else {
        throw 'Mail uygulaması açılamadı';
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => PlatformHelper.isIOS 
            ? CupertinoAlertDialog(
                title: const Text('E-postamı Unuttum'),
                content: const Text('Lütfen eventful@eventfulapp.com adresine mail atın.'),
                actions: [
                  CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: const Text('Tamam')),
                ],
              )
            : AlertDialog(
                title: const Text('E-postamı Unuttum'),
                content: const Text('Lütfen eventful@eventfulapp.com adresine mail atın.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tamam')),
                ],
              ),
        );
      }
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final credential = await _auth.signInWithGoogle();
      if (credential != null && mounted) {
        // Giriş başarılı, dialogdan gelmişsek dialogu kapat, 
        // ana sayfaya yönlendirmeyi AuthWrapper otomatik yapacak veya popUntil ile temizlenecek.
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Google ile giriş yapılamadı. Lütfen tekrar deneyin.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loginWithApple() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final credential = await _auth.signInWithApple();
      if (credential != null && mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Apple ile giriş yapılamadı. Lütfen tekrar deneyin.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background Gradient decoration
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.orange.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.orange.withOpacity(0.05),
              ),
            ),
          ),
          
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo and Title
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.event_available, size: 64, color: Colors.orange),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Hoş Geldiniz',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Etkinlik dünyasına adım atın',
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),

                    // Social Login Buttons
                    Row(
                      children: [
                        // Google Login Button
                        Expanded(
                          child: SizedBox(
                            height: 56,
                            child: OutlinedButton.icon(
                              onPressed: _isLoading ? null : _loginWithGoogle,
                              icon: const Icon(Icons.g_mobiledata, size: 32, color: Colors.blue),
                              label: const Text(
                                'Google',
                                style: TextStyle(fontSize: 14, color: Colors.black87),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ),
                        if (PlatformHelper.isIOS) ...[
                          const SizedBox(width: 12),
                          // Apple Login Button
                          Expanded(
                            child: SizedBox(
                              height: 56,
                              child: OutlinedButton.icon(
                                onPressed: _isLoading ? null : _loginWithApple,
                                icon: const Icon(Icons.apple, size: 24, color: Colors.black),
                                label: const Text(
                                  'Apple',
                                  style: TextStyle(fontSize: 14, color: Colors.black87),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.grey.shade300),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 24),
                    const Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('veya', style: TextStyle(color: Colors.grey)),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 24),

                    if (_isPhoneLogin) ...[
                      // Telefon Girişi UI
                      if (!_isCodeSent)
                        _buildTextField(
                          controller: _phoneController,
                          label: 'Telefon Numarası',
                          icon: Icons.phone_android,
                          keyboardType: TextInputType.phone,
                          hint: '5xx xxx xx xx',
                        )
                      else
                        _buildTextField(
                          controller: _codeController,
                          label: 'Doğrulama Kodu',
                          icon: Icons.lock_clock_outlined,
                          keyboardType: TextInputType.number,
                          hint: '6 haneli kod',
                        ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : (_isCodeSent ? _verifyCode : _sendCode),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                              : Text(_isCodeSent ? 'Doğrula ve Giriş Yap' : 'Kod Gönder', 
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      if (_isCodeSent)
                        TextButton(
                          onPressed: () => setState(() => _isCodeSent = false),
                          child: const Text('Numarayı Değiştir', style: TextStyle(color: Colors.grey)),
                        ),
                    ] else ...[
                      // E-posta Girişi UI
                      _buildTextField(
                        controller: _emailController,
                        label: 'E-posta',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _passwordController,
                        label: 'Şifre',
                        icon: Icons.lock_outline,
                        obscureText: true,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _showForgotPassword ? _resetPassword : () {
                            setState(() {
                              _error = null;
                              _showForgotPassword = true;
                            });
                          },
                          child: Text(
                            'Şifremi Unuttum',
                            style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                              : const Text('Giriş Yap', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Toggle Button
                    Center(
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _isPhoneLogin = !_isPhoneLogin;
                            _error = null;
                            _isCodeSent = false;
                          });
                        },
                        child: Text(
                          _isPhoneLogin ? 'Mail Adresi ile Giriş Yap' : 'Telefon ile Giriş Yap',
                          style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Register redirection
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Hesabınız yok mu?', style: TextStyle(color: Colors.grey.shade700)),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => RegisterScreen()),
                            );
                          },
                          child: const Text(
                            'Kayıt Ol',
                            style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    
                    if (_showForgotEmail)
                      Center(
                        child: TextButton(
                          onPressed: _forgotEmail,
                          child: const Text('E-posta Adresimi Hatırlat', style: TextStyle(color: Colors.blue)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? hint,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.orange.shade400),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          floatingLabelStyle: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
