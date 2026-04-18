import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_auth_client.dart';
import 'package:sleep_dorm_app/core/data/repositories.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

enum _AuthView { login, register, forgotPassword, resetPassword, resetSuccess }

enum _LoginMethod { password, smsCode }

class PhoneAuthPage extends StatefulWidget {
  const PhoneAuthPage({super.key});

  @override
  State<PhoneAuthPage> createState() => _PhoneAuthPageState();
}

class _PhoneAuthPageState extends State<PhoneAuthPage> {
  static const double _designWidth = 390;
  static const double _designHeight = 844;
  static const double _shellAspectRatio = _designWidth / _designHeight;

  static const Color _pageGradientStart = Color(0xFFF7FAFF);
  static const Color _pageGradientEnd = Color(0xFFEEF4FF);
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _cardBorder = Color(0xFFDFE3E7);
  static const Color _accentBlue = Color(0xFF90DDF2);
  static const Color _accentBlueSoft = Color(0xFFE8F7FB);
  static const Color _accentBlueDeep = Color(0xFF004F5D);
  static const Color _navyBlue = Color(0xFF204F96);
  static const Color _successBlue = Color(0xFF4EA8C2);
  static const Color _surfaceMuted = Color(0xFFF2F4F6);
  static const Color _surfaceSoft = Color(0xFFECEEF1);
  static const Color _textPrimary = Color(0xFF2F3336);
  static const Color _textSecondary = Color(0xFF5B6063);
  static const Color _textMuted = Color(0xFF57606B);
  static const Color _textHint = Color(0xFFA0A0A0);
  static const Color _actionText = Color(0xFF00697A);
  static const Color _shellShadow = Color(0x14123B7A);
  static const Color _buttonShadow = Color(0x4A90DDF2);
  static const Color _focusShadow = Color(0x142457CF);

  final TextEditingController _loginPhoneController = TextEditingController();
  final TextEditingController _loginPasswordController =
      TextEditingController();
  final TextEditingController _loginCodeController = TextEditingController();

  final TextEditingController _registerPhoneController =
      TextEditingController();
  final TextEditingController _registerCodeController = TextEditingController();
  final TextEditingController _registerPasswordController =
      TextEditingController();
  final TextEditingController _registerConfirmPasswordController =
      TextEditingController();

  final TextEditingController _resetPhoneController = TextEditingController();
  final TextEditingController _resetCodeController = TextEditingController();
  final TextEditingController _resetPasswordController =
      TextEditingController();
  final TextEditingController _resetConfirmPasswordController =
      TextEditingController();

  late final Listenable _loginPasswordFormListenable;
  late final Listenable _loginCodeFormListenable;
  late final Listenable _registerFormListenable;
  late final Listenable _forgotPasswordFormListenable;
  late final Listenable _resetPasswordFormListenable;

  _AuthView _currentView = _AuthView.login;
  _LoginMethod _loginMethod = _LoginMethod.password;
  PhoneVerificationChallenge? _loginChallenge;
  PhoneVerificationChallenge? _registerChallenge;
  PhoneVerificationChallenge? _resetChallenge;
  bool _isSendingLoginCode = false;
  bool _isSendingRegisterCode = false;
  bool _isSendingResetCode = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loginPasswordFormListenable = Listenable.merge(<Listenable>[
      _loginPhoneController,
      _loginPasswordController,
    ]);
    _loginCodeFormListenable = Listenable.merge(<Listenable>[
      _loginPhoneController,
      _loginCodeController,
    ]);
    _registerFormListenable = Listenable.merge(<Listenable>[
      _registerPhoneController,
      _registerCodeController,
      _registerPasswordController,
      _registerConfirmPasswordController,
    ]);
    _forgotPasswordFormListenable = Listenable.merge(<Listenable>[
      _resetPhoneController,
      _resetCodeController,
    ]);
    _resetPasswordFormListenable = Listenable.merge(<Listenable>[
      _resetPasswordController,
      _resetConfirmPasswordController,
    ]);
  }

  @override
  void dispose() {
    _loginPhoneController.dispose();
    _loginPasswordController.dispose();
    _loginCodeController.dispose();
    _registerPhoneController.dispose();
    _registerCodeController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmPasswordController.dispose();
    _resetPhoneController.dispose();
    _resetCodeController.dispose();
    _resetPasswordController.dispose();
    _resetConfirmPasswordController.dispose();
    super.dispose();
  }

  void _switchToLogin({
    String? phoneNumber,
    _LoginMethod method = _LoginMethod.password,
  }) {
    setState(() {
      _currentView = _AuthView.login;
      _loginMethod = method;
      if (phoneNumber != null && phoneNumber.trim().isNotEmpty) {
        _loginPhoneController.text = phoneNumber;
      }
      _loginPasswordController.clear();
      _loginCodeController.clear();
      _loginChallenge = null;
    });
  }

  void _switchToRegister(String phoneNumber) {
    setState(() {
      _currentView = _AuthView.register;
      _registerPhoneController.text = phoneNumber;
      _registerCodeController.clear();
      _registerPasswordController.clear();
      _registerConfirmPasswordController.clear();
      _registerChallenge = null;
    });
  }

  void _switchToForgotPassword({String? phoneNumber}) {
    setState(() {
      _currentView = _AuthView.forgotPassword;
      if (phoneNumber != null && phoneNumber.trim().isNotEmpty) {
        _resetPhoneController.text = phoneNumber;
      }
      _resetCodeController.clear();
      _resetPasswordController.clear();
      _resetConfirmPasswordController.clear();
      _resetChallenge = null;
    });
  }

  void _switchToResetPassword() {
    setState(() {
      _currentView = _AuthView.resetPassword;
      _resetPasswordController.clear();
      _resetConfirmPasswordController.clear();
    });
  }

  void _switchToResetSuccess() {
    setState(() {
      _currentView = _AuthView.resetSuccess;
    });
  }

  bool _redirectForUnexpectedChallenge({
    required PhoneVerificationTarget target,
    required PhoneVerificationChallenge challenge,
    required String phoneNumber,
  }) {
    if (target == PhoneVerificationTarget.newUser && challenge.isExistingUser) {
      _switchToLogin(phoneNumber: phoneNumber, method: _LoginMethod.smsCode);
      _showMessage('该手机号已注册，请直接登录。');
      return true;
    }
    if (target == PhoneVerificationTarget.existingUser &&
        !challenge.isExistingUser) {
      _switchToRegister(phoneNumber);
      _showMessage('未找到该手机号，请先注册。');
      return true;
    }
    return false;
  }

  Future<void> _sendLoginCode(AppServices services) async {
    final String? error = _validatePhone(_loginPhoneController.text);
    if (error != null) {
      _showMessage(error);
      return;
    }

    setState(() => _isSendingLoginCode = true);
    try {
      final PhoneVerificationChallenge? challenge =
          await _runCaptchaProtected<PhoneVerificationChallenge>(
            services,
            action: (String? captchaToken) {
              return services.profileFacade.sendPhoneVerificationCode(
                _loginPhoneController.text.trim(),
                target: PhoneVerificationTarget.existingUser,
                captchaToken: captchaToken,
              );
            },
          );
      if (challenge == null || !mounted) {
        return;
      }
      if (_redirectForUnexpectedChallenge(
        target: PhoneVerificationTarget.existingUser,
        challenge: challenge,
        phoneNumber: _loginPhoneController.text.trim(),
      )) {
        return;
      }
      setState(() => _loginChallenge = challenge);
    } on AuthPhoneTargetMismatchException catch (error) {
      if (!mounted) {
        return;
      }
      _switchToRegister(_loginPhoneController.text.trim());
      _showMessage(error.message);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSendingLoginCode = false);
      }
    }
  }

  Future<void> _sendRegisterCode(AppServices services) async {
    final String? error = _validatePhone(_registerPhoneController.text);
    if (error != null) {
      _showMessage(error);
      return;
    }

    setState(() => _isSendingRegisterCode = true);
    try {
      final PhoneVerificationChallenge? challenge =
          await _runCaptchaProtected<PhoneVerificationChallenge>(
            services,
            action: (String? captchaToken) {
              return services.profileFacade.sendPhoneVerificationCode(
                _registerPhoneController.text.trim(),
                target: PhoneVerificationTarget.newUser,
                captchaToken: captchaToken,
              );
            },
          );
      if (challenge == null || !mounted) {
        return;
      }
      if (_redirectForUnexpectedChallenge(
        target: PhoneVerificationTarget.newUser,
        challenge: challenge,
        phoneNumber: _registerPhoneController.text.trim(),
      )) {
        return;
      }
      setState(() => _registerChallenge = challenge);
    } on AuthPhoneTargetMismatchException catch (error) {
      if (!mounted) {
        return;
      }
      _switchToLogin(
        phoneNumber: _registerPhoneController.text.trim(),
        method: _LoginMethod.smsCode,
      );
      _showMessage(error.message);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSendingRegisterCode = false);
      }
    }
  }

  Future<void> _sendResetCode(AppServices services) async {
    final String? error = _validatePhone(_resetPhoneController.text);
    if (error != null) {
      _showMessage(error);
      return;
    }

    setState(() => _isSendingResetCode = true);
    try {
      final PhoneVerificationChallenge? challenge =
          await _runCaptchaProtected<PhoneVerificationChallenge>(
            services,
            action: (String? captchaToken) {
              return services.profileFacade.sendPhoneVerificationCode(
                _resetPhoneController.text.trim(),
                target: PhoneVerificationTarget.existingUser,
                captchaToken: captchaToken,
              );
            },
          );
      if (challenge == null || !mounted) {
        return;
      }
      if (_redirectForUnexpectedChallenge(
        target: PhoneVerificationTarget.existingUser,
        challenge: challenge,
        phoneNumber: _resetPhoneController.text.trim(),
      )) {
        return;
      }
      setState(() => _resetChallenge = challenge);
    } on AuthPhoneTargetMismatchException catch (error) {
      if (!mounted) {
        return;
      }
      _switchToRegister(_resetPhoneController.text.trim());
      _showMessage(error.message);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSendingResetCode = false);
      }
    }
  }

  Future<void> _submitLoginWithPassword(AppServices services) async {
    await _flushTextEditingState();
    final String? phoneError = _validatePhone(_loginPhoneController.text);
    if (phoneError != null) {
      _showMessage(phoneError);
      return;
    }
    final String? passwordError = _validatePassword(
      _loginPasswordController.text,
    );
    if (passwordError != null) {
      _showMessage(passwordError);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final bool completed =
          await _runCaptchaProtected<bool>(
            services,
            action: (String? captchaToken) async {
              await services.profileFacade.signInWithPassword(
                phoneNumber: _loginPhoneController.text.trim(),
                password: _loginPasswordController.text,
                captchaToken: captchaToken,
              );
              return true;
            },
          ) ??
          false;
      if (!completed || !mounted) {
        return;
      }
      context.go(AppRoutes.home);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _submitLoginWithCode(AppServices services) async {
    final PhoneVerificationChallenge? challenge = _loginChallenge;
    if (challenge == null) {
      _showMessage('请先发送验证码。');
      return;
    }

    await _flushTextEditingState();
    final String? phoneError = _validatePhone(_loginPhoneController.text);
    if (phoneError != null) {
      _showMessage(phoneError);
      return;
    }
    final String? codeError = _validateCode(_loginCodeController.text);
    if (codeError != null) {
      _showMessage(codeError);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final bool completed =
          await _runCaptchaProtected<bool>(
            services,
            action: (String? captchaToken) async {
              await services.profileFacade.signInWithPhoneCode(
                phoneNumber: _loginPhoneController.text.trim(),
                verificationId: challenge.verificationId,
                code: _loginCodeController.text.trim(),
                captchaToken: captchaToken,
              );
              return true;
            },
          ) ??
          false;
      if (!completed || !mounted) {
        return;
      }
      context.go(AppRoutes.home);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _submitRegister(AppServices services) async {
    await _flushTextEditingState();
    final PhoneVerificationChallenge? challenge = _registerChallenge;
    if (challenge == null) {
      _showMessage('请先发送验证码。');
      return;
    }

    final String? phoneError = _validatePhone(_registerPhoneController.text);
    if (phoneError != null) {
      _showMessage(phoneError);
      return;
    }
    final String? codeError = _validateCode(_registerCodeController.text);
    if (codeError != null) {
      _showMessage(codeError);
      return;
    }
    final String? passwordError = _validatePassword(
      _registerPasswordController.text,
    );
    if (passwordError != null) {
      _showMessage(passwordError);
      return;
    }
    if (_registerPasswordController.text !=
        _registerConfirmPasswordController.text) {
      _showMessage('两次输入的密码不一致。');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await services.profileFacade.registerWithPhone(
        phoneNumber: _registerPhoneController.text.trim(),
        verificationId: challenge.verificationId,
        code: _registerCodeController.text.trim(),
        password: _registerPasswordController.text,
      );
      if (!mounted) {
        return;
      }
      context.go(AppRoutes.home);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _verifyResetCode() async {
    await _flushTextEditingState();
    final PhoneVerificationChallenge? challenge = _resetChallenge;
    if (challenge == null) {
      _showMessage('请先发送验证码。');
      return;
    }

    final String? phoneError = _validatePhone(_resetPhoneController.text);
    if (phoneError != null) {
      _showMessage(phoneError);
      return;
    }
    final String? codeError = _validateCode(_resetCodeController.text);
    if (codeError != null) {
      _showMessage(codeError);
      return;
    }
    if (!challenge.isExistingUser) {
      _showMessage('未找到该手机号，请先注册。');
      return;
    }
    _switchToResetPassword();
  }

  Future<void> _submitResetPassword(AppServices services) async {
    await _flushTextEditingState();
    final PhoneVerificationChallenge? challenge = _resetChallenge;
    if (challenge == null) {
      _showMessage('请先发送验证码。');
      return;
    }

    final String? phoneError = _validatePhone(_resetPhoneController.text);
    if (phoneError != null) {
      _showMessage(phoneError);
      return;
    }
    final String? codeError = _validateCode(_resetCodeController.text);
    if (codeError != null) {
      _showMessage(codeError);
      return;
    }
    final String? passwordError = _validatePassword(
      _resetPasswordController.text,
    );
    if (passwordError != null) {
      _showMessage(passwordError);
      return;
    }
    if (_resetPasswordController.text != _resetConfirmPasswordController.text) {
      _showMessage('两次输入的新密码不一致。');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await services.profileFacade.resetPasswordWithPhone(
        phoneNumber: _resetPhoneController.text.trim(),
        verificationId: challenge.verificationId,
        code: _resetCodeController.text.trim(),
        newPassword: _resetPasswordController.text,
      );
      if (!mounted) {
        return;
      }
      _switchToResetSuccess();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _returnToLoginFromSuccess(AppServices services) async {
    try {
      await services.authRepository.signOut();
      if (!mounted) {
        return;
      }
      _switchToLogin(phoneNumber: _resetPhoneController.text.trim());
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.toString());
    }
  }

  Future<void> _resendResetFromSuccess(AppServices services) async {
    setState(() {
      _currentView = _AuthView.forgotPassword;
      _resetCodeController.clear();
      _resetPasswordController.clear();
      _resetConfirmPasswordController.clear();
      _resetChallenge = null;
    });
    await _sendResetCode(services);
  }

  String? _validatePhone(String value) {
    final String normalized = normalizeCloudBasePhoneNumber(value);
    final String digits = normalized.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 8) {
      return '请输入正确的手机号。';
    }
    return null;
  }

  String? _validatePassword(String value) {
    if (value.trim().length < 6) {
      return '密码至少需要 6 位。';
    }
    return null;
  }

  String? _validateCode(String value) {
    if (value.trim().length < 4) {
      return '请输入正确的验证码。';
    }
    return null;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _flushTextEditingState() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(Duration.zero);
  }

  Future<T?> _runCaptchaProtected<T>(
    AppServices services, {
    required Future<T> Function(String? captchaToken) action,
  }) async {
    try {
      return await action(null);
    } on AuthCaptchaRequiredException {
      final String? captchaToken = await _resolveCaptchaToken(services);
      if (captchaToken == null || captchaToken.isEmpty) {
        return null;
      }
      return action(captchaToken);
    }
  }

  Future<String?> _resolveCaptchaToken(AppServices services) async {
    final AuthCaptchaChallenge initialChallenge = await services.profileFacade
        .createCaptchaChallenge();
    if (!mounted) {
      return null;
    }
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return _CaptchaVerifyDialog(
          initialChallenge: initialChallenge,
          onRefresh: services.profileFacade.createCaptchaChallenge,
          onVerify: ({required String token, required String code}) {
            return services.profileFacade.verifyCaptchaChallenge(
              token: token,
              code: code,
            );
          },
        );
      },
    );
  }

  bool get _canSubmitLoginWithPassword =>
      _validatePhone(_loginPhoneController.text) == null &&
      _validatePassword(_loginPasswordController.text) == null;

  bool get _canSubmitLoginWithCode =>
      _loginChallenge != null &&
      _validatePhone(_loginPhoneController.text) == null &&
      _validateCode(_loginCodeController.text) == null;

  bool get _canSubmitRegister =>
      _registerChallenge != null &&
      _validatePhone(_registerPhoneController.text) == null &&
      _validateCode(_registerCodeController.text) == null &&
      _validatePassword(_registerPasswordController.text) == null &&
      _registerPasswordController.text ==
          _registerConfirmPasswordController.text &&
      _registerConfirmPasswordController.text.isNotEmpty;

  bool get _canVerifyResetCode =>
      _resetChallenge != null &&
      _validatePhone(_resetPhoneController.text) == null &&
      _validateCode(_resetCodeController.text) == null;

  bool get _canSubmitResetPassword =>
      _resetChallenge != null &&
      _validatePassword(_resetPasswordController.text) == null &&
      _resetPasswordController.text == _resetConfirmPasswordController.text &&
      _resetConfirmPasswordController.text.isNotEmpty;

  TextStyle _textStyle(
    BuildContext context, {
    required double size,
    required FontWeight weight,
    required Color color,
    double? height,
  }) {
    return Theme.of(context).textTheme.bodyMedium!.copyWith(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
    );
  }

  Widget _buildPhoneShell(
    BuildContext context,
    AppServices services, {
    required double width,
    required double height,
  }) {
    final double unit = height / _designHeight;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(28 * unit),
        border: Border.all(color: _cardBorder, width: math.max(1, unit)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _shellShadow,
            blurRadius: 48 * unit,
            offset: Offset(0, 20 * unit),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(32 * unit),
        child: switch (_currentView) {
          _AuthView.login => _buildLoginPage(context, services, unit),
          _AuthView.register => _buildRegisterPage(context, services, unit),
          _AuthView.forgotPassword => _buildForgotPasswordPage(
            context,
            services,
            unit,
          ),
          _AuthView.resetPassword => _buildResetPasswordPage(
            context,
            services,
            unit,
          ),
          _AuthView.resetSuccess => _buildResetSuccessPage(
            context,
            services,
            unit,
          ),
        },
      ),
    );
  }

  Widget _buildLoginPage(
    BuildContext context,
    AppServices services,
    double unit,
  ) {
    final bool usePassword = _loginMethod == _LoginMethod.password;
    final Listenable listenable = usePassword
        ? _loginPasswordFormListenable
        : _loginCodeFormListenable;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _PencilTopSquare(
                icon: Icons.bedtime_rounded,
                iconSize: 26 * unit,
                size: 52 * unit,
                radius: 16 * unit,
                backgroundColor: _accentBlue,
                iconColor: Colors.white,
              ),
              SizedBox(height: 20 * unit),
              Text(
                '登录舍眠',
                style: _textStyle(
                  context,
                  size: 32 * unit,
                  weight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              SizedBox(height: 10 * unit),
              Text(
                '使用手机号继续登录。支持密码登录，也支持短信验证码登录。',
                style: _textStyle(
                  context,
                  size: 15 * unit,
                  weight: FontWeight.w500,
                  color: _textMuted,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 20 * unit),
              _buildLoginMethodSwitch(context, unit),
              SizedBox(height: 20 * unit),
              _PencilInputField(
                fieldKey: const ValueKey<String>('auth-login-phone'),
                label: '手机号',
                hintText: '138 0013 8000',
                controller: _loginPhoneController,
                icon: Icons.phone_android_rounded,
                keyboardType: TextInputType.phone,
                textInputAction: usePassword
                    ? TextInputAction.next
                    : TextInputAction.done,
                scaleUnit: unit,
                forceHighlightedBorder: true,
              ),
              SizedBox(height: 12 * unit),
              if (usePassword) ...<Widget>[
                _PencilInputField(
                  fieldKey: const ValueKey<String>('auth-login-password'),
                  label: '密码',
                  hintText: '••••••••••••',
                  controller: _loginPasswordController,
                  icon: Icons.lock_outline_rounded,
                  textInputAction: TextInputAction.done,
                  obscureText: true,
                  scaleUnit: unit,
                ),
              ] else ...<Widget>[
                _buildCodeFieldRow(
                  context,
                  label: '短信验证码',
                  hintText: '输入收到的验证码',
                  controller: _loginCodeController,
                  fieldKey: const ValueKey<String>('auth-login-code'),
                  actionKey: const ValueKey<String>('auth-login-code-send'),
                  isSending: _isSendingLoginCode,
                  onPressed: _isSendingLoginCode
                      ? null
                      : () => _sendLoginCode(services),
                  unit: unit,
                ),
              ],
              SizedBox(height: 12 * unit),
              Align(
                alignment: Alignment.centerRight,
                child: _PencilTextAction(
                  actionKey: const ValueKey<String>('auth-forgot-password'),
                  label: '忘记密码？',
                  unit: unit,
                  onTap: () => _switchToForgotPassword(
                    phoneNumber: _loginPhoneController.text.trim(),
                  ),
                ),
              ),
              SizedBox(height: 12 * unit),
              ListenableBuilder(
                listenable: listenable,
                builder: (BuildContext context, Widget? child) {
                  return _PencilFilledButton(
                    buttonKey: const ValueKey<String>('auth-login-submit'),
                    label: '登录',
                    unit: unit,
                    onPressed: _isSubmitting
                        ? null
                        : usePassword
                        ? (_canSubmitLoginWithPassword
                              ? () => _submitLoginWithPassword(services)
                              : null)
                        : (_canSubmitLoginWithCode
                              ? () => _submitLoginWithCode(services)
                              : null),
                  );
                },
              ),
            ],
          ),
        ),
        SizedBox(height: 24 * unit),
        _PencilFooterCard(
          title: '还没有账号？',
          actionLabel: '立即注册',
          unit: unit,
          onTap: () => _switchToRegister(_loginPhoneController.text.trim()),
          actionKey: const ValueKey<String>('auth-mode-register'),
        ),
      ],
    );
  }

  Widget _buildRegisterPage(
    BuildContext context,
    AppServices services,
    double unit,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _PencilTopSquare(
                icon: Icons.person_add_alt_1_rounded,
                iconSize: 26 * unit,
                size: 52 * unit,
                radius: 16 * unit,
                backgroundColor: _accentBlue,
                iconColor: Colors.white,
              ),
              SizedBox(height: 20 * unit),
              _PencilBadge(label: '短信验证注册', unit: unit),
              SizedBox(height: 10 * unit),
              Text(
                '免费注册',
                style: _textStyle(
                  context,
                  size: 32 * unit,
                  weight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              SizedBox(height: 20 * unit),
              _PencilInputField(
                fieldKey: const ValueKey<String>('auth-register-phone'),
                label: '手机号',
                hintText: '请输入手机号',
                controller: _registerPhoneController,
                icon: Icons.phone_android_rounded,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                scaleUnit: unit,
              ),
              SizedBox(height: 12 * unit),
              _buildCodeFieldRow(
                context,
                label: '短信验证码',
                hintText: '请输入验证码',
                controller: _registerCodeController,
                fieldKey: const ValueKey<String>('auth-register-code'),
                actionKey: const ValueKey<String>('auth-register-send'),
                isSending: _isSendingRegisterCode,
                onPressed: _isSendingRegisterCode
                    ? null
                    : () => _sendRegisterCode(services),
                unit: unit,
              ),
              SizedBox(height: 12 * unit),
              _PencilInputField(
                fieldKey: const ValueKey<String>('auth-register-password'),
                label: '密码',
                hintText: '请设置登录密码',
                controller: _registerPasswordController,
                icon: Icons.lock_outline_rounded,
                textInputAction: TextInputAction.next,
                obscureText: true,
                scaleUnit: unit,
              ),
              SizedBox(height: 12 * unit),
              _PencilInputField(
                fieldKey: const ValueKey<String>(
                  'auth-register-password-confirm',
                ),
                label: '确认密码',
                hintText: '请再次输入密码',
                controller: _registerConfirmPasswordController,
                icon: Icons.lock_outline_rounded,
                textInputAction: TextInputAction.done,
                obscureText: true,
                scaleUnit: unit,
              ),
              SizedBox(height: 12 * unit),
              _PencilInfoStrip(
                icon: Icons.info_outline_rounded,
                message: '验证码验证通过后即可完成注册，密码至少 6 位。',
                unit: unit,
              ),
              SizedBox(height: 12 * unit),
              ListenableBuilder(
                listenable: _registerFormListenable,
                builder: (BuildContext context, Widget? child) {
                  return _PencilFilledButton(
                    buttonKey: const ValueKey<String>('auth-register-submit'),
                    label: '注册并进入',
                    unit: unit,
                    onPressed: _isSubmitting
                        ? null
                        : (_canSubmitRegister
                              ? () => _submitRegister(services)
                              : null),
                  );
                },
              ),
            ],
          ),
        ),
        SizedBox(height: 24 * unit),
        _PencilFooterCard(
          title: '已经有账号？',
          actionLabel: '返回登录',
          unit: unit,
          onTap: () =>
              _switchToLogin(phoneNumber: _registerPhoneController.text.trim()),
          actionKey: const ValueKey<String>('auth-mode-login'),
        ),
      ],
    );
  }

  Widget _buildForgotPasswordPage(
    BuildContext context,
    AppServices services,
    double unit,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _PencilTopSquare(
                icon: Icons.chevron_left_rounded,
                iconSize: 24 * unit,
                size: 48 * unit,
                radius: 14 * unit,
                backgroundColor: _accentBlue,
                iconColor: Colors.white,
                onTap: () => _switchToLogin(
                  phoneNumber: _resetPhoneController.text.trim(),
                ),
              ),
              SizedBox(height: 24 * unit),
              _PencilBadge(label: '短信找回密码', unit: unit),
              SizedBox(height: 10 * unit),
              Text(
                '找回密码',
                style: _textStyle(
                  context,
                  size: 32 * unit,
                  weight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              SizedBox(height: 20 * unit),
              _PencilInputField(
                fieldKey: const ValueKey<String>('auth-reset-phone'),
                label: '手机号',
                hintText: '请输入已绑定手机号',
                controller: _resetPhoneController,
                icon: Icons.phone_android_rounded,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                scaleUnit: unit,
              ),
              SizedBox(height: 12 * unit),
              _buildCodeFieldRow(
                context,
                label: '短信验证码',
                hintText: '输入收到的验证码',
                controller: _resetCodeController,
                fieldKey: const ValueKey<String>('auth-reset-code'),
                actionKey: const ValueKey<String>('auth-reset-send'),
                isSending: _isSendingResetCode,
                onPressed: _isSendingResetCode
                    ? null
                    : () => _sendResetCode(services),
                unit: unit,
              ),
              SizedBox(height: 12 * unit),
              ListenableBuilder(
                listenable: _forgotPasswordFormListenable,
                builder: (BuildContext context, Widget? child) {
                  return _PencilFilledButton(
                    buttonKey: const ValueKey<String>('auth-reset-verify'),
                    label: '验证并继续',
                    unit: unit,
                    onPressed: _isSubmitting
                        ? null
                        : (_canVerifyResetCode ? _verifyResetCode : null),
                  );
                },
              ),
            ],
          ),
        ),
        SizedBox(height: 24 * unit),
        _PencilSupportCard(title: '无法接收验证码？', subtitle: '联系客服协助处理', unit: unit),
      ],
    );
  }

  Widget _buildResetPasswordPage(
    BuildContext context,
    AppServices services,
    double unit,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _PencilTopSquare(
          icon: Icons.chevron_left_rounded,
          iconSize: 24 * unit,
          size: 48 * unit,
          radius: 14 * unit,
          backgroundColor: _accentBlue,
          iconColor: Colors.white,
          onTap: () {
            setState(() => _currentView = _AuthView.forgotPassword);
          },
        ),
        SizedBox(height: 24 * unit),
        _PencilBadge(label: '设置新密码', unit: unit),
        SizedBox(height: 10 * unit),
        Text(
          '重置密码',
          style: _textStyle(
            context,
            size: 32 * unit,
            weight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
        SizedBox(height: 10 * unit),
        Text(
          '短信验证已通过，现在请设置一个新的登录密码。',
          style: _textStyle(
            context,
            size: 15 * unit,
            weight: FontWeight.w500,
            color: _textMuted,
            height: 1.5,
          ),
        ),
        SizedBox(height: 20 * unit),
        _PencilInputField(
          fieldKey: const ValueKey<String>('auth-reset-password'),
          label: '新密码',
          hintText: '请输入新的登录密码',
          controller: _resetPasswordController,
          icon: Icons.lock_outline_rounded,
          textInputAction: TextInputAction.next,
          obscureText: true,
          scaleUnit: unit,
        ),
        SizedBox(height: 12 * unit),
        _PencilInputField(
          fieldKey: const ValueKey<String>('auth-reset-password-confirm'),
          label: '确认新密码',
          hintText: '再次输入新密码',
          controller: _resetConfirmPasswordController,
          icon: Icons.lock_outline_rounded,
          textInputAction: TextInputAction.done,
          obscureText: true,
          scaleUnit: unit,
        ),
        SizedBox(height: 12 * unit),
        _PencilTipsCard(unit: unit),
        SizedBox(height: 12 * unit),
        ListenableBuilder(
          listenable: _resetPasswordFormListenable,
          builder: (BuildContext context, Widget? child) {
            return _PencilFilledButton(
              buttonKey: const ValueKey<String>('auth-reset-submit'),
              label: '确认重置密码',
              unit: unit,
              onPressed: _isSubmitting
                  ? null
                  : (_canSubmitResetPassword
                        ? () => _submitResetPassword(services)
                        : null),
            );
          },
        ),
      ],
    );
  }

  Widget _buildResetSuccessPage(
    BuildContext context,
    AppServices services,
    double unit,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _PencilBadge(label: '密码更新完成', unit: unit),
        SizedBox(height: 24 * unit),
        Text(
          '密码已重置',
          style: _textStyle(
            context,
            size: 32 * unit,
            weight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
        SizedBox(height: 12 * unit),
        Text(
          '你的账号已经完成密码更新，现在可以使用新密码继续登录并同步宿舍睡眠状态。',
          style: _textStyle(
            context,
            size: 15 * unit,
            weight: FontWeight.w500,
            color: _textMuted,
            height: 1.5,
          ),
        ),
        SizedBox(height: 24 * unit),
        _PencilSuccessIllustration(unit: unit),
        SizedBox(height: 24 * unit),
        _PencilFilledButton(
          buttonKey: const ValueKey<String>('auth-reset-success-login'),
          label: '返回登录',
          unit: unit,
          onPressed: () => _returnToLoginFromSuccess(services),
        ),
        SizedBox(height: 12 * unit),
        _PencilSoftSurfaceButton(
          buttonKey: const ValueKey<String>('auth-reset-success-resend'),
          label: '重新发送重置短信',
          unit: unit,
          onPressed: () => _resendResetFromSuccess(services),
        ),
      ],
    );
  }

  Widget _buildLoginMethodSwitch(BuildContext context, double unit) {
    final bool usePassword = _loginMethod == _LoginMethod.password;
    return Row(
      children: <Widget>[
        Expanded(
          child: _PencilSegmentButton(
            label: '密码登录',
            unit: unit,
            selected: usePassword,
            onTap: () {
              setState(() {
                _loginMethod = _LoginMethod.password;
              });
            },
          ),
        ),
        SizedBox(width: 10 * unit),
        Expanded(
          child: _PencilSegmentButton(
            segmentKey: const ValueKey<String>('auth-login-method-code'),
            label: '验证码登录',
            unit: unit,
            selected: !usePassword,
            onTap: () {
              setState(() {
                _loginMethod = _LoginMethod.smsCode;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCodeFieldRow(
    BuildContext context, {
    required String label,
    required String hintText,
    required TextEditingController controller,
    required Key fieldKey,
    required Key actionKey,
    required bool isSending,
    required VoidCallback? onPressed,
    required double unit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: _textStyle(
            context,
            size: 13 * unit,
            weight: FontWeight.w600,
            color: _textSecondary,
          ),
        ),
        SizedBox(height: 6 * unit),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              flex: 10,
              child: _PencilBareInput(
                fieldKey: fieldKey,
                hintText: hintText,
                controller: controller,
                icon: Icons.sms_outlined,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                scaleUnit: unit,
              ),
            ),
            SizedBox(width: 10 * unit),
            Expanded(
              flex: 5,
              child: _PencilSoftButton(
                buttonKey: actionKey,
                label: isSending ? '发送中...' : '发送验证码',
                unit: unit,
                onPressed: onPressed,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = AppScope.of(context);
    final Size screenSize = MediaQuery.sizeOf(context);
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[_pageGradientStart, _pageGradientEnd],
            ),
          ),
          child: SafeArea(
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding: EdgeInsets.fromLTRB(
                screenSize.width * 0.05,
                screenSize.height * 0.025,
                screenSize.width * 0.05,
                keyboardInset + (screenSize.height * 0.025),
              ),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double shellHeight = math.min(
                    constraints.maxHeight,
                    constraints.maxWidth / _shellAspectRatio,
                  );
                  final double shellWidth = shellHeight * _shellAspectRatio;
                  return Center(
                    child: _buildPhoneShell(
                      context,
                      services,
                      width: shellWidth,
                      height: shellHeight,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PencilTopSquare extends StatelessWidget {
  const _PencilTopSquare({
    required this.icon,
    required this.iconSize,
    required this.size,
    required this.radius,
    required this.backgroundColor,
    required this.iconColor,
    this.onTap,
  });

  final IconData icon;
  final double iconSize;
  final double size;
  final double radius;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget iconWidget = Icon(icon, size: iconSize, color: iconColor);
    if (onTap == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(radius),
        ),
        alignment: Alignment.center,
        child: iconWidget,
      );
    }

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(child: iconWidget),
        ),
      ),
    );
  }
}

class _PencilBadge extends StatelessWidget {
  const _PencilBadge({required this.label, required this.unit});

  final String label;
  final double unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14 * unit),
      height: 34 * unit,
      decoration: BoxDecoration(
        color: _PhoneAuthPageState._accentBlueSoft,
        borderRadius: BorderRadius.circular(17 * unit),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
          fontSize: 13 * unit,
          fontWeight: FontWeight.w700,
          color: _PhoneAuthPageState._actionText,
        ),
      ),
    );
  }
}

class _PencilInputField extends StatelessWidget {
  const _PencilInputField({
    required this.fieldKey,
    required this.label,
    required this.hintText,
    required this.controller,
    required this.icon,
    required this.scaleUnit,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.forceHighlightedBorder = false,
  });

  final Key fieldKey;
  final String label;
  final String hintText;
  final TextEditingController controller;
  final IconData icon;
  final double scaleUnit;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool forceHighlightedBorder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            fontSize: 13 * scaleUnit,
            fontWeight: FontWeight.w600,
            color: _PhoneAuthPageState._textSecondary,
          ),
        ),
        SizedBox(height: 6 * scaleUnit),
        _PencilBareInput(
          fieldKey: fieldKey,
          hintText: hintText,
          controller: controller,
          icon: icon,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          obscureText: obscureText,
          scaleUnit: scaleUnit,
          forceHighlightedBorder: forceHighlightedBorder,
        ),
      ],
    );
  }
}

class _PencilBareInput extends StatelessWidget {
  const _PencilBareInput({
    required this.fieldKey,
    required this.hintText,
    required this.controller,
    required this.icon,
    required this.scaleUnit,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.forceHighlightedBorder = false,
  });

  final Key fieldKey;
  final String hintText;
  final TextEditingController controller;
  final IconData icon;
  final double scaleUnit;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool forceHighlightedBorder;

  @override
  Widget build(BuildContext context) {
    final Color borderColor = forceHighlightedBorder
        ? _PhoneAuthPageState._successBlue
        : _PhoneAuthPageState._cardBorder;
    final double borderWidth = forceHighlightedBorder
        ? 2 * scaleUnit
        : scaleUnit;

    return Container(
      height: 56 * scaleUnit,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18 * scaleUnit),
        border: Border.all(color: borderColor, width: math.max(1, borderWidth)),
        boxShadow: forceHighlightedBorder
            ? <BoxShadow>[
                BoxShadow(
                  color: _PhoneAuthPageState._focusShadow,
                  blurRadius: 24 * scaleUnit,
                  offset: Offset(0, 10 * scaleUnit),
                ),
              ]
            : const <BoxShadow>[],
      ),
      child: TextField(
        key: fieldKey,
        controller: controller,
        obscureText: obscureText,
        obscuringCharacter: '•',
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        enableSuggestions: !obscureText,
        autocorrect: false,
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
          fontSize: 14 * scaleUnit,
          fontWeight: FontWeight.w500,
          color: _PhoneAuthPageState._textPrimary,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
            fontSize: 14 * scaleUnit,
            fontWeight: obscureText ? FontWeight.w600 : FontWeight.w500,
            color: forceHighlightedBorder
                ? _PhoneAuthPageState._textPrimary
                : obscureText
                ? _PhoneAuthPageState._textPrimary
                : _PhoneAuthPageState._textHint,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 18 * scaleUnit),
          prefixIcon: Icon(
            icon,
            size: 20 * scaleUnit,
            color: _PhoneAuthPageState._textSecondary,
          ),
          prefixIconConstraints: BoxConstraints(
            minWidth: 44 * scaleUnit,
            minHeight: 56 * scaleUnit,
          ),
        ),
      ),
    );
  }
}

class _PencilFilledButton extends StatelessWidget {
  const _PencilFilledButton({
    required this.buttonKey,
    required this.label,
    required this.unit,
    required this.onPressed,
  });

  final Key buttonKey;
  final String label;
  final double unit;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    return SizedBox(
      key: buttonKey,
      width: double.infinity,
      height: 58 * unit,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18 * unit),
          boxShadow: enabled
              ? <BoxShadow>[
                  BoxShadow(
                    color: _PhoneAuthPageState._buttonShadow,
                    blurRadius: 30 * unit,
                    offset: Offset(0, 16 * unit),
                  ),
                ]
              : const <BoxShadow>[],
        ),
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            padding: EdgeInsets.zero,
            elevation: 0,
            backgroundColor: enabled
                ? _PhoneAuthPageState._accentBlue
                : _PhoneAuthPageState._accentBlue.withValues(alpha: 0.55),
            foregroundColor: enabled
                ? _PhoneAuthPageState._accentBlueDeep
                : _PhoneAuthPageState._accentBlueDeep.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18 * unit),
            ),
            textStyle: Theme.of(context).textTheme.bodyLarge!.copyWith(
              fontSize: 16 * unit,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

class _PencilSoftButton extends StatelessWidget {
  const _PencilSoftButton({
    required this.buttonKey,
    required this.label,
    required this.unit,
    required this.onPressed,
  });

  final Key buttonKey;
  final String label;
  final double unit;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    return SizedBox(
      key: buttonKey,
      height: 56 * unit,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: 10 * unit),
          elevation: 0,
          backgroundColor: enabled
              ? _PhoneAuthPageState._accentBlueSoft
              : _PhoneAuthPageState._accentBlueSoft.withValues(alpha: 0.45),
          foregroundColor: enabled
              ? _PhoneAuthPageState._actionText
              : _PhoneAuthPageState._actionText.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18 * unit),
          ),
          textStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
            fontSize: 13 * unit,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, maxLines: 1),
        ),
      ),
    );
  }
}

class _PencilSoftSurfaceButton extends StatelessWidget {
  const _PencilSoftSurfaceButton({
    required this.buttonKey,
    required this.label,
    required this.unit,
    required this.onPressed,
  });

  final Key buttonKey;
  final String label;
  final double unit;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: buttonKey,
      width: double.infinity,
      height: 54 * unit,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          elevation: 0,
          backgroundColor: _PhoneAuthPageState._surfaceSoft,
          foregroundColor: _PhoneAuthPageState._textSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18 * unit),
          ),
          textStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
            fontSize: 14 * unit,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

class _PencilSegmentButton extends StatelessWidget {
  const _PencilSegmentButton({
    this.segmentKey,
    required this.label,
    required this.unit,
    required this.selected,
    required this.onTap,
  });

  final Key? segmentKey;
  final String label;
  final double unit;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: segmentKey,
      color: selected
          ? _PhoneAuthPageState._accentBlue
          : _PhoneAuthPageState._accentBlueSoft,
      borderRadius: BorderRadius.circular(18 * unit),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18 * unit),
        child: SizedBox(
          height: 48 * unit,
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                fontSize: 14 * unit,
                fontWeight: FontWeight.w700,
                color: _PhoneAuthPageState._accentBlueDeep,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PencilTextAction extends StatelessWidget {
  const _PencilTextAction({
    required this.actionKey,
    required this.label,
    required this.unit,
    required this.onTap,
  });

  final Key actionKey;
  final String label;
  final double unit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: actionKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(8 * unit),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 4 * unit),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall!.copyWith(
            fontSize: 12 * unit,
            fontWeight: FontWeight.w700,
            color: _PhoneAuthPageState._actionText,
          ),
        ),
      ),
    );
  }
}

class _PencilInfoStrip extends StatelessWidget {
  const _PencilInfoStrip({
    required this.icon,
    required this.message,
    required this.unit,
  });

  final IconData icon;
  final String message;
  final double unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38 * unit,
      padding: EdgeInsets.symmetric(horizontal: 14 * unit),
      decoration: BoxDecoration(
        color: _PhoneAuthPageState._surfaceMuted,
        borderRadius: BorderRadius.circular(14 * unit),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18 * unit, color: _PhoneAuthPageState._navyBlue),
          SizedBox(width: 8 * unit),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                fontSize: 12 * unit,
                fontWeight: FontWeight.w500,
                color: _PhoneAuthPageState._textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PencilTipsCard extends StatelessWidget {
  const _PencilTipsCard({required this.unit});

  final double unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18 * unit),
      decoration: BoxDecoration(
        color: _PhoneAuthPageState._surfaceMuted,
        borderRadius: BorderRadius.circular(22 * unit),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '密码建议',
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontSize: 14 * unit,
              fontWeight: FontWeight.w700,
              color: _PhoneAuthPageState._textPrimary,
            ),
          ),
          SizedBox(height: 8 * unit),
          Text(
            '至少 6 位，建议混合数字与字母。',
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontSize: 13 * unit,
              fontWeight: FontWeight.w500,
              color: _PhoneAuthPageState._textMuted,
            ),
          ),
          SizedBox(height: 8 * unit),
          Text(
            '避免与旧密码过于接近。',
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontSize: 13 * unit,
              fontWeight: FontWeight.w500,
              color: _PhoneAuthPageState._textMuted,
            ),
          ),
          SizedBox(height: 8 * unit),
          Text(
            '重置后将使用新密码直接登录。',
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontSize: 13 * unit,
              fontWeight: FontWeight.w500,
              color: _PhoneAuthPageState._textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _PencilFooterCard extends StatelessWidget {
  const _PencilFooterCard({
    required this.title,
    required this.actionLabel,
    required this.unit,
    required this.onTap,
    required this.actionKey,
  });

  final String title;
  final String actionLabel;
  final double unit;
  final VoidCallback onTap;
  final Key actionKey;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _PhoneAuthPageState._surfaceMuted,
      borderRadius: BorderRadius.circular(24 * unit),
      child: InkWell(
        key: actionKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(24 * unit),
        child: SizedBox(
          height: 74 * unit,
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  fontSize: 13 * unit,
                  fontWeight: FontWeight.w500,
                  color: _PhoneAuthPageState._textMuted,
                ),
              ),
              SizedBox(height: 6 * unit),
              Semantics(
                button: true,
                child: Text(
                  actionLabel,
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                    fontSize: 15 * unit,
                    fontWeight: FontWeight.w700,
                    color: _PhoneAuthPageState._actionText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PencilSupportCard extends StatelessWidget {
  const _PencilSupportCard({
    required this.title,
    required this.subtitle,
    required this.unit,
  });

  final String title;
  final String subtitle;
  final double unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92 * unit,
      width: double.infinity,
      decoration: BoxDecoration(
        color: _PhoneAuthPageState._surfaceMuted,
        borderRadius: BorderRadius.circular(24 * unit),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontSize: 13 * unit,
              fontWeight: FontWeight.w500,
              color: _PhoneAuthPageState._textMuted,
            ),
          ),
          SizedBox(height: 8 * unit),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontSize: 14 * unit,
              fontWeight: FontWeight.w700,
              color: _PhoneAuthPageState._textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PencilSuccessIllustration extends StatelessWidget {
  const _PencilSuccessIllustration({required this.unit});

  final double unit;

  @override
  Widget build(BuildContext context) {
    final double leftRotation = -12 * math.pi / 180;
    final double rightRotation = 12 * math.pi / 180;
    final double topBarRotation = 32 * math.pi / 180;

    return Container(
      height: 220 * unit,
      width: double.infinity,
      decoration: BoxDecoration(
        color: _PhoneAuthPageState._surfaceSoft,
        borderRadius: BorderRadius.circular(28 * unit),
        border: Border.all(
          color: _PhoneAuthPageState._cardBorder,
          width: math.max(1, unit),
        ),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double width = constraints.maxWidth;
          final double height = constraints.maxHeight;
          return Stack(
            children: <Widget>[
              Positioned(
                left: width * 0.16,
                top: height * 0.15,
                child: Transform.rotate(
                  angle: leftRotation,
                  child: Container(
                    width: width * 0.5,
                    height: height * 0.49,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24 * unit),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: width * 0.27,
                top: height * 0.12,
                child: Transform.rotate(
                  angle: rightRotation,
                  child: Container(
                    width: width * 0.48,
                    height: height * 0.47,
                    decoration: BoxDecoration(
                      color: _PhoneAuthPageState._accentBlue,
                      borderRadius: BorderRadius.circular(24 * unit),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: width * 0.65,
                top: height * 0.32,
                child: Container(
                  width: height * 0.38,
                  height: height * 0.38,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: _PhoneAuthPageState._successBlue,
                  ),
                ),
              ),
              Positioned(
                left: width * 0.1,
                top: height * 0.14,
                child: Transform.rotate(
                  angle: topBarRotation,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: width * 0.54,
                    height: height * 0.064,
                    decoration: BoxDecoration(
                      color: _PhoneAuthPageState._accentBlueDeep,
                      borderRadius: BorderRadius.circular(8 * unit),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CaptchaVerifyDialog extends StatefulWidget {
  const _CaptchaVerifyDialog({
    required this.initialChallenge,
    required this.onRefresh,
    required this.onVerify,
  });

  final AuthCaptchaChallenge initialChallenge;
  final Future<AuthCaptchaChallenge> Function() onRefresh;
  final Future<String> Function({required String token, required String code})
  onVerify;

  @override
  State<_CaptchaVerifyDialog> createState() => _CaptchaVerifyDialogState();
}

class _CaptchaVerifyDialogState extends State<_CaptchaVerifyDialog> {
  final TextEditingController _codeController = TextEditingController();
  late AuthCaptchaChallenge _challenge;
  bool _isRefreshing = false;
  bool _isVerifying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _challenge = widget.initialChallenge;
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _isRefreshing = true;
      _error = null;
    });
    try {
      final AuthCaptchaChallenge next = await widget.onRefresh();
      if (!mounted) {
        return;
      }
      setState(() {
        _challenge = next;
        _codeController.clear();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _submit() async {
    if (_codeController.text.trim().length < 4) {
      setState(() => _error = '请输入图片中的验证码。');
      return;
    }
    setState(() {
      _isVerifying = true;
      _error = null;
    });
    try {
      final String captchaToken = await widget.onVerify(
        token: _challenge.token,
        code: _codeController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(captchaToken);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Uint8List? imageBytes = _captchaBytes(_challenge.imageData);

    return AlertDialog(
      backgroundColor: Colors.white,
      title: const Text('完成图片验证'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '为了继续发送验证码或登录，请先输入图片中的字符。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _PhoneAuthPageState._textMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 96,
              decoration: BoxDecoration(
                color: _PhoneAuthPageState._surfaceMuted,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _PhoneAuthPageState._cardBorder),
              ),
              alignment: Alignment.center,
              child: imageBytes == null || imageBytes.isEmpty
                  ? const Text('图片验证码加载失败')
                  : Image.memory(imageBytes, gaplessPlayback: true),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isRefreshing || _isVerifying ? null : _refresh,
                child: Text(_isRefreshing ? '刷新中...' : '换一张'),
              ),
            ),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.visiblePassword,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: '图片验证码',
                hintText: '请输入图片中的字符',
              ),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.redAccent),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isVerifying ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _isVerifying ? null : _submit,
          child: Text(_isVerifying ? '验证中...' : '继续'),
        ),
      ],
    );
  }
}

Uint8List? _captchaBytes(String imageData) {
  if (imageData.trim().isEmpty) {
    return null;
  }
  final String payload = imageData.contains(',')
      ? imageData.substring(imageData.indexOf(',') + 1)
      : imageData;
  try {
    return base64Decode(payload);
  } catch (_) {
    return null;
  }
}
