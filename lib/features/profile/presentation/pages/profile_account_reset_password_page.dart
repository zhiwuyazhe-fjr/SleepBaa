import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sleep_dorm_app/app/theme/app_semantic_colors.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/notifications/passive_toast_notification.dart';
import 'package:sleep_dorm_app/core/widgets/app_detail_page_header.dart';
import 'package:sleep_dorm_app/core/widgets/primary_button.dart';

enum _AccountResetStep { verify, password, success }

class AccountResetPasswordPage extends StatefulWidget {
  const AccountResetPasswordPage({super.key});

  @override
  State<AccountResetPasswordPage> createState() =>
      _AccountResetPasswordPageState();
}

class _AccountResetPasswordPageState extends State<AccountResetPasswordPage> {
  static const double _designWidth = 390;
  static const Color _accentBlue = Color(0xFF90DDF2);
  static const Color _accentBlueDeep = Color(0xFF004F5D);
  static const Color _accentBluePressed = Color(0xFF7CCDE5);
  static const Color _accentBlueDisabled = Color(0xFFCFE4EB);
  static const Color _accentBlueDisabledText = Color(0xFF6F8890);
  static const Color _codeButtonBackground = Color(0xFFBFE6F0);
  static const Color _codeButtonPressed = Color(0xFFA8D9E6);
  static const Color _codeButtonForeground = Color(0xFF004F5D);
  static const Color _darkCodeButtonBackground = Color(0xFF2C5C69);
  static const Color _darkCodeButtonPressed = Color(0xFF347084);
  static const Color _darkCodeButtonForeground = Color(0xFFEAFBFF);
  static const Color _successBlue = Color(0xFF4EA8C2);
  static const Color _buttonShadow = Color(0x4A90DDF2);

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  late final Listenable _verifyFormListenable;
  late final Listenable _passwordFormListenable;

  PhoneVerificationChallenge? _challenge;
  PhoneVerificationProof? _proof;
  bool _hasBoundInitialPhone = false;
  bool _isSendingCode = false;
  bool _isVerifyingCode = false;
  bool _isSubmitting = false;
  _AccountResetStep _step = _AccountResetStep.verify;

  int _phoneRemount = 0;
  int _codeRemount = 0;
  int _passwordRemount = 0;
  int _confirmPasswordRemount = 0;

  @override
  void initState() {
    super.initState();
    _verifyFormListenable = Listenable.merge(<Listenable>[
      _phoneController,
      _codeController,
    ]);
    _passwordFormListenable = Listenable.merge(<Listenable>[
      _passwordController,
      _confirmPasswordController,
    ]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_phoneController.text.isNotEmpty) {
      return;
    }
    final AppServices services = context.appServices;
    final String phone = _displayedPhone(
      services.profileFacade.currentUser,
      services.authRepository.currentUser.phoneNumber,
    );
    if (phone.isEmpty) {
      return;
    }
    _phoneController.text = phone;
    _hasBoundInitialPhone = true;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _showMessage(String message) {
    return notifyPassiveToast(context, message: message);
  }

  bool _dismissKeyboardIfNeeded() {
    if (MediaQuery.viewInsetsOf(context).bottom <= 0) {
      return false;
    }
    final FocusNode? focusedNode = FocusManager.instance.primaryFocus;
    if (focusedNode == null) {
      return false;
    }
    focusedNode.unfocus();
    return true;
  }

  void _handleBack() {
    if (_dismissKeyboardIfNeeded()) {
      return;
    }
    switch (_step) {
      case _AccountResetStep.verify:
        Navigator.of(context).maybePop();
      case _AccountResetStep.password:
        setState(() {
          _step = _AccountResetStep.verify;
          _passwordController.clear();
          _confirmPasswordController.clear();
        });
      case _AccountResetStep.success:
        setState(() => _step = _AccountResetStep.password);
    }
  }

  String? _validatePhone(String value) {
    final String trimmed = value.trim();
    final RegExp mainlandPhonePattern = RegExp(r'^(?:\+?86)?1\d{10}$');
    if (trimmed.isEmpty) {
      return '请输入手机号。';
    }
    if (!mainlandPhonePattern.hasMatch(trimmed)) {
      return '请输入正确的大陆手机号。';
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

  bool get _canSubmitPassword {
    return _validatePassword(_passwordController.text) == null &&
        _passwordController.text == _confirmPasswordController.text;
  }

  Future<void> _sendCode(AppServices services) async {
    final String? phoneError = _validatePhone(_phoneController.text);
    if (phoneError != null) {
      await _showMessage(phoneError);
      return;
    }

    setState(() => _isSendingCode = true);
    try {
      final PhoneVerificationChallenge challenge = await services.profileFacade
          .sendPhoneVerificationCode(
            _phoneController.text.trim(),
            target: PhoneVerificationTarget.existingUser,
          );
      if (!mounted) {
        return;
      }
      if (!challenge.isExistingUser) {
        await _showMessage('未找到该手机号，请先确认当前账号绑定信息。');
        return;
      }
      setState(() {
        _challenge = challenge;
        _proof = null;
      });
      await _showMessage('验证码已发送，请留意短信。');
    } catch (error) {
      if (!mounted) {
        return;
      }
      await _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSendingCode = false);
      }
    }
  }

  Future<void> _verifyCode(AppServices services) async {
    final PhoneVerificationChallenge? challenge = _challenge;
    if (challenge == null) {
      await _showMessage('请先发送验证码。');
      return;
    }
    final String? codeError = _validateCode(_codeController.text);
    if (codeError != null) {
      await _showMessage(codeError);
      return;
    }

    setState(() => _isVerifyingCode = true);
    try {
      final PhoneVerificationProof proof = await services.profileFacade
          .verifyPhoneCode(
            verificationId: challenge.verificationId,
            code: _codeController.text.trim(),
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _proof = proof;
        _step = _AccountResetStep.password;
      });
      await _showMessage('验证通过，请设置新密码。');
    } catch (error) {
      if (!mounted) {
        return;
      }
      await _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isVerifyingCode = false);
      }
    }
  }

  Future<void> _submitReset(AppServices services) async {
    final PhoneVerificationProof? proof = _proof;
    if (proof == null) {
      await _showMessage('请先完成验证码验证。');
      return;
    }
    final String? passwordError = _validatePassword(_passwordController.text);
    if (passwordError != null) {
      await _showMessage(passwordError);
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      await _showMessage('两次输入的新密码不一致。');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await services.profileFacade.resetPasswordWithVerificationToken(
        phoneNumber: _phoneController.text.trim(),
        verificationToken: proof.verificationToken,
        newPassword: _passwordController.text,
      );
      if (!mounted) {
        return;
      }
      setState(() => _step = _AccountResetStep.success);
      await _showMessage('密码已更新。');
    } catch (error) {
      if (!mounted) {
        return;
      }
      await _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

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

  Widget _buildVerifyPage(
    BuildContext context,
    AppServices services,
    double unit,
  ) {
    return _AccountPencilSplitPage(
      unit: unit,
      bodyChildren: <Widget>[
        AppDetailPageHeader(title: '找回密码', onBack: _handleBack),
        SizedBox(height: 10 * unit),
        Text(
          _hasBoundInitialPhone
              ? '当前优先使用本账号已绑定手机号完成验证。'
              : '请输入当前账号已注册的手机号并完成验证码验证。',
          style: _textStyle(
            context,
            size: 15 * unit,
            weight: FontWeight.w500,
            color: context.appColors.textSecondary,
            height: 1.5,
          ),
        ),
        SizedBox(height: 20 * unit),
        _AccountPencilInputField(
          fieldKey: ValueKey<String>('account-reset-phone-$_phoneRemount'),
          label: '手机号',
          hintText: '请输入已绑定手机号',
          controller: _phoneController,
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
            if (_challenge != null) {
              setState(() => _challenge = null);
            }
          },
          onImeRemount: () => setState(() => _phoneRemount += 1),
        ),
        SizedBox(height: 12 * unit),
        _buildCodeFieldRow(
          context,
          label: '短信验证码',
          hintText: '请输入验证码',
          controller: _codeController,
          fieldKey: ValueKey<String>('account-reset-code-$_codeRemount'),
          actionKey: const ValueKey<String>('account-reset-send'),
          buttonLabel: _isSendingCode ? '发送中...' : '发送验证码',
          onPressed: _isSendingCode ? null : () => _sendCode(services),
          unit: unit,
          onImeRemount: () => setState(() => _codeRemount += 1),
        ),
        SizedBox(height: 12 * unit),
        ListenableBuilder(
          listenable: _verifyFormListenable,
          builder: (BuildContext context, Widget? child) {
            return _AccountPencilFilledButton(
              buttonKey: const ValueKey<String>('account-reset-verify'),
              label: '验证并继续',
              loadingLabel: '验证中...',
              isLoading: _isVerifyingCode,
              unit: unit,
              onPressed: _isVerifyingCode ? null : () => _verifyCode(services),
            );
          },
        ),
      ],
      footer: _AccountPencilSupportCard(
        title: '无法接收验证码？',
        subtitle: '联系客服协助处理',
        unit: unit,
      ),
    );
  }

  Widget _buildPasswordPage(
    BuildContext context,
    AppServices services,
    double unit,
  ) {
    return _AccountPencilSplitPage(
      unit: unit,
      bodyChildren: <Widget>[
        AppDetailPageHeader(title: '重置密码', onBack: _handleBack),
        SizedBox(height: 10 * unit),
        Text(
          '短信验证已通过，现在请设置一个新的登录密码。',
          style: _textStyle(
            context,
            size: 15 * unit,
            weight: FontWeight.w500,
            color: context.appColors.textSecondary,
            height: 1.5,
          ),
        ),
        SizedBox(height: 20 * unit),
        _AccountPencilInputField(
          fieldKey: ValueKey<String>(
            'account-reset-password-$_passwordRemount',
          ),
          label: '新密码',
          hintText: '请输入新的登录密码',
          controller: _passwordController,
          icon: Icons.lock_outline_rounded,
          textInputAction: TextInputAction.next,
          obscureText: true,
          scaleUnit: unit,
          clearSemanticsLabel: '清除新密码',
          onImeRemount: () => setState(() => _passwordRemount += 1),
        ),
        SizedBox(height: 12 * unit),
        _AccountPencilInputField(
          fieldKey: ValueKey<String>(
            'account-reset-password-confirm-$_confirmPasswordRemount',
          ),
          label: '确认新密码',
          hintText: '再次输入新密码',
          controller: _confirmPasswordController,
          icon: Icons.lock_outline_rounded,
          textInputAction: TextInputAction.done,
          obscureText: true,
          scaleUnit: unit,
          clearSemanticsLabel: '清除确认新密码',
          onImeRemount: () => setState(() => _confirmPasswordRemount += 1),
        ),
        SizedBox(height: 12 * unit),
        ListenableBuilder(
          listenable: _passwordFormListenable,
          builder: (BuildContext context, Widget? child) {
            return _AccountPencilFilledButton(
              buttonKey: const ValueKey<String>('account-reset-submit'),
              label: '确认重置密码',
              loadingLabel: '重置中...',
              isLoading: _isSubmitting,
              unit: unit,
              onPressed: _isSubmitting || !_canSubmitPassword
                  ? null
                  : () => _submitReset(services),
            );
          },
        ),
      ],
      footer: _AccountPencilSupportCard(
        title: '无法接收验证码？',
        subtitle: '联系客服协助处理',
        unit: unit,
      ),
    );
  }

  Widget _buildSuccessPage(BuildContext context, double unit) {
    final AppSemanticColors appColors = context.appColors;
    return _AccountPencilSplitPage(
      unit: unit,
      bodyChildren: <Widget>[
        Text(
          '密码已重置',
          style: _textStyle(
            context,
            size: 32 * unit,
            weight: FontWeight.w700,
            color: context.appColors.textPrimary,
          ),
        ),
        SizedBox(height: 12 * unit),
        Text(
          '当前账号已经完成密码更新，现在可以返回账号管理继续其他设置。',
          style: _textStyle(
            context,
            size: 15 * unit,
            weight: FontWeight.w500,
            color: context.appColors.textSecondary,
            height: 1.5,
          ),
        ),
        SizedBox(height: 24 * unit),
        Container(
          height: 180 * unit,
          width: double.infinity,
          decoration: BoxDecoration(
            color: context.appColors.surfaceMuted,
            borderRadius: BorderRadius.circular(28 * unit),
            border: Border.all(color: context.appColors.borderSubtle),
          ),
          child: Center(
            child: Container(
              width: 76 * unit,
              height: 76 * unit,
              decoration: const BoxDecoration(
                color: _successBlue,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_rounded,
                size: 42 * unit,
                color: appColors.textOnAccent,
              ),
            ),
          ),
        ),
        SizedBox(height: 24 * unit),
        _AccountPencilFilledButton(
          buttonKey: const ValueKey<String>('account-reset-success-back'),
          label: '返回账号管理',
          unit: unit,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      footer: const SizedBox.shrink(),
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
            color: context.appColors.textSecondary,
          ),
        ),
        SizedBox(height: 6 * unit),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              flex: 2,
              child: _AccountPencilBareInput(
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
              child: _AccountPencilSoftButton(
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
    final AppServices services = context.appServices;
    final AppSemanticColors appColors = context.appColors;
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final bool hasVisibleKeyboard = keyboardInset > 0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: appColors.pageBackground,
        resizeToAvoidBottomInset: false,
        body: PopScope<void>(
          canPop: _step == _AccountResetStep.verify && !hasVisibleKeyboard,
          onPopInvokedWithResult: (bool didPop, void _) {
            if (!didPop) {
              _handleBack();
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

                final Widget content = switch (_step) {
                  _AccountResetStep.verify => _buildVerifyPage(
                    context,
                    services,
                    unit,
                  ),
                  _AccountResetStep.password => _buildPasswordPage(
                    context,
                    services,
                    unit,
                  ),
                  _AccountResetStep.success => _buildSuccessPage(context, unit),
                };

                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalInset,
                    verticalInset,
                    horizontalInset,
                    verticalInset + keyboardInset,
                  ),
                  physics: const ClampingScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: minPageHeight),
                    child: IntrinsicHeight(child: content),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountPencilSplitPage extends StatelessWidget {
  const _AccountPencilSplitPage({
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

class _AccountPencilInputField extends StatelessWidget {
  const _AccountPencilInputField({
    required this.fieldKey,
    required this.label,
    required this.hintText,
    required this.controller,
    required this.icon,
    required this.scaleUnit,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
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
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final String? clearSemanticsLabel;
  final VoidCallback? onImeRemount;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            fontSize: 13 * scaleUnit,
            fontWeight: FontWeight.w600,
            color: appColors.textSecondary,
          ),
        ),
        SizedBox(height: 6 * scaleUnit),
        _AccountPencilBareInput(
          fieldKey: fieldKey,
          hintText: hintText,
          controller: controller,
          icon: icon,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          obscureText: obscureText,
          scaleUnit: scaleUnit,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          clearSemanticsLabel: clearSemanticsLabel,
          onImeRemount: onImeRemount,
        ),
      ],
    );
  }
}

class _AccountPencilBareInput extends StatefulWidget {
  const _AccountPencilBareInput({
    required this.fieldKey,
    required this.hintText,
    required this.controller,
    required this.icon,
    required this.scaleUnit,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
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
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final String? clearSemanticsLabel;
  final VoidCallback? onImeRemount;

  @override
  State<_AccountPencilBareInput> createState() =>
      _AccountPencilBareInputState();
}

class _AccountPencilBareInputState extends State<_AccountPencilBareInput> {
  late bool _obscured;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText;
  }

  @override
  void didUpdateWidget(covariant _AccountPencilBareInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.obscureText != widget.obscureText) {
      _obscured = widget.obscureText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    final Color borderColor = appColors.borderSubtle;
    final double borderWidth = widget.scaleUnit;
    final bool showsClearButton = widget.clearSemanticsLabel != null;
    final Widget? suffixIcon = showsClearButton || widget.obscureText
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (showsClearButton)
                _AccountClearFieldButton(
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
                    color: appColors.textSecondary,
                  ),
                ),
            ],
          )
        : null;

    return Container(
      height: 56 * widget.scaleUnit,
      decoration: BoxDecoration(
        color: appColors.surface,
        borderRadius: BorderRadius.circular(18 * widget.scaleUnit),
        border: Border.all(color: borderColor, width: math.max(1, borderWidth)),
        boxShadow: const <BoxShadow>[],
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
          color: appColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
            fontSize: 14 * widget.scaleUnit,
            fontWeight: widget.obscureText ? FontWeight.w600 : FontWeight.w500,
            color: widget.obscureText
                ? appColors.textPrimary
                : appColors.textSecondary.withAlpha(150),
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 18 * widget.scaleUnit),
          prefixIcon: Icon(
            widget.icon,
            size: 20 * widget.scaleUnit,
            color: appColors.textSecondary,
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

class _AccountPencilFilledButton extends StatelessWidget {
  const _AccountPencilFilledButton({
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
              color: _AccountResetPasswordPageState._buttonShadow,
              blurRadius: 30 * unit,
              offset: Offset(0, 16 * unit),
            ),
          ],
        ),
        child: PrimaryButton(
          label: label,
          loadingLabel: resolvedLabel,
          isLoading: isLoading,
          onPressed: onPressed,
          backgroundColor: _AccountResetPasswordPageState._accentBlue,
          pressedBackgroundColor:
              _AccountResetPasswordPageState._accentBluePressed,
          disabledBackgroundColor:
              _AccountResetPasswordPageState._accentBlueDisabled,
          foregroundColor: _AccountResetPasswordPageState._accentBlueDeep,
          disabledForegroundColor:
              _AccountResetPasswordPageState._accentBlueDisabledText,
          borderRadius: BorderRadius.circular(18 * unit),
          elevation: 0,
          shadowColor: Colors.transparent,
          textStyle: Theme.of(context).textTheme.bodyLarge!.copyWith(
            fontSize: 16 * unit,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _AccountPencilSoftButton extends StatelessWidget {
  const _AccountPencilSoftButton({
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
    final AppSemanticColors appColors = context.appColors;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color background = dark
        ? _AccountResetPasswordPageState._darkCodeButtonBackground
        : _AccountResetPasswordPageState._codeButtonBackground;
    final Color pressed = dark
        ? _AccountResetPasswordPageState._darkCodeButtonPressed
        : _AccountResetPasswordPageState._codeButtonPressed;
    final Color foreground = dark
        ? _AccountResetPasswordPageState._darkCodeButtonForeground
        : _AccountResetPasswordPageState._codeButtonForeground;
    return SizedBox(
      key: buttonKey,
      height: 56 * unit,
      child: PrimaryButton(
        label: label,
        onPressed: onPressed,
        size: PrimaryButtonSize.compact,
        backgroundColor: background,
        pressedBackgroundColor: pressed,
        disabledBackgroundColor: appColors.surfaceMuted,
        foregroundColor: foreground,
        disabledForegroundColor: appColors.textSecondary,
        borderRadius: BorderRadius.circular(18 * unit),
        elevation: 0,
        shadowColor: Colors.transparent,
        textStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
          fontSize: 13 * unit,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AccountPencilSupportCard extends StatelessWidget {
  const _AccountPencilSupportCard({
    required this.title,
    required this.subtitle,
    required this.unit,
  });

  final String title;
  final String subtitle;
  final double unit;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors appColors = context.appColors;
    return Container(
      height: 92 * unit,
      width: double.infinity,
      decoration: BoxDecoration(
        color: appColors.surfaceMuted,
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
              color: appColors.textSecondary,
            ),
          ),
          SizedBox(height: 8 * unit),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontSize: 14 * unit,
              fontWeight: FontWeight.w700,
              color: appColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountClearFieldButton extends StatelessWidget {
  const _AccountClearFieldButton({
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

String _displayedPhone(UserProfile profile, String? authPhoneNumber) {
  final List<String> candidates = <String>[
    if (profile.phoneNumber case final String phoneNumber) phoneNumber,
    if (authPhoneNumber case final String phoneNumber) phoneNumber,
  ];
  for (final String item in candidates) {
    final String trimmed = item.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return '';
}
