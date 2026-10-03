import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_campus/core/constants.dart';
import 'package:smart_campus/core/router.dart';
import 'package:smart_campus/features/auth/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();
  late final Animation<double> _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
  late final Animation<double> _scale =
      Tween<double>(begin: 0.7, end: 1).animate(CurvedAnimation(parent: _c, curve: Curves.elasticOut));

  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    final auth = context.read<AuthProvider>();
    final started = DateTime.now();
    final user = await auth.restoreSession();
    final elapsed = DateTime.now().difference(started);
    const total = Duration(milliseconds: 2500);
    if (elapsed < total) await Future.delayed(total - elapsed);
    if (!mounted) return;
    if (user != null) {
      AppRouter.toHome(context, user);
    } else {
      AppRouter.toLogin(context);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF172554),
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 116,
                      height: 116,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: Image.asset('assets/logo.png', fit: BoxFit.cover),
                    ),
                    Positioned(
                      right: -8,
                      top: -8,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.teal,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF172554), width: 4),
                        ),
                        child: const Icon(Icons.bolt, size: 18, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                const Text(AppStrings.appName,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5)),
                const SizedBox(height: 8),
                const Text(AppStrings.tagline,
                    style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 16)),
                const SizedBox(height: 48),
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
