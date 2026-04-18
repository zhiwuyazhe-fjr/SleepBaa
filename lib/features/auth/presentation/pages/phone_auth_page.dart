import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_auth_client.dart';
import 'package:sleep_dorm_app/core/data/repositories.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/primary_button.dart';

enum _AuthView { login, register, resetPassword }

enum _LoginMethod { password, smsCode }

class PhoneAuthPage extends StatefulWidget {
  const PhoneAuthPage({super.key});

  @override
  State<PhoneAuthPage> createState() => _PhoneAuthPageState();
}

class _PhoneAuthPageState extends State<PhoneAuthPage> {
  static const Color _authAccent = Color(0xFF90DDF2);
  static const Color _authAccentSoft = Color(0xFFE8F7FB);
  static const Color _authAccentDeep = Color(0xFF004F5D);
  static const Color _stageStart = Color(0xFF2F67EC);
  static const Color _stageMid = Color(0xFF5E93FF);
  static const Color _stageEnd = Color(0xFFEAF2FF);

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
  late final Listenable _resetFormListenable;

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
    _resetFormListenable = Listenable.merge(<Listenable>[
      _resetPhoneController,
      _resetCodeController,
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

  void _switchToRegister(String phoneNumber) {
    setState(() {
      _currentView = _AuthView.register;
      _registerPhoneController.text = phoneNumber;
      _registerCodeController.clear();
      _loginChallenge = null;
      _registerChallenge = null;
      _resetChallenge = null;
    });
  }

  void _switchToLoginWithSms(String phoneNumber) {
    setState(() {
      _currentView = _AuthView.login;
      _loginMethod = _LoginMethod.smsCode;
      _loginPhoneController.text = phoneNumber;
      _loginCodeController.clear();
      _loginChallenge = null;
      _registerChallenge = null;
      _resetChallenge = null;
    });
  }

  bool _redirectForUnexpectedChallenge({
    required PhoneVerificationTarget target,
    required PhoneVerificationChallenge challenge,
    required String phoneNumber,
  }) {
    if (target == PhoneVerificationTarget.newUser && challenge.isExistingUser) {
      _switchToLoginWithSms(phoneNumber);
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
      if (challenge == null) {
        return;
      }
      if (!mounted) {
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
      _showMessage('验证码已发送，请查看短信。');
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
      if (challenge == null) {
        return;
      }
      if (!mounted) {
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
      _showMessage('验证码已发送，请继续完成注册。');
    } on AuthPhoneTargetMismatchException catch (error) {
      if (!mounted) {
        return;
      }
      _switchToLoginWithSms(_registerPhoneController.text.trim());
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
      if (challenge == null) {
        return;
      }
      if (!mounted) {
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
      _showMessage('验证码已发送，请继续重置密码。');
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
      if (!completed) {
        return;
      }
      if (!mounted) {
        return;
      }
      _showMessage('登录成功。');
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
      if (!completed) {
        return;
      }
      if (!mounted) {
        return;
      }
      _showMessage('登录成功。');
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
      _showMessage('注册成功，已为你登录。');
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
      _showMessage('密码已重置，已为你登录。');
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

  ThemeData _buildAuthTheme(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final NightMoodPalette palette = context.nightMoodPalette.copyWith(
      primary: _authAccent,
      primarySoft: _authAccentSoft,
      primaryHighlight: _authAccentSoft,
      primaryDeep: _authAccentDeep,
      calmBlue: AppColors.calmBlue,
      welcomeAccentColor: _authAccent,
      welcomeTextOnAccent: _authAccentDeep,
    );

    return theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        primary: _authAccent,
        onPrimary: _authAccentDeep,
        secondary: _authAccentDeep,
        surface: AppColors.surface,
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: theme.textTheme.bodyMedium?.copyWith(
          color: AppColors.textHint,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.surfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.surfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.calmBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textHint,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _authAccentDeep,
          textStyle: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[palette],
    );
  }

  void _showRegisterFromFooter() {
    setState(() {
      _currentView = _AuthView.register;
      _registerPhoneController.text = _loginPhoneController.text;
    });
  }

  void _showLoginFromFooter() {
    setState(() {
      _currentView = _AuthView.login;
      _loginMethod = _LoginMethod.password;
      _loginPhoneController.text = _registerPhoneController.text;
    });
  }

  Widget _buildLoginMethodSwitch() {
    return Row(
      children: <Widget>[
        Expanded(
          child: _AuthSegmentButton(
            key: const ValueKey<String>('auth-login-method-password'),
            label: '密码登录',
            selected: _loginMethod == _LoginMethod.password,
            onTap: () {
              setState(() => _loginMethod = _LoginMethod.password);
            },
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _AuthSegmentButton(
            key: const ValueKey<String>('auth-login-method-code'),
            label: '验证码登录',
            selected: _loginMethod == _LoginMethod.smsCode,
            onTap: () {
              setState(() => _loginMethod = _LoginMethod.smsCode);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField({
    required Key fieldKey,
    required TextEditingController controller,
    required ValueChanged<String>? onChanged,
    required String label,
    String hintText = '请输入手机号',
  }) {
    return _AuthFieldGroup(
      label: label,
      child: TextField(
        key: fieldKey,
        controller: controller,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.next,
        autofillHints: const <String>[AutofillHints.telephoneNumber],
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.allow(RegExp(r'[\d+\-\s]')),
        ],
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.smartphone_rounded),
        ),
      ),
    );
  }

  Widget _buildPasswordFieldGroup({
    required Key fieldKey,
    required TextEditingController controller,
    required String label,
    required String hintText,
    required TextInputAction textInputAction,
  }) {
    return _AuthFieldGroup(
      label: label,
      child: _AuthPasswordField(
        fieldKey: fieldKey,
        controller: controller,
        labelText: label,
        hintText: hintText,
        textInputAction: textInputAction,
      ),
    );
  }

  Widget _buildCodeFieldWithAction({
    required String label,
    required Key fieldKey,
    required TextEditingController controller,
    required Key actionKey,
    required String actionLabel,
    required bool isLoading,
    required VoidCallback? onPressed,
  }) {
    final Widget sendButton = PrimaryButton(
      key: actionKey,
      label: isLoading ? '发送中...' : actionLabel,
      variant: PrimaryButtonVariant.soft,
      foregroundColor: _authAccentDeep,
      onPressed: onPressed,
    );

    return _AuthFieldGroup(
      label: label,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (constraints.maxWidth < MediaQuery.sizeOf(context).width * 0.46) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _buildCodeField(fieldKey: fieldKey, controller: controller),
                const SizedBox(height: AppSpacing.sm),
                sendButton,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: _buildCodeField(
                  fieldKey: fieldKey,
                  controller: controller,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(width: constraints.maxWidth * 0.3, child: sendButton),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCodeField({
    required Key fieldKey,
    required TextEditingController controller,
  }) {
    return TextField(
      key: fieldKey,
      controller: controller,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      decoration: const InputDecoration(
        hintText: '请输入短信验证码',
        prefixIcon: Icon(Icons.sms_rounded),
      ),
    );
  }

  Widget _buildLoginPanel(AppServices services, {required bool compact}) {
    final double fieldGap = compact ? AppSpacing.xs : AppSpacing.sm;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (compact) ...<Widget>[
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const ValueKey<String>('auth-mode-register'),
              onPressed: _showRegisterFromFooter,
              child: const Text('免费注册'),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        _buildLoginMethodSwitch(),
        SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
        _buildPhoneField(
          fieldKey: const ValueKey<String>('auth-login-phone'),
          controller: _loginPhoneController,
          label: '手机号',
          onChanged: (_) {
            if (_loginChallenge != null) {
              setState(() => _loginChallenge = null);
            }
          },
        ),
        SizedBox(height: fieldGap),
        if (_loginMethod == _LoginMethod.password) ...<Widget>[
          _buildPasswordFieldGroup(
            fieldKey: const ValueKey<String>('auth-login-password'),
            controller: _loginPasswordController,
            label: '登录密码',
            hintText: '请输入登录密码',
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const ValueKey<String>('auth-forgot-password'),
              onPressed: () {
                _resetPhoneController.text = _loginPhoneController.text;
                setState(() => _currentView = _AuthView.resetPassword);
              },
              child: const Text('忘记密码'),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          ListenableBuilder(
            listenable: _loginPasswordFormListenable,
            builder: (BuildContext context, Widget? child) {
              final bool canSubmit = !_isSubmitting;
              return PrimaryButton(
                key: const ValueKey<String>('auth-login-password-submit'),
                label: _isSubmitting ? '登录中...' : '登录',
                foregroundColor: _authAccentDeep,
                onPressed: canSubmit
                    ? () => _submitLoginWithPassword(services)
                    : null,
              );
            },
          ),
        ] else ...<Widget>[
          _buildCodeFieldWithAction(
            label: '短信验证码',
            fieldKey: const ValueKey<String>('auth-login-code'),
            controller: _loginCodeController,
            actionKey: const ValueKey<String>('auth-login-code-send'),
            actionLabel: '发送验证码',
            isLoading: _isSendingLoginCode,
            onPressed: _isSendingLoginCode || _isSubmitting
                ? null
                : () => _sendLoginCode(services),
          ),
          SizedBox(height: fieldGap),
          ListenableBuilder(
            listenable: _loginCodeFormListenable,
            builder: (BuildContext context, Widget? child) {
              final bool canSubmit =
                  !_isSubmitting &&
                  _loginPhoneController.text.trim().isNotEmpty &&
                  _loginCodeController.text.trim().isNotEmpty;
              return PrimaryButton(
                key: const ValueKey<String>('auth-login-code-submit'),
                label: _isSubmitting ? '登录中...' : '验证码登录',
                foregroundColor: _authAccentDeep,
                onPressed: canSubmit
                    ? () => _submitLoginWithCode(services)
                    : null,
              );
            },
          ),
        ],
        if (!compact) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          _AuthFooterSwitchCard(
            key: const ValueKey<String>('auth-mode-register'),
            prompt: '还没有账号？',
            actionLabel: '免费注册',
            compact: false,
            onTap: _showRegisterFromFooter,
          ),
        ],
      ],
    );
  }

  Widget _buildRegisterPanel(AppServices services, {required bool compact}) {
    final double fieldGap = compact ? AppSpacing.xs : AppSpacing.sm;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (compact) ...<Widget>[
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const ValueKey<String>('auth-mode-login'),
              onPressed: _showLoginFromFooter,
              child: const Text('返回登录'),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        _buildPhoneField(
          fieldKey: const ValueKey<String>('auth-register-phone'),
          controller: _registerPhoneController,
          label: '手机号',
          onChanged: (_) {
            if (_registerChallenge != null) {
              setState(() => _registerChallenge = null);
            }
          },
        ),
        SizedBox(height: fieldGap),
        _buildCodeFieldWithAction(
          label: '短信验证码',
          fieldKey: const ValueKey<String>('auth-register-code'),
          controller: _registerCodeController,
          actionKey: const ValueKey<String>('auth-register-send'),
          actionLabel: '发送验证码',
          isLoading: _isSendingRegisterCode,
          onPressed: _isSendingRegisterCode || _isSubmitting
              ? null
              : () => _sendRegisterCode(services),
        ),
        SizedBox(height: fieldGap),
        _buildPasswordFieldGroup(
          fieldKey: const ValueKey<String>('auth-register-password'),
          controller: _registerPasswordController,
          label: '设置密码',
          hintText: '请设置登录密码',
          textInputAction: TextInputAction.next,
        ),
        SizedBox(height: fieldGap),
        _buildPasswordFieldGroup(
          fieldKey: const ValueKey<String>('auth-register-password-confirm'),
          controller: _registerConfirmPasswordController,
          label: '确认密码',
          hintText: '请再次输入密码',
          textInputAction: TextInputAction.done,
        ),
        if (!compact) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          const _AuthInfoBox(
            icon: Icons.shield_outlined,
            message: '注册仅支持手机号。完成短信验证后即可创建账号，并同时设置登录密码。',
          ),
          const SizedBox(height: AppSpacing.sm),
        ] else ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            '完成短信验证后即可创建账号，并同时设置登录密码。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        ListenableBuilder(
          listenable: _registerFormListenable,
          builder: (BuildContext context, Widget? child) {
            final bool canSubmit = !_isSubmitting;
            return PrimaryButton(
              key: const ValueKey<String>('auth-register-submit'),
              label: _isSubmitting ? '注册中...' : '注册并登录',
              foregroundColor: _authAccentDeep,
              onPressed: canSubmit ? () => _submitRegister(services) : null,
            );
          },
        ),
        if (!compact) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          _AuthFooterSwitchCard(
            key: const ValueKey<String>('auth-mode-login'),
            prompt: '已有账号？',
            actionLabel: '返回登录',
            compact: false,
            onTap: _showLoginFromFooter,
          ),
        ],
      ],
    );
  }

  Widget _buildResetPasswordPanel(
    AppServices services, {
    required bool compact,
  }) {
    final double fieldGap = compact ? AppSpacing.xs : AppSpacing.sm;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextButton.icon(
          onPressed: () => setState(() => _currentView = _AuthView.login),
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('返回登录'),
        ),
        SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
        _buildPhoneField(
          fieldKey: const ValueKey<String>('auth-reset-phone'),
          controller: _resetPhoneController,
          label: '手机号',
          onChanged: (_) {
            if (_resetChallenge != null) {
              setState(() => _resetChallenge = null);
            }
          },
        ),
        SizedBox(height: fieldGap),
        _buildCodeFieldWithAction(
          label: '短信验证码',
          fieldKey: const ValueKey<String>('auth-reset-code'),
          controller: _resetCodeController,
          actionKey: const ValueKey<String>('auth-reset-send'),
          actionLabel: '发送验证码',
          isLoading: _isSendingResetCode,
          onPressed: _isSendingResetCode || _isSubmitting
              ? null
              : () => _sendResetCode(services),
        ),
        SizedBox(height: fieldGap),
        _buildPasswordFieldGroup(
          fieldKey: const ValueKey<String>('auth-reset-password'),
          controller: _resetPasswordController,
          label: '新密码',
          hintText: '请输入新的登录密码',
          textInputAction: TextInputAction.next,
        ),
        SizedBox(height: fieldGap),
        _buildPasswordFieldGroup(
          fieldKey: const ValueKey<String>('auth-reset-password-confirm'),
          controller: _resetConfirmPasswordController,
          label: '确认新密码',
          hintText: '请再次输入新密码',
          textInputAction: TextInputAction.done,
        ),
        if (!compact) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          const _AuthInfoBox(
            icon: Icons.lock_reset_rounded,
            message: '仅支持短信找回。重置成功后会自动登录，并继续进入应用。',
          ),
          const SizedBox(height: AppSpacing.sm),
        ] else ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            '仅支持短信找回，重置成功后会自动登录。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        ListenableBuilder(
          listenable: _resetFormListenable,
          builder: (BuildContext context, Widget? child) {
            final bool canSubmit = !_isSubmitting;
            return PrimaryButton(
              key: const ValueKey<String>('auth-reset-submit'),
              label: _isSubmitting ? '重置中...' : '重置密码',
              foregroundColor: _authAccentDeep,
              onPressed: canSubmit
                  ? () => _submitResetPassword(services)
                  : null,
            );
          },
        ),
      ],
    );
  }

  Widget _buildStageIntro(bool isWide) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final List<_StageFeatureData> features = <_StageFeatureData>[
      const _StageFeatureData(
        icon: Icons.lock_open_rounded,
        title: '双登录方式',
        description: '支持手机号 + 密码，或手机号 + 短信验证码两种登录方式。',
      ),
      const _StageFeatureData(
        icon: Icons.mark_chat_unread_rounded,
        title: '短信注册',
        description: '新用户通过短信验证注册，同时完成登录密码设置。',
      ),
      const _StageFeatureData(
        icon: Icons.password_rounded,
        title: '短信找回',
        description: '忘记密码时，通过手机号和验证码安全重置即可。',
      ),
    ];

    return Container(
      padding: EdgeInsets.all(isWide ? AppSpacing.xxl : AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0x24FFFFFF), Color(0x10FFFFFF)],
        ),
        borderRadius: AppRadius.cardLarge,
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _AuthHeaderIcon(darkSurface: true),
          const SizedBox(height: AppSpacing.xl),
          Text(
            '舍眠',
            style: textTheme.displaySmall?.copyWith(
              color: AppColors.onDark,
              fontWeight: FontWeight.w800,
              height: 1.08,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '把登录、注册和密码找回统一成一套清晰稳定的前端入口。',
            style: textTheme.bodyLarge?.copyWith(
              color: const Color(0xEAF9F9FB),
              height: 1.6,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: const <Widget>[
              _StageChip(label: '手机号登录'),
              _StageChip(label: '短信注册'),
              _StageChip(label: '重置密码'),
            ],
          ),
          if (isWide) ...<Widget>[
            const SizedBox(height: AppSpacing.xxl),
            for (final _StageFeatureData feature in features) ...<Widget>[
              _StageFeatureTile(feature: feature),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        ],
      ),
    );
  }

  String _panelTitle() {
    switch (_currentView) {
      case _AuthView.login:
        return '登录舍眠';
      case _AuthView.register:
        return '免费注册';
      case _AuthView.resetPassword:
        return '重置密码';
    }
  }

  String _panelSubtitle({required bool compact}) {
    switch (_currentView) {
      case _AuthView.login:
        return compact ? '使用手机号继续登录。' : '使用手机号继续登录，支持密码登录与短信验证码登录。';
      case _AuthView.register:
        return compact ? '手机号注册并同步设置密码。' : '完成短信验证后即可创建账号，并同时设置登录密码。';
      case _AuthView.resetPassword:
        return compact ? '通过短信验证码设置新密码。' : '通过短信验证码设置新密码，成功后会自动登录。';
    }
  }

  String? _panelBadge() {
    switch (_currentView) {
      case _AuthView.login:
        return null;
      case _AuthView.register:
        return '短信验证注册';
      case _AuthView.resetPassword:
        return '设置新密码';
    }
  }

  Widget _buildPanelHeader({required bool compact}) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final String? badge = _panelBadge();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (_currentView != _AuthView.resetPassword && !compact) ...<Widget>[
          const _AuthHeaderIcon(),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (badge != null) ...<Widget>[
          _AuthBadge(label: badge),
          SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
        ],
        Text(
          _panelTitle(),
          style: (compact ? textTheme.headlineSmall : textTheme.headlineMedium)
              ?.copyWith(
                color: AppColors.textStrong,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          _panelSubtitle(compact: compact),
          style: textTheme.bodyMedium?.copyWith(
            color: AppColors.textMuted,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildAuthErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFC6C6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 18,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.redAccent,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthCard(AppServices services, {required bool compact}) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double cardPadding =
            constraints.maxWidth * (compact ? 0.055 : 0.072);
        final double cardRadius = constraints.maxWidth * 0.075;

        return Container(
          padding: EdgeInsets.all(cardPadding),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(cardRadius),
            border: Border.all(color: const Color(0xFFF0F3F8)),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x143B67A8),
                blurRadius: 42,
                offset: Offset(0, 22),
              ),
              BoxShadow(
                color: Color(0x0D3B67A8),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _buildPanelHeader(compact: compact),
              SizedBox(height: compact ? AppSpacing.md : AppSpacing.xl),
              if (_currentView == _AuthView.login)
                _buildLoginPanel(services, compact: compact),
              if (_currentView == _AuthView.register)
                _buildRegisterPanel(services, compact: compact),
              if (_currentView == _AuthView.resetPassword)
                _buildResetPasswordPanel(services, compact: compact),
              if (services.authRepository.lastAuthError
                  case final String error) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                _buildAuthErrorBanner(error),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    final ThemeData authTheme = _buildAuthTheme(context);
    final Size screenSize = MediaQuery.sizeOf(context);

    return Theme(
      data: authTheme,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[_stageStart, _stageMid, _stageEnd],
              stops: <double>[0, 0.55, 1],
            ),
          ),
          child: Stack(
            children: <Widget>[
              Positioned(
                top: -(screenSize.height * 0.12),
                right: -(screenSize.width * 0.08),
                child: _BlurOrb(
                  size: screenSize.width * 0.28,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
              ),
              Positioned(
                bottom: -(screenSize.height * 0.14),
                left: -(screenSize.width * 0.05),
                child: _BlurOrb(
                  size: screenSize.width * 0.24,
                  color: const Color(0xFFBFD3FF).withValues(alpha: 0.32),
                ),
              ),
              SafeArea(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final double aspectRatio =
                        constraints.maxWidth / constraints.maxHeight;
                    final bool isWide = aspectRatio > 1.45;
                    final bool isCompact = !isWide && aspectRatio > 1.15;
                    final bool useWideCompact =
                        isWide &&
                        (constraints.maxHeight / constraints.maxWidth) < 0.62;
                    final bool useCompactCard = isCompact || useWideCompact;
                    final double outerHorizontalPadding =
                        constraints.maxWidth * (isWide ? 0.03 : 0.05);
                    final double outerVerticalPadding =
                        constraints.maxHeight * (isWide ? 0.028 : 0.02);
                    final double shellPadding =
                        constraints.maxWidth * (isWide ? 0.018 : 0.03);
                    final double shellRadius = constraints.maxWidth * 0.03;
                    final double shellWidth =
                        (constraints.maxWidth - (outerHorizontalPadding * 2)) *
                        (isWide ? 0.92 : 1);
                    final Widget shell = Container(
                      padding: EdgeInsets.all(shellPadding),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(shellRadius),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      child: isWide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                Expanded(
                                  flex: 12,
                                  child: Padding(
                                    padding: EdgeInsets.all(
                                      constraints.maxWidth * 0.015,
                                    ),
                                    child: _buildStageIntro(!useWideCompact),
                                  ),
                                ),
                                SizedBox(width: constraints.maxWidth * 0.025),
                                Expanded(
                                  flex: 10,
                                  child: _buildAuthCard(
                                    services,
                                    compact: useCompactCard,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                _buildStageIntro(false),
                                SizedBox(height: constraints.maxHeight * 0.024),
                                _buildAuthCard(services, compact: false),
                              ],
                            ),
                    );

                    if (isCompact) {
                      return SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: outerHorizontalPadding,
                          vertical: outerVerticalPadding,
                        ),
                        child: Center(
                          child: SizedBox(
                            width:
                                (constraints.maxWidth -
                                    (outerHorizontalPadding * 2)) *
                                0.92,
                            child: _buildAuthCard(
                              services,
                              compact: useCompactCard,
                            ),
                          ),
                        ),
                      );
                    }

                    if (isWide) {
                      return Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: outerHorizontalPadding,
                          vertical: outerVerticalPadding,
                        ),
                        child: Center(
                          child: SizedBox(
                            width: shellWidth,
                            height:
                                constraints.maxHeight -
                                (outerVerticalPadding * 2),
                            child: shell,
                          ),
                        ),
                      );
                    }

                    return SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: outerHorizontalPadding,
                        vertical: outerVerticalPadding,
                      ),
                      child: Center(
                        child: SizedBox(width: shellWidth, child: shell),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthSegmentButton extends StatelessWidget {
  const _AuthSegmentButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? _PhoneAuthPageState._authAccent
                : _PhoneAuthPageState._authAccentSoft,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? _PhoneAuthPageState._authAccent
                  : const Color(0xFFD6E8F3),
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: _PhoneAuthPageState._authAccentDeep,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthHeaderIcon extends StatelessWidget {
  const _AuthHeaderIcon({this.darkSurface = false});

  final bool darkSurface;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: darkSurface
            ? Colors.white.withValues(alpha: 0.16)
            : _PhoneAuthPageState._authAccentDeep,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.bedtime_rounded, color: AppColors.onDark, size: 28),
    );
  }
}

class _AuthBadge extends StatelessWidget {
  const _AuthBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: _PhoneAuthPageState._authAccentSoft,
        borderRadius: AppRadius.pill,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: _PhoneAuthPageState._authAccentDeep,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AuthFieldGroup extends StatelessWidget {
  const _AuthFieldGroup({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _AuthInfoBox extends StatelessWidget {
  const _AuthInfoBox({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0EBF5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _PhoneAuthPageState._authAccentSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: _PhoneAuthPageState._authAccentDeep,
              size: 18,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthFooterSwitchCard extends StatelessWidget {
  const _AuthFooterSwitchCard({
    super.key,
    required this.prompt,
    required this.actionLabel,
    this.compact = false,
    required this.onTap,
  });

  final String prompt;
  final String actionLabel;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? AppSpacing.md : AppSpacing.lg,
            vertical: compact ? AppSpacing.sm : AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: compact ? Colors.transparent : const Color(0xFFF8FBFF),
            borderRadius: BorderRadius.circular(20),
            border: compact ? null : Border.all(color: const Color(0xFFE0EBF5)),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    children: <InlineSpan>[
                      TextSpan(text: prompt),
                      TextSpan(
                        text: actionLabel,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _PhoneAuthPageState._authAccentDeep,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                color: _PhoneAuthPageState._authAccentDeep,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: AppRadius.pill,
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.onDark,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StageFeatureData {
  const _StageFeatureData({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

class _StageFeatureTile extends StatelessWidget {
  const _StageFeatureTile({required this.feature});

  final _StageFeatureData feature;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(feature.icon, color: AppColors.onDark),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  feature.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.onDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  feature.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.84),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BlurOrb extends StatelessWidget {
  const _BlurOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

class _AuthPasswordField extends StatefulWidget {
  const _AuthPasswordField({
    required this.fieldKey,
    required this.controller,
    required this.labelText,
    required this.hintText,
    required this.textInputAction,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final TextInputAction textInputAction;

  @override
  State<_AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<_AuthPasswordField> {
  late final FocusNode _focusNode;
  late TextEditingController _localController;
  bool _obscureText = true;
  bool _isSyncingFromExternal = false;
  bool _isSyncingToExternal = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_handleFocusChange);
    _localController = TextEditingController(text: widget.controller.text)
      ..addListener(_syncToExternalController);
    widget.controller.addListener(_syncFromExternalController);
  }

  @override
  void didUpdateWidget(covariant _AuthPasswordField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncFromExternalController);
      widget.controller.addListener(_syncFromExternalController);
      _rebuildLocalController(widget.controller.text);
      if (mounted) {
        setState(() {});
      }
    }
    _syncFromExternalController();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFromExternalController);
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _localController.removeListener(_syncToExternalController);
    _localController.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) {
      _syncToExternalController();
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _obscureText = !_focusNode.hasFocus;
    });
  }

  void _rebuildLocalController(String text) {
    final TextEditingController previous = _localController;
    previous.removeListener(_syncToExternalController);
    _localController = TextEditingController.fromValue(
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      ),
    )..addListener(_syncToExternalController);
    previous.dispose();
  }

  void _syncFromExternalController() {
    if (_isSyncingToExternal) {
      return;
    }
    final String externalText = widget.controller.text;
    if (_localController.text == externalText) {
      return;
    }
    _isSyncingFromExternal = true;
    _rebuildLocalController(externalText);
    _isSyncingFromExternal = false;
    if (mounted) {
      setState(() {});
    }
  }

  void _syncToExternalController() {
    if (_isSyncingFromExternal) {
      return;
    }
    final String value = _localController.text;
    _isSyncingToExternal = true;
    if (widget.controller.text != value) {
      widget.controller.text = value;
    }
    _isSyncingToExternal = false;
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: widget.fieldKey,
      controller: _localController,
      focusNode: _focusNode,
      obscureText: _obscureText,
      textInputAction: widget.textInputAction,
      keyboardType: TextInputType.visiblePassword,
      enableSuggestions: false,
      autocorrect: false,
      enableIMEPersonalizedLearning: false,
      smartDashesType: SmartDashesType.disabled,
      smartQuotesType: SmartQuotesType.disabled,
      autofillHints: const <String>[],
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: Semantics(
          button: true,
          label: _obscureText ? '显示密码' : '隐藏密码',
          child: IconButton(
            onPressed: () {
              setState(() => _obscureText = !_obscureText);
            },
            icon: Icon(
              _obscureText
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
            ),
          ),
        ),
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
      backgroundColor: AppColors.surface,
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
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              alignment: Alignment.center,
              child: imageBytes == null || imageBytes.isEmpty
                  ? const Text('图片验证码加载失败')
                  : Image.memory(imageBytes, gaplessPlayback: true),
            ),
            const SizedBox(height: AppSpacing.sm),
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
              const SizedBox(height: AppSpacing.sm),
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
