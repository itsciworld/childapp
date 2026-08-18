import 'package:flexi_form_field/flexi_form_field.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil1/core/appColor/app_theme/app_gradient.dart';
import 'package:vigil1/core/appimages/app_images.dart';
import 'package:vigil1/core/config/legal_links.dart';
import 'package:vigil1/core/utils/validators.dart';
import 'package:vigil1/core/utils/app_toast.dart';
import 'package:vigil1/core/widgets/custom_button.dart';
import 'package:vigil1/core/widgets/in_app_web_view_page.dart';

import '../../../navigation_helper.dart';
import '../viewmodel/login_state.dart';
import '../viewmodel/login_viewmodel.dart';

/// Login screen. All API work is delegated to [LoginViewModel] via Riverpod;
/// this widget only renders state and forwards user input.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _acceptedTerms = false;

  static const Color _darkNavy = Color(0xFF1A237E);
  static const Color _accentGreen = Color(0xFF15BEB5);
  static const Color _accentBlue = Color(0xFF2BA0CC);

  FlexiFormTheme get _fieldTheme => FlexiFormTheme(
        primaryColor: _darkNavy,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        fillColor: Colors.grey.shade50,
        labelStyle: const TextStyle(color: Colors.black87),
        errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
      );

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onSignIn() {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_acceptedTerms) {
      showAppToast(
        context: context,
        title: 'Action required',
        subtitle: 'Please accept the Terms & Conditions and Privacy Policy',
        type: ToastType.warning,
      );
      return;
    }

    ref.read(loginViewModelProvider.notifier).login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenH = mq.size.height;
    final screenW = mq.size.width;
    final isSmall = screenH < 680;

    final hPad = screenW * 0.06;
    final logoBoxH = screenH * 0.30;
    final vGapSm = screenH * 0.015;
    final vGapMd = screenH * 0.022;

    // React to state changes for side effects (navigation / snackbars).
    ref.listen<LoginState>(loginViewModelProvider, (previous, next) {
      if (next.status == LoginStatus.success && next.response != null) {
        // login-and-send-otp returns no token; the verify-OTP screen needs the
        // email (the parent enters the emailed OTP there) and the password, so
        // its "Resend OTP" button can replay this same call.
        Nav.toVerifyOtp(
          context,
          _emailController.text.trim(),
          _passwordController.text,
        );
        ref.read(loginViewModelProvider.notifier).reset();
      } else if (next.status == LoginStatus.error &&
          next.errorMessage != null) {
        showAppToast(
          context: context,
          title: 'Login failed',
          subtitle: next.errorMessage!,
          type: ToastType.error,
        );
        ref.read(loginViewModelProvider.notifier).reset();
      }
    });

    final state = ref.watch(loginViewModelProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      _HeroSection(
                        height: logoBoxH,
                        darkNavy: _darkNavy,
                        accentBlue: _accentBlue,
                      ),
                      Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(30),
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: hPad),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: vGapMd * 1.2),
                                Text(
                                  'Welcome ',
                                  style: TextStyle(
                                    fontSize: isSmall ? 22 : 26,
                                    fontWeight: FontWeight.w800,
                                    color: _darkNavy,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Login to your account to continue',
                                  style: TextStyle(
                                    fontSize: isSmall ? 12 : 13.5,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                SizedBox(height: vGapMd),
                                const FieldLabel(text: 'Email', required: true),
                                const SizedBox(height: 6),
                                FlexiFormField(
                                  controller: _emailController,
                                  hint: 'Enter Parent Email',
                                  isEmail: true,
                                  isMandatory: true,
                                  denySpace: true,
                                  validator: Validators.email,
                                  keyboardType: TextInputType.emailAddress,
                                  maxLength: 254,
                                  fieldStyle: FlexiFieldStyle.outline,
                                  theme: _fieldTheme,
                                  prefixIcon: Icon(
                                    Icons.email_outlined,
                                    size: 20,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                                SizedBox(height: vGapSm),
                                const FieldLabel(
                                    text: 'Password', required: true),
                                const SizedBox(height: 6),
                                FlexiFormField(
                                  controller: _passwordController,
                                  hint: 'Enter Parent Password',
                                  obscureText: _obscurePassword,
                                  isMandatory: true,
                                  denySpace: true,
                                  validator: Validators.password,
                                  maxLength: 64,
                                  fieldStyle: FlexiFieldStyle.outline,
                                  theme: _fieldTheme,
                                  prefixIcon: Icon(
                                    Icons.lock_outline_rounded,
                                    size: 20,
                                    color: Colors.grey.shade500,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: Colors.grey.shade500,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                                SizedBox(height: vGapMd),
                                _TermsConsent(
                                  value: _acceptedTerms,
                                  accentColor: _accentBlue,
                                  onChanged: (v) =>
                                      setState(() => _acceptedTerms = v),
                                ),
                                SizedBox(height: vGapMd * 0.8),
                                CustomButton(
                                  label: 'Sign In',
                                  isLoading: state.isLoading,
                                  height: screenH * 0.055,
                                  gradient: _acceptedTerms
                                      ? AppGradients.primaryButton
                                      : const LinearGradient(
                                          colors: [
                                            Color(0xFFBDBDBD),
                                            Color(0xFFBDBDBD),
                                          ],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        ),
                                  onTap: (state.isLoading || !_acceptedTerms)
                                      ? null
                                      : _onSignIn,
                                ),
                                SizedBox(height: vGapMd),
                                // Row(
                                //   children: [
                                //     Expanded(
                                //         child: Divider(
                                //             color: Colors.grey.shade300)),
                                //     const Padding(
                                //       padding:
                                //           EdgeInsets.symmetric(horizontal: 12),
                                //       child: Text(
                                //         'OR',
                                //         style: TextStyle(
                                //           color: Color(0xFF9E9E9E),
                                //           fontSize: 13,
                                //         ),
                                //       ),
                                //     ),
                                //     Expanded(
                                //         child: Divider(
                                //             color: Colors.grey.shade300)),
                                //   ],
                                // ),
                                // SizedBox(height: vGapMd),
                                // Center(
                                //   child: GestureDetector(
                                //     onTap: state.isLoading
                                //         ? null
                                //         : () => Nav.toPairing(context,
                                //             _emailController.text.trim()),
                                //     child: const Row(
                                //       mainAxisSize: MainAxisSize.min,
                                //       children: [
                                //         Text(
                                //           'Have a pairing code? ',
                                //           style: TextStyle(
                                //             fontSize: 13.5,
                                //             color: Colors.black87,
                                //           ),
                                //         ),
                                //         Text(
                                //           'Pair device',
                                //           style: TextStyle(
                                //             fontSize: 13.5,
                                //             color: _accentGreen,
                                //             fontWeight: FontWeight.w700,
                                //           ),
                                //         ),
                                //       ],
                                //     ),
                                //   ),
                                // ),
                                SizedBox(height: vGapMd),
                              ],
                            ),
                          ),
                        ),
                      ),
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

// ---------------------------------------------------------------------------
// Hero / Logo Section
// ---------------------------------------------------------------------------

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.height,
    required this.darkNavy,
    required this.accentBlue,
  });

  final double height;
  final Color darkNavy;
  final Color accentBlue;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            bottom: -20,
            left: -30,
            child: _Blob(size: height * 0.6, color: const Color(0xFFEBF6FF)),
          ),
          Positioned(
            bottom: -10,
            right: -20,
            child: _Blob(
              size: height * 0.5,
              color: const Color(0xFFBAE4C8).withValues(alpha: 0.16),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: SizedBox(
                width: height * 0.99,
                height: height * 0.99,
                child: Padding(
                  padding: const EdgeInsets.all(1),
                  child: Image.asset(AppImages.logo, fit: BoxFit.contain),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

// ---------------------------------------------------------------------------
// Terms & privacy consent
// ---------------------------------------------------------------------------

/// Checkbox the parent must tick before signing in. The document names are
/// tappable and open inside the app rather than the system browser.
class _TermsConsent extends StatefulWidget {
  const _TermsConsent({
    required this.value,
    required this.onChanged,
    required this.accentColor,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Color accentColor;

  @override
  State<_TermsConsent> createState() => _TermsConsentState();
}

class _TermsConsentState extends State<_TermsConsent> {
  // Recognizers are long-lived and must be disposed, so they're built once
  // here instead of inside build().
  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;

  @override
  void initState() {
    super.initState();
    _termsTap = TapGestureRecognizer()
      ..onTap = () => InAppWebViewPage.open(
            context,
            url: LegalLinks.termsAndConditions,
            title: 'Terms and Conditions',
          );
    _privacyTap = TapGestureRecognizer()
      ..onTap = () => InAppWebViewPage.open(
            context,
            url: LegalLinks.privacyPolicy,
            title: 'Privacy Policy',
          );
  }

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  TextSpan _link(String text, TapGestureRecognizer recognizer) {
    return TextSpan(
      text: text,
      style: TextStyle(
        color: widget.accentColor,
        fontWeight: FontWeight.w700,
        decoration: TextDecoration.underline,
        decorationColor: widget.accentColor,
      ),
      recognizer: recognizer,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: widget.value,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            activeColor: widget.accentColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            onChanged: (v) => widget.onChanged(v ?? false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: Colors.grey.shade700,
                ),
                children: [
                  const TextSpan(text: 'I accept the '),
                  _link('Terms and Conditions', _termsTap),
                  const TextSpan(text: ' and '),
                  _link('Privacy Policy', _privacyTap),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Field label helper
// ---------------------------------------------------------------------------

class FieldLabel extends StatelessWidget {
  const FieldLabel({super.key, required this.text, this.required = false});
  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
        children: required
            ? const [
                TextSpan(
                  text: ' *',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ]
            : null,
      ),
    );
  }
}
