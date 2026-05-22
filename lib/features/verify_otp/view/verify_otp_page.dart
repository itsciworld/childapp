import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../navigation_helper.dart';
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
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();

  /// Parent's email, read once from the route arguments.
  String _email = '';

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
    ref.read(verifyOtpViewModelProvider.notifier).verify(
          email: _email,
          otp: _otpController.text,
          name: _nameController.text,
          ageText: _ageController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 60),
            const Text(
              'Verify & Add Child',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _email.isEmpty
                  ? 'Enter the OTP from your email and your child\'s details.'
                  : 'Enter the OTP sent to $_email and your child\'s details.',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'OTP',
                hintText: '6-digit code from your email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Child’s Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Child’s Age',
                border: OutlineInputBorder(),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: state.isLoading ? null : _onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    disabledBackgroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: state.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Submit',
                          style:
                              TextStyle(color: Colors.white, fontSize: 18),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
