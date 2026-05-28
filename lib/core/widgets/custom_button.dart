import 'package:flutter/material.dart';
import 'package:vigil1/core/appColor/app_theme/app_gradient.dart';

class CustomButton extends StatelessWidget {
  const CustomButton({
    super.key,
    required this.onTap,
    required this.isLoading,
    this.label = 'Login',
    this.height = 56.0,
    this.width = double.infinity,
    this.borderRadius = 14.0,
    this.gradient,
    this.textStyle,
    this.arrowIcon = true,
  });

  final VoidCallback? onTap;
  final bool isLoading;
  final String label;
  final double height;
  final double width;
  final double borderRadius;

  /// Gradient to use. Defaults to [AppGradients.primaryButton] when null.
  final LinearGradient? gradient;

  final TextStyle? textStyle;
  final bool arrowIcon;

  LinearGradient get _resolvedGradient => isLoading
      ? AppGradients.disabled
      : (gradient ?? AppGradients.primaryButton);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: _resolvedGradient,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: isLoading
              ? []
              : [
                  BoxShadow(
                    color: AppGradients.shadowColor(
                      gradient ?? AppGradients.primaryButton,
                    ),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: isLoading
            ? const Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: textStyle ??
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                  ),
                  if (arrowIcon) ...[
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
