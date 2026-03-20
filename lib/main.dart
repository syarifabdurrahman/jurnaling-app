import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants/colors.dart';
import 'theme/app_theme.dart';
import 'features/auth/pin_lock/pin_lock_screen.dart';
import 'features/journal/journal_editor_screen.dart';
import 'features/journal/home_screen.dart';
import 'features/journal/journal_list_screen.dart';
import 'features/journal/insights_screen.dart';
import 'providers/pin_auth_provider.dart';
import 'utils/responsive.dart';

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Suppress Quill toolbar scroll position errors
  FlutterError.onError = (details) {
    // Ignore Quill scroll position null check errors
    if (details.exception.toString().contains('Null check operator used on a null value') &&
        details.stack.toString().contains('QuillToolbarArrowIndicatedButtonListState')) {
      return;
    }
    FlutterError.presentError(details);
  };

  // Initialize SharedPreferences before app starts
  final prefs = await SharedPreferences.getInstance();

  // Preload Google Fonts to prevent Android system font fallback
  await GoogleFonts.pendingFonts([
    GoogleFonts.plusJakartaSans(),
    GoogleFonts.lora(),
    GoogleFonts.playfairDisplay(),
  ]);

  runApp(
    ProviderScope(
      overrides: [
        // Override the PIN auth repository provider with the already initialized SharedPreferences
        pinAuthRepositoryProvider.overrideWithValue(
          SharedPreferencesPinAuthRepository(prefs),
        ),
      ],
      child: const MindFlowApp(),
    ),
  );
}

class MindFlowApp extends StatelessWidget {
  const MindFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      // Disable system font scaling - keep app font sizes consistent
      // Preserve all other MediaQuery data (padding, size, etc.)
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
      child: MaterialApp(
        title: 'MindFlow',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: '/',
        onGenerateRoute: (settings) {
          final widgets = {
            '/': const SplashScreen(),
            '/pin': const PinLockScreen(),
            '/home': const JournalHomeScreen(),
            '/journal': const JournalListScreen(),
            '/insights': const InsightsScreen(),
            '/editor': const JournalEditorScreen(),
          };

          final widget = widgets[settings.name] ?? const SplashScreen();

          // Apply transitions only to main navigation routes
          final useTransition = settings.name != '/' && settings.name != '/pin';

          if (useTransition) {
            return PageRouteBuilder(
              settings: settings,
              pageBuilder: (context, animation, secondaryAnimation) => widget,
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: CurveTween(curve: Curves.easeOut).animate(animation),
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 200),
            );
          }

          return MaterialPageRoute(
            builder: (context) => widget,
            settings: settings,
          );
        },
      ),
    );
  }
}

/// Splash screen shown on app launch
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();

    // Navigate to PIN lock after animation
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/pin');
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.background,
              const Color(0xFFFFFFFF),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ResponsivePadding(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App icon placeholder
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.accentPrimary, // Coral
                            AppColors.accentSecondary, // Emerald
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentPrimary.withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'MindFlow',
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your thoughts, beautifully preserved',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textMuted,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
