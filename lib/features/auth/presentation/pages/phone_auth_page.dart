import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/app_brand.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/data/repositories.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/notifications/passive_toast_notification.dart';
import 'package:sleep_dorm_app/core/widgets/modals/app_modal.dart';
import 'package:sleep_dorm_app/core/widgets/primary_button.dart';

enum _AuthView { login, register, forgotPassword, resetPassword, resetSuccess }

enum _LoginMethod { password, smsCode }

enum _PageTransitionDirection { forward, backward }

class PhoneAuthPage extends StatefulWidget {
  const PhoneAuthPage({super.key});

  @override
  State<PhoneAuthPage> createState() => _PhoneAuthPageState();
}

class _PhoneAuthPageState extends State<PhoneAuthPage> {
  static const double _designWidth = 390;
  static const Color _cardBorder = Color(0xFFDFE3E7);
  static const Color _accentBlue = Color(0xFF90DDF2);
  static const Color _accentBlueSoft = Color(0xFFE8F7FB);
  static const Color _accentBlueDeep = Color(0xFF004F5D);
  static const Color _accentBluePressed = Color(0xFF7CCDE5);
  static const Color _accentBlueDisabled = Color(0xFFCFE4EB);
  static const Color _accentBlueDisabledText = Color(0xFF6F8890);
  static const Color _navyBlue = Color(0xFF204F96);
  static const Color _successBlue = Color(0xFF4EA8C2);
  static const Color _surfaceMuted = Color(0xFFF2F4F6);
  static const Color _surfaceSoft = Color(0xFFECEEF1);
  static const Color _surfaceSoftDisabled = Color(0xFFE9EFF2);
  static const Color _textPrimary = Color(0xFF2F3336);
  static const Color _textSecondary = Color(0xFF5B6063);
  static const Color _textMuted = Color(0xFF57606B);
  static const Color _textHint = Color(0xFFA0A0A0);
  static const Color _actionText = Color(0xFF00697A);
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
  PhoneVerificationProof? _resetVerificationProof;
  Timer? _codeCooldownTimer;
  final Map<String, int> _codeCooldownsByPhone = <String, int>{};
  bool _isSendingLoginCode = false;
  bool _isSendingRegisterCode = false;
  bool _isSendingResetCode = false;
  bool _isSubmitting = false;
  final List<_AuthView> _viewHistory = <_AuthView>[_AuthView.login];
  _PageTransitionDirection _pageTransitionDirection =
      _PageTransitionDirection.forward;

  bool get _isAtAuthRoot =>
      _currentView == _AuthView.login && _viewHistory.length <= 1;

  // Only bumped when a field is explicitly cleared so Android IME/autofill
  // drops remembered text without causing normal focus changes to wipe input.
  int _loginPhoneRemount = 0;
  int _loginCodeRemount = 0;
  int _loginPasswordRemount = 0;
  int _registerPhoneRemount = 0;
  int _registerCodeRemount = 0;
  int _registerPasswordRemount = 0;
  int _registerConfirmPasswordRemount = 0;
  int _resetPhoneRemount = 0;
  int _resetCodeRemount = 0;
  int _resetPasswordRemount = 0;
  int _resetConfirmPasswordRemount = 0;

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
    _resetPhoneController.addListener(_handleResetVerificationInputChanged);
    _resetCodeController.addListener(_handleResetVerificationInputChanged);
    _loginPhoneController.addListener(_handleCooldownPhoneChanged);
    _registerPhoneController.addListener(_handleCooldownPhoneChanged);
    _resetPhoneController.addListener(_handleCooldownPhoneChanged);
  }

  @override
  void dispose() {
    _codeCooldownTimer?.cancel();
    _loginPhoneController.dispose();
    _loginPasswordController.dispose();
    _loginCodeController.dispose();
    _registerPhoneController.dispose();
    _registerCodeController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmPasswordController.dispose();
    _resetPhoneController.removeListener(_handleResetVerificationInputChanged);
    _resetCodeController.removeListener(_handleResetVerificationInputChanged);
    _loginPhoneController.removeListener(_handleCooldownPhoneChanged);
    _registerPhoneController.removeListener(_handleCooldownPhoneChanged);
    _resetPhoneController.removeListener(_handleCooldownPhoneChanged);
    _resetPhoneController.dispose();
    _resetCodeController.dispose();
    _resetPasswordController.dispose();
    _resetConfirmPasswordController.dispose();
    super.dispose();
  }

  void _handleResetVerificationInputChanged() {
    if (_resetVerificationProof == null) {
      return;
    }
    setState(() {
      _resetVerificationProof = null;
      _resetPasswordController.clear();
      _resetConfirmPasswordController.clear();
    });
  }

  void _handleCooldownPhoneChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _startCodeCooldown(String phoneNumber) {
    final String? phoneKey = _mainlandPhoneKey(phoneNumber);
    if (phoneKey == null) {
      return;
    }
    setState(() {
      _codeCooldownsByPhone[phoneKey] = 60;
    });
    _ensureCodeCooldownTicker();
  }

  void _ensureCodeCooldownTicker() {
    if (_codeCooldownTimer?.isActive ?? false) {
      return;
    }
    _codeCooldownTimer = Timer.periodic(const Duration(seconds: 1), (
      Timer timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_codeCooldownsByPhone.isEmpty) {
        timer.cancel();
        _codeCooldownTimer = null;
        return;
      }
      setState(() {
        final List<String> expiredKeys = <String>[];
        _codeCooldownsByPhone.forEach((String key, int value) {
          if (value <= 1) {
            expiredKeys.add(key);
          } else {
            _codeCooldownsByPhone[key] = value - 1;
          }
        });
        for (final String key in expiredKeys) {
          _codeCooldownsByPhone.remove(key);
        }
      });
    });
  }

  int get _loginCodeCooldown => _cooldownForPhone(_loginPhoneController.text);

  int get _registerCodeCooldown =>
      _cooldownForPhone(_registerPhoneController.text);

  int get _resetCodeCooldown => _cooldownForPhone(_resetPhoneController.text);

  int _cooldownForPhone(String phoneNumber) {
    final String? phoneKey = _mainlandPhoneKey(phoneNumber);
    if (phoneKey == null) {
      return 0;
    }
    return _codeCooldownsByPhone[phoneKey] ?? 0;
  }

  String? _mainlandPhoneKey(String value) {
    final String digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 13 && digits.startsWith('86')) {
      final String mainlandDigits = digits.substring(2);
      if (_isValidMainlandPhoneDigits(mainlandDigits)) {
        return mainlandDigits;
      }
    }
    if (_isValidMainlandPhoneDigits(digits)) {
      return digits;
    }
    return null;
  }

  bool _isValidMainlandPhoneDigits(String digits) {
    return RegExp(r'^1[3-9]\d{9}$').hasMatch(digits);
  }

  String _codeButtonLabel({required bool isSending, required int cooldown}) {
    if (isSending) {
      return '发送中...';
    }
    if (cooldown > 0) {
      return '${cooldown}s';
    }
    return '发送验证码';
  }

  void _applyViewState(
    _AuthView view, {
    required _PageTransitionDirection direction,
    bool push = false,
    bool replace = false,
    bool resetStack = false,
  }) {
    setState(() {
      _pageTransitionDirection = direction;
      if (resetStack) {
        _viewHistory
          ..clear()
          ..add(view);
      } else if (replace) {
        if (_viewHistory.isEmpty) {
          _viewHistory.add(view);
        } else {
          _viewHistory[_viewHistory.length - 1] = view;
        }
      } else if (push) {
        if (_viewHistory.isEmpty || _viewHistory.last != view) {
          _viewHistory.add(view);
        }
      }
      _currentView = view;
    });
  }

  void _returnToPreviousView() {
    if (_currentView == _AuthView.resetPassword) {
      setState(() {
        _resetVerificationProof = null;
        _resetPasswordController.clear();
        _resetConfirmPasswordController.clear();
        if (_viewHistory.length > 1) {
          _pageTransitionDirection = _PageTransitionDirection.backward;
          _viewHistory.removeLast();
          _currentView = _viewHistory.last;
        } else {
          _currentView = _AuthView.forgotPassword;
        }
      });
      return;
    }
    if (_viewHistory.length > 1) {
      setState(() {
        _pageTransitionDirection = _PageTransitionDirection.backward;
        _viewHistory.removeLast();
        _currentView = _viewHistory.last;
      });
      return;
    }

    switch (_currentView) {
      case _AuthView.login:
        return;
      case _AuthView.register:
        _switchToLogin(
          phoneNumber: _registerPhoneController.text.trim(),
          replaceCurrent: true,
        );
        return;
      case _AuthView.forgotPassword:
        _switchToLogin(
          phoneNumber: _resetPhoneController.text.trim(),
          replaceCurrent: true,
        );
        return;
      case _AuthView.resetPassword:
        _switchToForgotPassword(
          phoneNumber: _resetPhoneController.text.trim(),
          replaceCurrent: true,
        );
        return;
      case _AuthView.resetSuccess:
        _switchToForgotPassword(
          phoneNumber: _resetPhoneController.text.trim(),
          resetStack: true,
        );
        return;
    }
  }

  void _switchToLogin({
    String? phoneNumber,
    _LoginMethod method = _LoginMethod.password,
    bool replaceCurrent = false,
    bool resetStack = false,
  }) {
    _applyViewState(
      _AuthView.login,
      direction: _PageTransitionDirection.backward,
      replace: replaceCurrent,
      resetStack: resetStack,
    );
    _loginMethod = method;
    if (phoneNumber != null && phoneNumber.trim().isNotEmpty) {
      _loginPhoneController.text = phoneNumber;
    }
    _loginPasswordController.clear();
    _loginCodeController.clear();
    _loginChallenge = null;
  }

  void _switchToRegister(String phoneNumber, {bool replaceCurrent = false}) {
    _applyViewState(
      _AuthView.register,
      direction: replaceCurrent
          ? _PageTransitionDirection.backward
          : _PageTransitionDirection.forward,
      push: !replaceCurrent,
      replace: replaceCurrent,
    );
    _registerPhoneController.text = phoneNumber;
    _registerCodeController.clear();
    _registerPasswordController.clear();
    _registerConfirmPasswordController.clear();
    _registerChallenge = null;
  }

  void _switchToForgotPassword({
    String? phoneNumber,
    bool replaceCurrent = false,
    bool resetStack = false,
    bool preserveResetDraft = false,
  }) {
    _applyViewState(
      _AuthView.forgotPassword,
      direction: replaceCurrent
          ? _PageTransitionDirection.backward
          : _PageTransitionDirection.forward,
      push: !replaceCurrent && !resetStack,
      replace: replaceCurrent,
      resetStack: resetStack,
    );
    if (phoneNumber != null && phoneNumber.trim().isNotEmpty) {
      _resetPhoneController.text = phoneNumber;
    }
    if (!preserveResetDraft) {
      _resetCodeController.clear();
      _resetPasswordController.clear();
      _resetConfirmPasswordController.clear();
      _resetChallenge = null;
      _resetVerificationProof = null;
    }
  }

  void _switchToResetPassword() {
    _applyViewState(
      _AuthView.resetPassword,
      direction: _PageTransitionDirection.forward,
      push: true,
    );
    _resetPasswordController.clear();
    _resetConfirmPasswordController.clear();
  }

  void _switchToResetSuccess() {
    _applyViewState(
      _AuthView.resetSuccess,
      direction: _PageTransitionDirection.forward,
      push: true,
    );
  }

  bool _redirectForUnexpectedChallenge({
    required PhoneVerificationTarget target,
    required PhoneVerificationChallenge challenge,
    required String phoneNumber,
  }) {
    if (target == PhoneVerificationTarget.newUser && challenge.isExistingUser) {
      _switchToLogin(
        phoneNumber: phoneNumber,
        method: _LoginMethod.smsCode,
        replaceCurrent: true,
      );
      _showMessage('该手机号已注册，请直接登录。');
      return true;
    }
    if (target == PhoneVerificationTarget.existingUser &&
        !challenge.isExistingUser) {
      _switchToRegister(
        phoneNumber,
        replaceCurrent: _currentView != _AuthView.login,
      );
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
      _startCodeCooldown(_loginPhoneController.text);
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
      _startCodeCooldown(_registerPhoneController.text);
    } on AuthPhoneTargetMismatchException catch (error) {
      if (!mounted) {
        return;
      }
      _switchToLogin(
        phoneNumber: _registerPhoneController.text.trim(),
        method: _LoginMethod.smsCode,
        replaceCurrent: true,
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

    setState(() {
      _isSendingResetCode = true;
      _resetVerificationProof = null;
      _resetPasswordController.clear();
      _resetConfirmPasswordController.clear();
    });
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
      _startCodeCooldown(_resetPhoneController.text);
    } on AuthPhoneTargetMismatchException catch (error) {
      if (!mounted) {
        return;
      }
      _switchToRegister(
        _resetPhoneController.text.trim(),
        replaceCurrent: true,
      );
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
    final profileFacade = AppScope.of(context).profileFacade;
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

    setState(() => _isSubmitting = true);
    try {
      final PhoneVerificationProof proof = await profileFacade.verifyPhoneCode(
        verificationId: challenge.verificationId,
        code: _resetCodeController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      setState(() => _resetVerificationProof = proof);
      _switchToResetPassword();
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

  Future<void> _submitResetPassword(AppServices services) async {
    await _flushTextEditingState();
    final PhoneVerificationProof? proof = _resetVerificationProof;
    if (proof == null) {
      _showMessage('请先完成验证码验证。');
      return;
    }

    final String? phoneError = _validatePhone(_resetPhoneController.text);
    if (phoneError != null) {
      _showMessage(phoneError);
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
      await services.profileFacade.resetPasswordWithVerificationToken(
        phoneNumber: _resetPhoneController.text.trim(),
        verificationToken: proof.verificationToken,
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
      _switchToLogin(
        phoneNumber: _resetPhoneController.text.trim(),
        resetStack: true,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.toString());
    }
  }

  String? _validatePhone(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '请输入手机号。';
    }
    if (_mainlandPhoneKey(trimmed) == null) {
      return '请输入正确的大陆手机号。';
    }
    return null;
  }

  String? _validatePassword(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '请输入密码。';
    }
    if (trimmed.length < 6) {
      return '密码至少需要 6 位。';
    }
    return null;
  }

  String? _validateCode(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '请输入验证码。';
    }
    if (trimmed.length < 4) {
      return '请输入正确的验证码。';
    }
    return null;
  }

  void _showMessage(String message) {
    notifyPassiveToast(context, message: message);
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
    return showAppModal<String>(
      context,
      spec: AppFormDialogSpec<String>(
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
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
      ),
    );
  }

  bool get _canSubmitRegister =>
      _registerChallenge != null &&
      _validatePhone(_registerPhoneController.text) == null &&
      _validateCode(_registerCodeController.text) == null &&
      _validatePassword(_registerPasswordController.text) == null &&
      _registerPasswordController.text ==
          _registerConfirmPasswordController.text &&
      _registerConfirmPasswordController.text.isNotEmpty;

  bool get _canSubmitResetPassword =>
      _resetVerificationProof != null &&
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

  double _frameWidthFor(BoxConstraints constraints) {
    if (constraints.maxWidth < 650) {
      return constraints.maxWidth;
    }
    final double widthTarget = constraints.maxWidth < 1100
        ? constraints.maxWidth * 0.58
        : constraints.maxWidth * 0.26;
    final double heightSafeTarget =
        constraints.maxHeight * (_designWidth / 844);
    return math.min(widthTarget, heightSafeTarget);
  }

  double _framePaddingFor(double frameWidth) {
    return frameWidth * (32 / _designWidth);
  }

  Widget _buildCurrentPage(
    BuildContext context,
    AppServices services,
    double unit,
  ) {
    return switch (_currentView) {
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
      _AuthView.resetSuccess => _buildResetSuccessPage(context, services, unit),
    };
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

    return _PencilSplitPage(
      unit: unit,
      bodyChildren: <Widget>[
        _PencilLogoTopSquare(size: 52 * unit),
        SizedBox(height: 20 * unit),
        Text(
          AppBrand.loginTitle,
          style: _textStyle(
            context,
            size: 32 * unit,
            weight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
        SizedBox(height: 20 * unit),
        _buildLoginMethodSwitch(context, unit),
        SizedBox(height: 20 * unit),
        _PencilInputField(
          fieldKey: ValueKey<String>('auth-login-phone-$_loginPhoneRemount'),
          label: '手机号',
          hintText: '请输入手机号',
          controller: _loginPhoneController,
          icon: Icons.smartphone_rounded,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
          textInputAction: usePassword
              ? TextInputAction.next
              : TextInputAction.done,
          scaleUnit: unit,
          forceHighlightedBorder: true,
          clearSemanticsLabel: '清除手机号',
          onChanged: (_) {
            if (_loginChallenge != null) {
              setState(() => _loginChallenge = null);
            }
          },
          onImeRemount: () => setState(() => _loginPhoneRemount += 1),
        ),
        SizedBox(height: 12 * unit),
        if (usePassword)
          _PencilInputField(
            fieldKey: ValueKey<String>(
              'auth-login-password-$_loginPasswordRemount',
            ),
            label: '密码',
            hintText: '请输入密码',
            controller: _loginPasswordController,
            icon: Icons.lock_outline_rounded,
            textInputAction: TextInputAction.done,
            obscureText: true,
            scaleUnit: unit,
            clearSemanticsLabel: '清除密码',
            onImeRemount: () => setState(() => _loginPasswordRemount += 1),
          )
        else
          _buildCodeFieldRow(
            context,
            label: '短信验证码',
            hintText: '请输入验证码',
            controller: _loginCodeController,
            fieldKey: ValueKey<String>('auth-login-code-$_loginCodeRemount'),
            actionKey: const ValueKey<String>('auth-login-code-send'),
            buttonLabel: _codeButtonLabel(
              isSending: _isSendingLoginCode,
              cooldown: _loginCodeCooldown,
            ),
            onPressed: _isSendingLoginCode || _loginCodeCooldown > 0
                ? null
                : () => _sendLoginCode(services),
            unit: unit,
            onImeRemount: () => setState(() => _loginCodeRemount += 1),
          ),
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
              loadingLabel: '登录中...',
              isLoading: _isSubmitting,
              unit: unit,
              onPressed: _isSubmitting
                  ? null
                  : usePassword
                  ? () => _submitLoginWithPassword(services)
                  : () => _submitLoginWithCode(services),
            );
          },
        ),
      ],
      footer: _PencilFooterCard(
        title: '还没有账号？',
        actionLabel: '立即注册',
        unit: unit,
        onTap: () => _switchToRegister(_loginPhoneController.text.trim()),
        actionKey: const ValueKey<String>('auth-mode-register'),
      ),
    );
  }

  Widget _buildRegisterPage(
    BuildContext context,
    AppServices services,
    double unit,
  ) {
    return _PencilSplitPage(
      unit: unit,
      bodyChildren: <Widget>[
        _PencilTopSquare(
          icon: Icons.person_add_alt_1_rounded,
          iconSize: 26 * unit,
          size: 52 * unit,
          radius: 16 * unit,
          backgroundColor: _accentBlue,
          iconColor: _accentBlueDeep,
        ),
        SizedBox(height: 20 * unit),
        Text(
          '注册',
          style: _textStyle(
            context,
            size: 32 * unit,
            weight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
        SizedBox(height: 20 * unit),
        _PencilInputField(
          fieldKey: ValueKey<String>(
            'auth-register-phone-$_registerPhoneRemount',
          ),
          label: '手机号',
          hintText: '请输入手机号',
          controller: _registerPhoneController,
          icon: Icons.smartphone_rounded,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
          textInputAction: TextInputAction.next,
          scaleUnit: unit,
          clearSemanticsLabel: '清除手机号',
          onChanged: (_) {
            if (_registerChallenge != null) {
              setState(() => _registerChallenge = null);
            }
          },
          onImeRemount: () => setState(() => _registerPhoneRemount += 1),
        ),
        SizedBox(height: 12 * unit),
        _buildCodeFieldRow(
          context,
          label: '短信验证码',
          hintText: '请输入验证码',
          controller: _registerCodeController,
          fieldKey: ValueKey<String>(
            'auth-register-code-$_registerCodeRemount',
          ),
          actionKey: const ValueKey<String>('auth-register-send'),
          buttonLabel: _codeButtonLabel(
            isSending: _isSendingRegisterCode,
            cooldown: _registerCodeCooldown,
          ),
          onPressed: _isSendingRegisterCode || _registerCodeCooldown > 0
              ? null
              : () => _sendRegisterCode(services),
          unit: unit,
          onImeRemount: () => setState(() => _registerCodeRemount += 1),
        ),
        SizedBox(height: 12 * unit),
        _PencilInputField(
          fieldKey: ValueKey<String>(
            'auth-register-password-$_registerPasswordRemount',
          ),
          label: '密码',
          hintText: '请设置登录密码',
          controller: _registerPasswordController,
          icon: Icons.lock_outline_rounded,
          textInputAction: TextInputAction.next,
          obscureText: true,
          scaleUnit: unit,
          clearSemanticsLabel: '清除密码',
          onImeRemount: () => setState(() => _registerPasswordRemount += 1),
        ),
        SizedBox(height: 12 * unit),
        _PencilInputField(
          fieldKey: ValueKey<String>(
            'auth-register-password-confirm-$_registerConfirmPasswordRemount',
          ),
          label: '确认密码',
          hintText: '请再次输入密码',
          controller: _registerConfirmPasswordController,
          icon: Icons.lock_outline_rounded,
          textInputAction: TextInputAction.done,
          obscureText: true,
          scaleUnit: unit,
          clearSemanticsLabel: '清除确认密码',
          onImeRemount: () =>
              setState(() => _registerConfirmPasswordRemount += 1),
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
              loadingLabel: '注册中...',
              isLoading: _isSubmitting,
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
      footer: _PencilFooterCard(
        title: '已经有账号？',
        actionLabel: '返回登录',
        unit: unit,
        onTap: () => _switchToLogin(
          phoneNumber: _registerPhoneController.text.trim(),
          replaceCurrent: true,
        ),
        actionKey: const ValueKey<String>('auth-mode-login'),
      ),
    );
  }

  Widget _buildForgotPasswordPage(
    BuildContext context,
    AppServices services,
    double unit,
  ) {
    return _PencilSplitPage(
      unit: unit,
      bodyChildren: <Widget>[
        _PencilTopSquare(
          icon: Icons.chevron_left_rounded,
          iconSize: 24 * unit,
          size: 48 * unit,
          radius: 14 * unit,
          backgroundColor: _accentBlue,
          iconColor: _accentBlueDeep,
          onTap: _returnToPreviousView,
        ),
        SizedBox(height: 24 * unit),
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
          fieldKey: ValueKey<String>('auth-reset-phone-$_resetPhoneRemount'),
          label: '手机号',
          hintText: '请输入已绑定手机号',
          controller: _resetPhoneController,
          icon: Icons.smartphone_rounded,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
          textInputAction: TextInputAction.next,
          scaleUnit: unit,
          clearSemanticsLabel: '清除手机号',
          onChanged: (_) {
            if (_resetChallenge != null) {
              setState(() => _resetChallenge = null);
            }
          },
          onImeRemount: () => setState(() => _resetPhoneRemount += 1),
        ),
        SizedBox(height: 12 * unit),
        _buildCodeFieldRow(
          context,
          label: '短信验证码',
          hintText: '请输入验证码',
          controller: _resetCodeController,
          fieldKey: ValueKey<String>('auth-reset-code-$_resetCodeRemount'),
          actionKey: const ValueKey<String>('auth-reset-send'),
          buttonLabel: _codeButtonLabel(
            isSending: _isSendingResetCode,
            cooldown: _resetCodeCooldown,
          ),
          onPressed: _isSendingResetCode || _resetCodeCooldown > 0
              ? null
              : () => _sendResetCode(services),
          unit: unit,
          onImeRemount: () => setState(() => _resetCodeRemount += 1),
        ),
        SizedBox(height: 12 * unit),
        ListenableBuilder(
          listenable: _forgotPasswordFormListenable,
          builder: (BuildContext context, Widget? child) {
            return _PencilFilledButton(
              buttonKey: const ValueKey<String>('auth-reset-verify'),
              label: '验证并继续',
              loadingLabel: '验证中...',
              isLoading: _isSubmitting,
              unit: unit,
              onPressed: _isSubmitting ? null : _verifyResetCode,
            );
          },
        ),
      ],
      footer: _PencilSupportCard(
        title: '无法接收验证码？',
        subtitle: '联系客服协助处理',
        unit: unit,
      ),
    );
  }

  Widget _buildResetPasswordPage(
    BuildContext context,
    AppServices services,
    double unit,
  ) {
    return _PencilSplitPage(
      unit: unit,
      bodyChildren: <Widget>[
        _PencilTopSquare(
          icon: Icons.chevron_left_rounded,
          iconSize: 24 * unit,
          size: 48 * unit,
          radius: 14 * unit,
          backgroundColor: _accentBlue,
          iconColor: _accentBlueDeep,
          onTap: _returnToPreviousView,
        ),
        SizedBox(height: 24 * unit),
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
          fieldKey: ValueKey<String>(
            'auth-reset-password-$_resetPasswordRemount',
          ),
          label: '新密码',
          hintText: '请输入新的登录密码',
          controller: _resetPasswordController,
          icon: Icons.lock_outline_rounded,
          textInputAction: TextInputAction.next,
          obscureText: true,
          scaleUnit: unit,
          clearSemanticsLabel: '清除新密码',
          onImeRemount: () => setState(() => _resetPasswordRemount += 1),
        ),
        SizedBox(height: 12 * unit),
        _PencilInputField(
          fieldKey: ValueKey<String>(
            'auth-reset-password-confirm-$_resetConfirmPasswordRemount',
          ),
          label: '确认新密码',
          hintText: '再次输入新密码',
          controller: _resetConfirmPasswordController,
          icon: Icons.lock_outline_rounded,
          textInputAction: TextInputAction.done,
          obscureText: true,
          scaleUnit: unit,
          clearSemanticsLabel: '清除确认新密码',
          onImeRemount: () => setState(() => _resetConfirmPasswordRemount += 1),
        ),
        SizedBox(height: 12 * unit),
        ListenableBuilder(
          listenable: _resetPasswordFormListenable,
          builder: (BuildContext context, Widget? child) {
            return _PencilFilledButton(
              buttonKey: const ValueKey<String>('auth-reset-submit'),
              label: '确认重置密码',
              loadingLabel: '重置中...',
              isLoading: _isSubmitting,
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
      footer: _PencilSupportCard(
        title: '无法接收验证码？',
        subtitle: '联系客服协助处理',
        unit: unit,
      ),
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
      ],
    );
  }

  Widget _buildLoginMethodSwitch(BuildContext context, double unit) {
    final bool usePassword = _loginMethod == _LoginMethod.password;
    return Row(
      children: <Widget>[
        Expanded(
          child: _PencilSegmentButton(
            segmentKey: const ValueKey<String>('auth-login-method-password'),
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
    required String buttonLabel,
    required VoidCallback? onPressed,
    required double unit,
    VoidCallback? onImeRemount,
    ValueChanged<String>? onChanged,
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
              flex: 2,
              child: _PencilBareInput(
                fieldKey: fieldKey,
                hintText: hintText,
                controller: controller,
                icon: Icons.sms_outlined,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                textInputAction: TextInputAction.done,
                scaleUnit: unit,
                clearSemanticsLabel: '清除验证码',
                onImeRemount: onImeRemount,
                onChanged: onChanged,
              ),
            ),
            SizedBox(width: 10 * unit),
            Expanded(
              child: _PencilSoftButton(
                buttonKey: actionKey,
                label: buttonLabel,
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
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final Widget authContent = PopScope<void>(
      canPop: _isAtAuthRoot,
      onPopInvokedWithResult: (bool didPop, void _) {
        if (!didPop && !_isAtAuthRoot) {
          _returnToPreviousView();
        }
      },
      child: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double frameWidth = _frameWidthFor(constraints);
            final double unit = frameWidth / _designWidth;
            final double framePadding = _framePaddingFor(frameWidth);
            final double horizontalInset =
                ((constraints.maxWidth - frameWidth) / 2) + framePadding;
            final double verticalInset = framePadding;
            final double minPageHeight = math.max(
              constraints.maxHeight - (verticalInset * 2),
              0,
            );
            final ValueKey<String> activeKey = ValueKey<String>(
              _currentView.name,
            );
            final double transitionSign =
                _pageTransitionDirection == _PageTransitionDirection.forward
                ? 1
                : -1;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalInset,
                verticalInset,
                horizontalInset,
                verticalInset + keyboardInset,
              ),
              physics: const ClampingScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minPageHeight),
                child: IntrinsicHeight(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    layoutBuilder:
                        (Widget? currentChild, List<Widget> previousChildren) {
                          final List<Widget> stackedChildren = List<Widget>.of(
                            previousChildren,
                          );
                          if (currentChild != null) {
                            stackedChildren.add(currentChild);
                          }
                          return Stack(
                            alignment: Alignment.topCenter,
                            children: stackedChildren,
                          );
                        },
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                          final bool isIncoming = child.key == activeKey;
                          return AnimatedBuilder(
                            animation: animation,
                            child: child,
                            builder: (BuildContext context, Widget? child) {
                              final double progress = animation.value;
                              final double xOffset = isIncoming
                                  ? (1 - progress) * transitionSign
                                  : (1 - progress) * -transitionSign * 0.18;
                              return Opacity(
                                opacity: progress,
                                child: FractionalTranslation(
                                  translation: Offset(xOffset, 0),
                                  child: child,
                                ),
                              );
                            },
                          );
                        },
                    child: KeyedSubtree(
                      key: activeKey,
                      child: _buildCurrentPage(context, services, unit),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    final bool hasRouter = Router.maybeOf(context) != null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: false,
        body: hasRouter
            ? BackButtonListener(
                onBackButtonPressed: () async {
                  if (_isAtAuthRoot) {
                    return false;
                  }
                  _returnToPreviousView();
                  return true;
                },
                child: authContent,
              )
            : authContent,
      ),
    );
  }
}

class _PencilSplitPage extends StatelessWidget {
  const _PencilSplitPage({
    required this.unit,
    required this.bodyChildren,
    required this.footer,
  });

  final double unit;
  final List<Widget> bodyChildren;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final bool compactFooter = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: compactFooter
          ? MainAxisAlignment.start
          : MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ...bodyChildren,
            SizedBox(height: 24 * unit),
          ],
        ),
        footer,
      ],
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

class _PencilLogoTopSquare extends StatelessWidget {
  const _PencilLogoTopSquare({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey<String>('auth-login-logo'),
      width: size,
      height: size,
      child: Center(
        child: Image.asset(
          AppBrand.logoAssetPath,
          width: size,
          height: size,
          fit: BoxFit.contain,
          semanticLabel: AppBrand.displayName,
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
    this.inputFormatters,
    this.onChanged,
    this.clearSemanticsLabel,
    this.onImeRemount,
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
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final String? clearSemanticsLabel;
  final VoidCallback? onImeRemount;

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
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          clearSemanticsLabel: clearSemanticsLabel,
          onImeRemount: onImeRemount,
        ),
      ],
    );
  }
}

class _PencilBareInput extends StatefulWidget {
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
    this.inputFormatters,
    this.onChanged,
    this.clearSemanticsLabel,
    this.onImeRemount,
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
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final String? clearSemanticsLabel;
  final VoidCallback? onImeRemount;

  @override
  State<_PencilBareInput> createState() => _PencilBareInputState();
}

class _PencilBareInputState extends State<_PencilBareInput> {
  late bool _obscured;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText;
  }

  @override
  void didUpdateWidget(covariant _PencilBareInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.obscureText != widget.obscureText) {
      _obscured = widget.obscureText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color borderColor = widget.forceHighlightedBorder
        ? _PhoneAuthPageState._successBlue
        : _PhoneAuthPageState._cardBorder;
    final double borderWidth = widget.forceHighlightedBorder
        ? 2 * widget.scaleUnit
        : widget.scaleUnit;
    final bool showsClearButton = widget.clearSemanticsLabel != null;
    final Widget? suffixIcon = showsClearButton || widget.obscureText
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (showsClearButton)
                _ClearFieldButton(
                  controller: widget.controller,
                  semanticsLabel: widget.clearSemanticsLabel!,
                  onCleared: widget.onChanged,
                  onImeRemount: widget.onImeRemount,
                ),
              if (widget.obscureText)
                IconButton(
                  onPressed: () {
                    setState(() => _obscured = !_obscured);
                  },
                  splashRadius: 18 * widget.scaleUnit,
                  icon: Icon(
                    _obscured
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20 * widget.scaleUnit,
                    color: _PhoneAuthPageState._textHint,
                  ),
                ),
            ],
          )
        : null;

    return Container(
      height: 56 * widget.scaleUnit,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18 * widget.scaleUnit),
        border: Border.all(color: borderColor, width: math.max(1, borderWidth)),
        boxShadow: widget.forceHighlightedBorder
            ? <BoxShadow>[
                BoxShadow(
                  color: _PhoneAuthPageState._focusShadow,
                  blurRadius: 24 * widget.scaleUnit,
                  offset: Offset(0, 10 * widget.scaleUnit),
                ),
              ]
            : const <BoxShadow>[],
      ),
      child: TextField(
        key: widget.fieldKey,
        controller: widget.controller,
        obscureText: _obscured,
        obscuringCharacter: '•',
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
        enableSuggestions: false,
        autocorrect: false,
        enableIMEPersonalizedLearning: false,
        smartDashesType: SmartDashesType.disabled,
        smartQuotesType: SmartQuotesType.disabled,
        autofillHints: const <String>[],
        inputFormatters: widget.inputFormatters,
        onChanged: widget.onChanged,
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
          fontSize: 14 * widget.scaleUnit,
          fontWeight: FontWeight.w500,
          color: _PhoneAuthPageState._textPrimary,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
            fontSize: 14 * widget.scaleUnit,
            fontWeight: widget.obscureText ? FontWeight.w600 : FontWeight.w500,
            color: widget.forceHighlightedBorder
                ? _PhoneAuthPageState._textPrimary
                : widget.obscureText
                ? _PhoneAuthPageState._textPrimary
                : _PhoneAuthPageState._textHint,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 18 * widget.scaleUnit),
          prefixIcon: Icon(
            widget.icon,
            size: 20 * widget.scaleUnit,
            color: _PhoneAuthPageState._textSecondary,
          ),
          prefixIconConstraints: BoxConstraints(
            minWidth: 48 * widget.scaleUnit,
            minHeight: 56 * widget.scaleUnit,
          ),
          suffixIcon: suffixIcon,
          suffixIconConstraints: BoxConstraints(
            minWidth: 48 * widget.scaleUnit,
            minHeight: 56 * widget.scaleUnit,
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
    this.isLoading = false,
    this.loadingLabel,
  });

  final Key buttonKey;
  final String label;
  final double unit;
  final VoidCallback? onPressed;
  final bool isLoading;
  final String? loadingLabel;

  @override
  Widget build(BuildContext context) {
    final String resolvedLabel = loadingLabel ?? label;
    return SizedBox(
      key: buttonKey,
      width: double.infinity,
      height: 58 * unit,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18 * unit),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: _PhoneAuthPageState._buttonShadow,
              blurRadius: 30 * unit,
              offset: Offset(0, 16 * unit),
            ),
          ],
        ),
        child: FilledButton(
          onPressed: onPressed,
          style:
              FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18 * unit),
                ),
                textStyle: Theme.of(context).textTheme.bodyLarge!.copyWith(
                  fontSize: 16 * unit,
                  fontWeight: FontWeight.w700,
                ),
              ).copyWith(
                backgroundColor: WidgetStateProperty.resolveWith<Color>((
                  Set<WidgetState> states,
                ) {
                  if (states.contains(WidgetState.disabled)) {
                    return _PhoneAuthPageState._accentBlueDisabled;
                  }
                  if (states.contains(WidgetState.pressed)) {
                    return _PhoneAuthPageState._accentBluePressed;
                  }
                  return _PhoneAuthPageState._accentBlue;
                }),
                foregroundColor: WidgetStateProperty.resolveWith<Color>((
                  Set<WidgetState> states,
                ) {
                  if (states.contains(WidgetState.disabled)) {
                    return _PhoneAuthPageState._accentBlueDisabledText;
                  }
                  return _PhoneAuthPageState._accentBlueDeep;
                }),
                overlayColor: WidgetStateProperty.resolveWith<Color?>((
                  Set<WidgetState> states,
                ) {
                  if (states.contains(WidgetState.pressed)) {
                    return _PhoneAuthPageState._accentBlueDeep.withValues(
                      alpha: 0.08,
                    );
                  }
                  return null;
                }),
              ),
          child: isLoading
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    SizedBox.square(
                      dimension: 18 * unit,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          _PhoneAuthPageState._accentBlueDeep,
                        ),
                      ),
                    ),
                    SizedBox(width: 12 * unit),
                    Text(resolvedLabel),
                  ],
                )
              : Text(label),
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
    return SizedBox(
      key: buttonKey,
      height: 56 * unit,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: 10 * unit),
          elevation: 0,
          backgroundColor: _PhoneAuthPageState._accentBlueSoft,
          disabledBackgroundColor: _PhoneAuthPageState._surfaceSoftDisabled,
          foregroundColor: _PhoneAuthPageState._actionText,
          disabledForegroundColor: _PhoneAuthPageState._textMuted,
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
                      color: const Color(0xFF8EDDF2),
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

class _ClearFieldButton extends StatelessWidget {
  const _ClearFieldButton({
    required this.controller,
    required this.semanticsLabel,
    this.onCleared,
    this.onImeRemount,
  });

  final TextEditingController controller;
  final String semanticsLabel;
  final ValueChanged<String>? onCleared;
  final VoidCallback? onImeRemount;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (BuildContext context, TextEditingValue value, Widget? _) {
        if (value.text.isEmpty) {
          return const SizedBox.shrink();
        }
        return Semantics(
          button: true,
          label: semanticsLabel,
          child: IconButton(
            splashRadius: 18,
            icon: const Icon(Icons.close_rounded),
            onPressed: () {
              controller.clear();
              TextInput.finishAutofillContext(shouldSave: false);
              onCleared?.call('');
              onImeRemount?.call();
            },
          ),
        );
      },
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

    return AppFormDialogScaffold(
      title: '完成图片验证',
      body: '为了继续发送验证码或登录，请先输入图片中的字符。',
      icon: const AppDialogIconSpec(icon: Icons.verified_user_outlined),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
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
      actions: <Widget>[
        AppModalAction(
          label: '取消',
          variant: PrimaryButtonVariant.ghost,
          onPressed: _isVerifying ? null : () => Navigator.of(context).pop(),
        ),
        AppModalAction(
          label: _isVerifying ? '验证中...' : '继续',
          onPressed: _isVerifying ? null : _submit,
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
