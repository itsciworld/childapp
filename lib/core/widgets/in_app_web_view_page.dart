import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Simple in-app browser used for legal documents (terms, privacy policy).
///
/// Pushed as a normal route so the user stays inside the app instead of
/// being handed off to the system browser.
class InAppWebViewPage extends StatefulWidget {
  const InAppWebViewPage({
    super.key,
    required this.url,
    required this.title,
  });

  final String url;
  final String title;

  /// Convenience helper so callers don't have to build the route themselves.
  static Future<void> open(
    BuildContext context, {
    required String url,
    required String title,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InAppWebViewPage(url: url, title: title),
      ),
    );
  }

  @override
  State<InAppWebViewPage> createState() => _InAppWebViewPageState();
}

class _InAppWebViewPageState extends State<InAppWebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _error;

  static const Color _darkNavy = Color(0xFF1A237E);

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _isLoading = true;
              _error = null;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            // Sub-resource failures (images, trackers) shouldn't blank the page.
            if (error.isForMainFrame == false) return;
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _error = 'Unable to load the page. Please check your connection.';
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  void _reload() {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    _controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _darkNavy,
        elevation: 0.5,
        title: Text(
          widget.title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _darkNavy,
          ),
        ),
      ),
      body: Stack(
        children: [
          if (_error == null) WebViewWidget(controller: _controller),
          if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi_off_rounded,
                        size: 40, color: Colors.grey.shade500),
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 12),
                    TextButton(onPressed: _reload, child: const Text('Retry')),
                  ],
                ),
              ),
            ),
          if (_isLoading && _error == null)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
