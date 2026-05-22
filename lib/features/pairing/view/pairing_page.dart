import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../navigation_helper.dart';
import '../viewmodel/pairing_state.dart';
import '../viewmodel/pairing_viewmodel.dart';

/// Pairing screen — an alternative to the verify-OTP flow.
///
/// The parent generates a 6-digit pairing code on their Vigil app; the parent
/// enters it here to link this child device. All API work is delegated to
/// [PairingViewModel] via Riverpod.
///
/// The parent's email is passed via route arguments: `{'email': '...'}`.
class PairingPage extends ConsumerStatefulWidget {
  const PairingPage({super.key});

  @override
  ConsumerState<PairingPage> createState() => _PairingPageState();
}

class _PairingPageState extends ConsumerState<PairingPage> {
  static const int _codeLength = 6;

  final List<TextEditingController> _controllers =
      List.generate(_codeLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_codeLength, (_) => FocusNode());

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
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  bool get _isCodeComplete => _controllers.every((c) => c.text.isNotEmpty);

  void _onSubmit() {
    FocusScope.of(context).unfocus();
    ref.read(pairingViewModelProvider.notifier).verify(
          email: _email,
          code: _code,
        );
  }

  @override
  Widget build(BuildContext context) {
    // React to state changes for side effects (navigation / snackbars).
    ref.listen<PairingState>(pairingViewModelProvider, (previous, next) {
      if (next.status == PairingStatus.success) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                next.response?.message ?? 'Pairing code verified successfully',
              ),
              backgroundColor: Colors.green,
            ),
          );
        // The pairing API returns no childId/token — pass empty placeholders.
        Nav.toAllowPermission(context, '', '');
        ref.read(pairingViewModelProvider.notifier).reset();
      } else if (next.status == PairingStatus.error &&
          next.errorMessage != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(next.errorMessage!),
              backgroundColor: Colors.red,
            ),
          );
        ref.read(pairingViewModelProvider.notifier).reset();
      }
    });

    final state = ref.watch(pairingViewModelProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios),
              ),
            ),
            const Text(
              'Link Parents Device',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            const Text(
              'Enter Code',
              style: TextStyle(
                color: Colors.blue,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'A unique 6-digit code is displayed on your Vigil1 Parental App. \n Enter the code to pair the two devices.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            _buildCodeInput(),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (!_isCodeComplete || state.isLoading)
                      ? null
                      : _onSubmit,
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
                          'Continue',
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

  Widget _buildCodeInput() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(_codeLength, _buildCodeDigitField),
    );
  }

  Widget _buildCodeDigitField(int index) {
    return SizedBox(
      width: 40,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(fontSize: 24),
        decoration: const InputDecoration(
          counterText: '',
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.grey),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.blue),
          ),
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < _codeLength - 1) {
            _focusNodes[index + 1].requestFocus();
          }
          if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
          setState(() {});
        },
      ),
    );
  }
}
