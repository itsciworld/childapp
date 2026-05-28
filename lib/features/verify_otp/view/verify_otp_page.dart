import 'package:flexi_form_field/flexi_form_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil1/core/appColor/app_theme/app_gradient.dart';
import 'package:vigil1/core/appimages/app_images.dart';
import 'package:vigil1/core/widgets/custom_button.dart';

import '../../../navigation_helper.dart';
import '../../auth/view/login_page.dart' show FieldLabel;
import '../viewmodel/verify_otp_state.dart';
import '../viewmodel/verify_otp_viewmodel.dart';

/// Verify-OTP screen shown right after login.
///
/// The parent receives an OTP by email; here they enter that code along with
/// the child's name and age. All API work is delegated to [VerifyOtpViewModel]
/// via Riverpod — this widget only renders state and forwards user input.
///
/// The parent's email is passed via route arguments: `{'email': '...'}`.
class VerifyOtpPage extends ConsumerStatefulWidget {
  const VerifyOtpPage({super.key});

  @override
  ConsumerState<VerifyOtpPage> createState() => _VerifyOtpPageState();
}

class _VerifyOtpPageState extends ConsumerState<VerifyOtpPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();

  static const Color _darkNavy = Color(0xFF1A237E);
  static const Color _accentBlue = Color(0xFF2BA0CC);

  /// Parent's email, read once from the route arguments.
  String _email = '';

  FlexiFormTheme get _fieldTheme => FlexiFormTheme(
        primaryColor: _darkNavy,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        fillColor: Colors.grey.shade50,
        labelStyle: const TextStyle(color: Colors.black87),
        errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
      );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _email = args?['email'] as String? ?? '';
  }

  @override
  void dispose() {
    _otpController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _onSubmit() {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    ref.read(verifyOtpViewModelProvider.notifier).verify(
          email: _email,
          otp: _otpController.text,
          name: _nameController.text,
          ageText: _ageController.text,
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
    ref.listen<VerifyOtpState>(verifyOtpViewModelProvider, (previous, next) {
      if (next.status == VerifyOtpStatus.success && next.response != null) {
        final response = next.response!;
        Nav.toAllowPermission(
          context,
          response.childId!,
          response.token ?? '',
        );
        ref.read(verifyOtpViewModelProvider.notifier).reset();
      } else if (next.status == VerifyOtpStatus.error &&
          next.errorMessage != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(next.errorMessage!),
              backgroundColor: Colors.red,
            ),
          );
        ref.read(verifyOtpViewModelProvider.notifier).reset();
      }
    });

    final state = ref.watch(verifyOtpViewModelProvider);

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
                                  'Verify & Add Child',
                                  style: TextStyle(
                                    fontSize: isSmall ? 22 : 26,
                                    fontWeight: FontWeight.w800,
                                    color: _darkNavy,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _email.isEmpty
                                      ? 'Enter the OTP from your email and your child\'s details.'
                                      : 'Enter the OTP sent to $_email and your child\'s details.',
                                  style: TextStyle(
                                    fontSize: isSmall ? 12 : 13.5,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                SizedBox(height: vGapMd),
                                const FieldLabel(text: 'OTP', required: true),
                                const SizedBox(height: 6),
                                FlexiFormField(
                                  controller: _otpController,
                                  hint: '6-digit code from your email',
                                  isMandatory: true,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  maxLength: 6,
                                  fieldStyle: FlexiFieldStyle.outline,
                                  theme: _fieldTheme,
                                  prefixIcon: Icon(
                                    Icons.lock_clock_outlined,
                                    size: 20,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                                SizedBox(height: vGapSm),
                                const FieldLabel(
                                    text: 'Child’s Name', required: true),
                                const SizedBox(height: 6),
                                FlexiFormField(
                                  controller: _nameController,
                                  hint: 'Enter child’s name',
                                  isMandatory: true,
                                  fieldStyle: FlexiFieldStyle.outline,
                                  theme: _fieldTheme,
                                  prefixIcon: Icon(
                                    Icons.person_outline,
                                    size: 20,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                                SizedBox(height: vGapSm),
                                const FieldLabel(
                                    text: 'Child’s Age', required: true),
                                const SizedBox(height: 6),
                                FlexiFormField(
                                  controller: _ageController,
                                  hint: 'Enter child’s age',
                                  isMandatory: true,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  maxLength: 2,
                                  fieldStyle: FlexiFieldStyle.outline,
                                  theme: _fieldTheme,
                                  prefixIcon: Icon(
                                    Icons.cake_outlined,
                                    size: 20,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                                SizedBox(height: vGapMd * 1.4),
                                CustomButton(
                                  label: 'Submit',
                                  isLoading: state.isLoading,
                                  height: screenH * 0.055,
                                  gradient: AppGradients.primaryButton,
                                  onTap: state.isLoading ? null : _onSubmit,
                                ),
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
