import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:vigil1/core/appimages/app_images.dart';
import 'package:vigil1/route_names.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  static const Color _darkBlue = Color(0xFF0B2C6B);
  static const Color _green = Color(0xFF46B72A);

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, RouteNames.terms);
      }
    });
  }

  double _fs(
    double screenW,
    double factor, {
    double min = 12,
    double max = 40,
  }) {
    return clampDouble(screenW * factor, min, max);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenH = mq.size.height;
    final screenW = mq.size.width;

    double clampH(
      double fraction, {
      required double minPx,
      required double maxPx,
    }) {
      return clampDouble(screenH * fraction, minPx, maxPx);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final h = constraints.maxHeight;

            return SizedBox(
              width: double.infinity,
              height: h,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: clampH(0.04, minPx: 16, maxPx: 48)),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: screenW * 0.06),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: 80,
                        maxHeight: clampH(0.28, minPx: 80, maxPx: 220),
                      ),
                      child: Image.asset(
                        AppImages.logo,
                        fit: BoxFit.contain,
                        width: double.infinity,
                      ),
                    ),
                  ),

                  SizedBox(height: clampH(0.025, minPx: 12, maxPx: 32)),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: 100,
                        maxHeight: clampH(0.26, minPx: 100, maxPx: 260),
                      ),
                      child: Image.asset(
                        AppImages.splashBanner,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    ),
                  ),

                  SizedBox(height: clampH(0.04, minPx: 16, maxPx: 48)),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: screenW * 0.08),
                    child: Column(
                      children: [
                        Text(
                          'Because Your Safety',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: _fs(screenW, 0.085, min: 22, max: 38),
                            fontWeight: FontWeight.w800,
                            color: _darkBlue,
                            height: 1.15,
                          ),
                        ),
                        SizedBox(height: clampH(0.006, minPx: 4, maxPx: 12)),
                        Text(
                          'Is Your Peace of Mind',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: _fs(screenW, 0.072, min: 18, max: 32),
                            fontWeight: FontWeight.w700,
                            color: _green,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Flexible(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: 24,
                        maxHeight: clampH(0.10, minPx: 24, maxPx: 80),
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),

                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: _green,
                    ),
                  ),

                  SizedBox(height: clampH(0.05, minPx: 20, maxPx: 56)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
