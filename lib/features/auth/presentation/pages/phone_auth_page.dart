import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/backend/cloudbase_auth_client.dart';
import 'package:sleep_dorm_app/core/data/repositories.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/primary_button.dart';

enum _AuthView { login, register, resetPassword }

enum _LoginMethod { password, smsCode }

class PhoneAuthPage extends StatefulWidget {
  const PhoneAuthPage({super.key});

  @override
  State<PhoneAuthPage> createState() => _PhoneAuthPageState();
}

class _PhoneAuthPageState extends State<PhoneAuthPage> {
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

  /// Incremented when the user clears a field so the [TextField] is remounted
  /// with a new key — this drops the IME connection so deleted characters
  /// cannot reappear as suggestions while the page stays open.
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

  Widget _buildModeSwitch() {
    return Row(
      children: <Widget>[
        Expanded(
          child: _ModePill(
            key: const ValueKey<String>('auth-mode-login'),
            label: '登录',
            selected: _currentView == _AuthView.login,
            onTap: () {
              setState(() => _currentView = _AuthView.login);
            },
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _ModePill(
            key: const ValueKey<String>('auth-mode-register'),
            label: '注册',
            selected: _currentView == _AuthView.register,
            onTap: () {
              setState(() => _currentView = _AuthView.register);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLoginMethodSwitch() {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        ChoiceChip(
          label: const Text('密码登录'),
          key: const ValueKey<String>('auth-login-method-password'),
          selected: _loginMethod == _LoginMethod.password,
          onSelected: (_) {
            setState(() => _loginMethod = _LoginMethod.password);
          },
        ),
        ChoiceChip(
          label: const Text('验证码登录'),
          key: const ValueKey<String>('auth-login-method-code'),
          selected: _loginMethod == _LoginMethod.smsCode,
          onSelected: (_) {
            setState(() => _loginMethod = _LoginMethod.smsCode);
          },
        ),
      ],
    );
  }

  Widget _buildPhoneField({
    required Key fieldKey,
    required TextEditingController controller,
    required ValueChanged<String>? onChanged,
    VoidCallback? onImeRemount,
  }) {
    return TextField(
      key: fieldKey,
      controller: controller,
      spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
      // TextInputType.number avoids the phone dialer keyboard which on many
      // Android devices shows recent-call / contact-history suggestions that
      // survive controller.clear().
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      autofillHints: const <String>[],
      enableSuggestions: false,
      autocorrect: false,
      enableIMEPersonalizedLearning: false,
      smartDashesType: SmartDashesType.disabled,
      smartQuotesType: SmartQuotesType.disabled,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[\d+\-\s]')),
      ],
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: '手机号',
        hintText: '请输入手机号',
        suffixIcon: _ClearFieldButton(
          controller: controller,
          semanticsLabel: '清除手机号',
          onCleared: onChanged,
          onImeRemount: onImeRemount,
        ),
      ),
    );
  }

  Widget _buildCodeField({
    required Key fieldKey,
    required TextEditingController controller,
    VoidCallback? onImeRemount,
  }) {
    return TextField(
      key: fieldKey,
      controller: controller,
      spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      enableSuggestions: false,
      autocorrect: false,
      enableIMEPersonalizedLearning: false,
      smartDashesType: SmartDashesType.disabled,
      smartQuotesType: SmartQuotesType.disabled,
      autofillHints: const <String>[],
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      decoration: InputDecoration(
        labelText: '验证码',
        hintText: '请输入短信验证码',
        suffixIcon: _ClearFieldButton(
          controller: controller,
          semanticsLabel: '清除验证码',
          onImeRemount: onImeRemount,
        ),
      ),
    );
  }

  Widget _buildLoginPanel(AppServices services) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '支持密码登录，也支持验证码快速登录。',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            height: 1.6,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _buildLoginMethodSwitch(),
        const SizedBox(height: AppSpacing.lg),
        _buildPhoneField(
          fieldKey: ValueKey<String>('auth-login-phone-$_loginPhoneRemount'),
          controller: _loginPhoneController,
          onChanged: (_) {
            if (_loginChallenge != null) {
              setState(() => _loginChallenge = null);
            }
          },
          onImeRemount: () => setState(() => _loginPhoneRemount++),
        ),
        const SizedBox(height: AppSpacing.md),
        if (_loginMethod == _LoginMethod.password) ...<Widget>[
          _AuthPasswordField(
            fieldKey: ValueKey<String>('auth-login-password-$_loginPasswordRemount'),
            controller: _loginPasswordController,
            labelText: '密码',
            hintText: '请输入登录密码',
            textInputAction: TextInputAction.done,
            onImeRemount: () => setState(() => _loginPasswordRemount++),
          ),
          const SizedBox(height: AppSpacing.sm),
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
          const SizedBox(height: AppSpacing.sm),
          ListenableBuilder(
            listenable: _loginPasswordFormListenable,
            builder: (BuildContext context, Widget? child) {
              final bool canSubmit = !_isSubmitting;
              return PrimaryButton(
                key: const ValueKey<String>('auth-login-password-submit'),
                label: _isSubmitting ? '登录中...' : '登录',
                onPressed: canSubmit
                    ? () => _submitLoginWithPassword(services)
                    : null,
              );
            },
          ),
        ] else ...<Widget>[
          _buildCodeField(
            fieldKey: ValueKey<String>('auth-login-code-$_loginCodeRemount'),
            controller: _loginCodeController,
            onImeRemount: () => setState(() => _loginCodeRemount++),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: PrimaryButton(
                  key: const ValueKey<String>('auth-login-code-send'),
                  label: _isSendingLoginCode ? '发送中...' : '发送验证码',
                  expand: false,
                  variant: PrimaryButtonVariant.soft,
                  onPressed: _isSendingLoginCode || _isSubmitting
                      ? null
                      : () => _sendLoginCode(services),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ListenableBuilder(
                  listenable: _loginCodeFormListenable,
                  builder: (BuildContext context, Widget? child) {
                    final bool canSubmit =
                        !_isSubmitting &&
                        _loginPhoneController.text.trim().isNotEmpty &&
                        _loginCodeController.text.trim().isNotEmpty;
                    return PrimaryButton(
                      key: const ValueKey<String>('auth-login-code-submit'),
                      label: _isSubmitting ? '登录中...' : '验证码登录',
                      expand: false,
                      onPressed: canSubmit
                          ? () => _submitLoginWithCode(services)
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildRegisterPanel(AppServices services) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '首次注册时会同时设置登录密码，之后可以直接用密码登录。',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            height: 1.6,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _buildPhoneField(
          fieldKey: ValueKey<String>('auth-register-phone-$_registerPhoneRemount'),
          controller: _registerPhoneController,
          onChanged: (_) {
            if (_registerChallenge != null) {
              setState(() => _registerChallenge = null);
            }
          },
          onImeRemount: () => setState(() => _registerPhoneRemount++),
        ),
        const SizedBox(height: AppSpacing.md),
        _buildCodeField(
          fieldKey: ValueKey<String>('auth-register-code-$_registerCodeRemount'),
          controller: _registerCodeController,
          onImeRemount: () => setState(() => _registerCodeRemount++),
        ),
        const SizedBox(height: AppSpacing.md),
        _AuthPasswordField(
          fieldKey:
              ValueKey<String>('auth-register-password-$_registerPasswordRemount'),
          controller: _registerPasswordController,
          labelText: '密码',
          hintText: '请设置登录密码',
          textInputAction: TextInputAction.next,
          onImeRemount: () => setState(() => _registerPasswordRemount++),
        ),
        const SizedBox(height: AppSpacing.md),
        _AuthPasswordField(
          fieldKey: ValueKey<String>(
            'auth-register-password-confirm-$_registerConfirmPasswordRemount',
          ),
          controller: _registerConfirmPasswordController,
          labelText: '确认密码',
          hintText: '请再次输入密码',
          textInputAction: TextInputAction.done,
          onImeRemount: () =>
              setState(() => _registerConfirmPasswordRemount++),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: <Widget>[
            Expanded(
              child: PrimaryButton(
                key: const ValueKey<String>('auth-register-send'),
                label: _isSendingRegisterCode ? '发送中...' : '发送验证码',
                expand: false,
                variant: PrimaryButtonVariant.soft,
                onPressed: _isSendingRegisterCode || _isSubmitting
                    ? null
                    : () => _sendRegisterCode(services),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: ListenableBuilder(
                listenable: _registerFormListenable,
                builder: (BuildContext context, Widget? child) {
                  final bool canSubmit = !_isSubmitting;
                  return PrimaryButton(
                    key: const ValueKey<String>('auth-register-submit'),
                    label: _isSubmitting ? '注册中...' : '注册并登录',
                    expand: false,
                    onPressed: canSubmit
                        ? () => _submitRegister(services)
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResetPasswordPanel(AppServices services) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            TextButton.icon(
              onPressed: () => setState(() => _currentView = _AuthView.login),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('返回登录'),
            ),
          ],
        ),
        Text(
          '通过验证码重置密码，成功后会直接登录。',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            height: 1.6,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _buildPhoneField(
          fieldKey: ValueKey<String>('auth-reset-phone-$_resetPhoneRemount'),
          controller: _resetPhoneController,
          onChanged: (_) {
            if (_resetChallenge != null) {
              setState(() => _resetChallenge = null);
            }
          },
          onImeRemount: () => setState(() => _resetPhoneRemount++),
        ),
        const SizedBox(height: AppSpacing.md),
        _buildCodeField(
          fieldKey: ValueKey<String>('auth-reset-code-$_resetCodeRemount'),
          controller: _resetCodeController,
          onImeRemount: () => setState(() => _resetCodeRemount++),
        ),
        const SizedBox(height: AppSpacing.md),
        _AuthPasswordField(
          fieldKey: ValueKey<String>('auth-reset-password-$_resetPasswordRemount'),
          controller: _resetPasswordController,
          labelText: '新密码',
          hintText: '请输入新的登录密码',
          textInputAction: TextInputAction.next,
          onImeRemount: () => setState(() => _resetPasswordRemount++),
        ),
        const SizedBox(height: AppSpacing.md),
        _AuthPasswordField(
          fieldKey: ValueKey<String>(
            'auth-reset-password-confirm-$_resetConfirmPasswordRemount',
          ),
          controller: _resetConfirmPasswordController,
          labelText: '确认新密码',
          hintText: '请再次输入新密码',
          textInputAction: TextInputAction.done,
          onImeRemount: () =>
              setState(() => _resetConfirmPasswordRemount++),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: <Widget>[
            Expanded(
              child: PrimaryButton(
                key: const ValueKey<String>('auth-reset-send'),
                label: _isSendingResetCode ? '发送中...' : '发送验证码',
                expand: false,
                variant: PrimaryButtonVariant.soft,
                onPressed: _isSendingResetCode || _isSubmitting
                    ? null
                    : () => _sendResetCode(services),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: ListenableBuilder(
                listenable: _resetFormListenable,
                builder: (BuildContext context, Widget? child) {
                  final bool canSubmit = !_isSubmitting;
                  return PrimaryButton(
                    key: const ValueKey<String>('auth-reset-submit'),
                    label: _isSubmitting ? '重置中...' : '重置密码',
                    expand: false,
                    onPressed: canSubmit
                        ? () => _submitResetPassword(services)
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AutofillGroup(
        onDisposeAction: AutofillContextAction.cancel,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _currentView == _AuthView.register
                            ? '创建账号'
                            : _currentView == _AuthView.resetPassword
                            ? '重置密码'
                            : '欢迎回来',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      if (_currentView != _AuthView.resetPassword) ...<Widget>[
                        _buildModeSwitch(),
                        const SizedBox(height: AppSpacing.xl),
                      ],
                      if (_currentView == _AuthView.login)
                        _buildLoginPanel(services),
                      if (_currentView == _AuthView.register)
                        _buildRegisterPanel(services),
                      if (_currentView == _AuthView.resetPassword)
                        _buildResetPasswordPanel(services),
                      if (services.authRepository.lastAuthError
                          case final String error)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.lg),
                          child: Text(
                            error,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.redAccent, height: 1.5),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({
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
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.textPrimary : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.textPrimary : AppColors.surfaceBorder,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: selected ? AppColors.onDark : AppColors.textPrimary,
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
    this.onImeRemount,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final TextInputAction textInputAction;
  final VoidCallback? onImeRemount;

  @override
  State<_AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<_AuthPasswordField> {
  late final FocusNode _focusNode;
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!mounted) {
      return;
    }
    // When the field loses focus we re-hide the password for privacy, but
    // never rebuild the controller — that would erase any text the user
    // has typed (and is the historical reason deletes could appear to undo
    // themselves when the parent triggered a setState elsewhere).
    setState(() {
      _obscureText = !_focusNode.hasFocus || _obscureText;
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: widget.fieldKey,
      controller: widget.controller,
      focusNode: _focusNode,
      obscureText: _obscureText,
      textInputAction: widget.textInputAction,
      keyboardType: TextInputType.visiblePassword,
      spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
      enableSuggestions: false,
      autocorrect: false,
      enableIMEPersonalizedLearning: false,
      smartDashesType: SmartDashesType.disabled,
      smartQuotesType: SmartQuotesType.disabled,
      autofillHints: const <String>[],
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _ClearFieldButton(
              controller: widget.controller,
              semanticsLabel: '清除${widget.labelText}',
              onImeRemount: widget.onImeRemount,
            ),
            Semantics(
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
          ],
        ),
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
          return const SizedBox(width: 0, height: 0);
        }
        return Semantics(
          button: true,
          label: semanticsLabel,
          child: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () {
              controller.clear();
              // Tell the platform to discard any remembered input for this
              // autofill context so the cleared value does not reappear via
              // IME candidate bar or system autofill on the next focus.
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
