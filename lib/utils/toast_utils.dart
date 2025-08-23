import 'package:flutter/material.dart';

class ToastUtils {
  static final Color _greyColor = Colors.grey[800]!.withOpacity(0.7);

  static void showSuccess(String message, {BuildContext? context}) {
    _showToast(message, _greyColor, context: context);
  }

  static void showError(String message, {BuildContext? context}) {
    _showToast(message, Colors.red[700]!.withOpacity(0.8), context: context);
  }

  static void showInfo(String message, {BuildContext? context}) {
    _showToast(message, _greyColor, context: context);
  }

  static void showWarning(String message, {BuildContext? context}) {
    _showToast(message, _greyColor, context: context);
  }

  static void show(String message, {BuildContext? context}) {
    _showToast(message, _greyColor, context: context);
  }

  static void _showToast(String message, Color backgroundColor, {BuildContext? context}) {
    final targetContext = context ?? NavigationService.navigatorKey.currentContext;
    if (targetContext == null) {
      print('Toast Error: No context available');
      return;
    }

    showDialog(
      context: targetContext,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (context) => _CustomToastDialog(
        message: message,
        backgroundColor: backgroundColor,
      ),
    );
  }
}

class _CustomToastDialog extends StatefulWidget {
  final String message;
  final Color backgroundColor;

  const _CustomToastDialog({
    required this.message,
    required this.backgroundColor,
  });

  @override
  State<_CustomToastDialog> createState() => _CustomToastDialogState();
}

class _CustomToastDialogState extends State<_CustomToastDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    // 5초 후 자동 닫기
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() async {
    await _controller.reverse();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Align(
                alignment: Alignment.topCenter,
                child: Material(
                  color: Colors.transparent,
                  child: GestureDetector(
                    onTap: _dismiss,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: widget.backgroundColor,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
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

// NavigationService 클래스 추가
class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
}