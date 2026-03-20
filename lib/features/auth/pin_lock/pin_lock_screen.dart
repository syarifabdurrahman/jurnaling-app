import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/pin_auth_provider.dart';
import '../../../constants/colors.dart';
import '../../../widgets/glassmorphic_container.dart';
import '../../../utils/responsive.dart';

/// PIN lock screen for authentication
class PinLockScreen extends ConsumerStatefulWidget {
  const PinLockScreen({super.key});

  @override
  ConsumerState<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends ConsumerState<PinLockScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  final TextEditingController _pinController = TextEditingController();
  String? _lastError;
  bool _hasNavigated = false;
  bool _isOnConfirmScreen = false;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );
    _initializeScreen();
  }

  void _initializeScreen() {
    // Check if we should start on confirm screen
    final authState = ref.read(pinAuthProvider);
    _isOnConfirmScreen = authState.pendingPin != null;
  }

  void _handleErrorState(PinAuth authState) {
    // Trigger shake for PIN mismatch error
    if (authState.error != null &&
        authState.error!.contains('do not match')) {
      _shakeController.forward().then((_) => _shakeController.reverse());
      _pinController.clear();
      _isOnConfirmScreen = false;
    }

    // Trigger shake for incorrect PIN
    if (authState.error != null &&
        authState.error!.contains('Incorrect PIN') &&
        _lastError != authState.error) {
      _lastError = authState.error;
      _shakeController.forward().then((_) => _shakeController.reverse());
      _pinController.clear();
    }

    // Reset last error if no error
    if (authState.error == null) {
      _lastError = null;
    }
  }

  void _goBackToCreatePin() {
    setState(() {
      _isOnConfirmScreen = false;
      _pinController.clear();
    });
    ref.read(pinAuthProvider.notifier).cancelSetup();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _onPinChanged(String value) {
    final authState = ref.read(pinAuthProvider);
    final pinLength = value.length;

    // Auto-submit when 4 digits entered
    if (pinLength == 4) {
      switch (authState.state) {
        case PinAuthState.notSet:
          // First PIN entered - move to confirm screen
          ref.read(pinAuthProvider.notifier).startSetup();
          ref.read(pinAuthProvider.notifier).confirmSetupPin(value);
          setState(() {
            _isOnConfirmScreen = true;
            _pinController.clear();
          });
          break;
        case PinAuthState.locked:
          ref.read(pinAuthProvider.notifier).verifyPin(value);
          break;
        case PinAuthState.settingUp:
          ref.read(pinAuthProvider.notifier).confirmSetupPin(value);
          break;
        default:
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(pinAuthProvider);
    final isLoading = ref.watch(sharedPreferencesProvider).isLoading;

    // Listen for error state changes (must be in build method for Riverpod 2.x)
    ref.listen<PinAuth>(pinAuthProvider, (previous, next) {
      _handleErrorState(next);
    });

    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Handle authentication success - navigate to home
    if (authState.state == PinAuthState.authenticated && !_hasNavigated) {
      _hasNavigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      });
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.background,
              AppColors.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: ResponsivePadding(
            child: AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_shakeAnimation.value * 0.5, 0),
                  child: child,
                );
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildHeader(authState),
                  const SizedBox(height: 32),
                  _buildPinDotsArea(authState),
                  // Error message right below PIN dots
                  if (authState.error != null) ...[
                    const SizedBox(height: 12),
                    _buildErrorMessage(authState.error!),
                  ] else if (_isOnConfirmScreen || authState.state == PinAuthState.settingUp) ...[
                    const SizedBox(height: 12),
                    _buildSetupInfo(),
                  ],
                  const SizedBox(height: 24),
                  // Custom Numeric Keypad
                  _buildCustomKeypad(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(PinAuth authState) {
    String title;
    String subtitle;
    bool showBackButton = false;

    if (_isOnConfirmScreen || authState.state == PinAuthState.settingUp) {
      title = 'Confirm PIN';
      subtitle = 'Enter your PIN again to confirm';
      showBackButton = true;
    } else if (authState.state == PinAuthState.notSet) {
      title = 'Create a PIN';
      subtitle = 'Secure your journal with a 4-digit PIN';
      showBackButton = false;
    } else if (authState.state == PinAuthState.locked) {
      title = 'Enter PIN';
      subtitle = authState.attemptsRemaining > 0
          ? '${authState.attemptsRemaining} attempts remaining'
          : 'Too many attempts';
      showBackButton = false;
    } else {
      title = 'Enter PIN';
      subtitle = 'Secure your journal';
      showBackButton = false;
    }

    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.accentPrimary,
                AppColors.accentSecondary,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentPrimary.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(
            Icons.lock_outline,
            size: 40,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textMuted,
              ),
        ),
        if (showBackButton) ...[
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _goBackToCreatePin,
            child: Text(
              'Change PIN',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.accentPrimary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPinDotsArea(PinAuth authState) {
    final pinLength = _pinController.text.length;

    // PIN Dots Display
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final isActive = index < pinLength;
        final isCurrent = index == pinLength && pinLength < 4;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: EdgeInsets.symmetric(horizontal: isCurrent ? 14 : 12),
          height: 20,
          width: isActive ? 20 : 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? AppColors.accentPrimary : Colors.transparent,
            border: Border.all(
              color: AppColors.accentPrimary,
              width: 2,
            ),
            boxShadow: isActive ? [
              BoxShadow(
                color: AppColors.accentPrimary.withValues(alpha: 0.5),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ] : [],
          ),
        );
      }),
    );
  }

  Widget _buildCustomKeypad() {
    return Column(
      children: [
        for (var row in [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"]])
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((number) => _keypadButton(number)).toList(),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 80, // Spacer for layout balance
            height: 80),
            _keypadButton("0"),
            _backspaceButton(),
          ],
        ),
      ],
    );
  }

  Widget _keypadButton(String number) {
    return Container(
      margin: const EdgeInsets.all(8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onNumberPressed(number),
          borderRadius: BorderRadius.circular(40),
          splashColor: AppColors.accentPrimary.withValues(alpha: 0.2),
          highlightColor: AppColors.accentPrimary.withValues(alpha: 0.1),
          child: Container(
            height: 72,
            width: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.glassBorder,
                width: 1,
              ),
            ),
            child: Text(
              number,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.textHighContrast,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _backspaceButton() {
    return Container(
      margin: const EdgeInsets.all(8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _onBackspacePressed,
          borderRadius: BorderRadius.circular(40),
          splashColor: AppColors.moodAnxious.withValues(alpha: 0.2),
          child: Container(
            height: 72,
            width: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.glassBorder,
                width: 1,
              ),
            ),
            child: Icon(
              Icons.backspace_outlined,
              color: AppColors.textMuted,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  void _onNumberPressed(String number) {
    if (_pinController.text.length < 4) {
      setState(() {
        _pinController.text += number;
      });
      _onPinChanged(_pinController.text);
    }
  }

  void _onBackspacePressed() {
    if (_pinController.text.isNotEmpty) {
      setState(() {
        _pinController.text = _pinController.text.substring(0, _pinController.text.length - 1);
      });
    }
  }

  Widget _buildErrorMessage(String error) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.moodAnxious.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.moodAnxious.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline,
            color: AppColors.moodAnxious,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            error,
            style: const TextStyle(
              color: AppColors.moodAnxious,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetupInfo() {
    final hasPendingPin = ref.read(pinAuthProvider.notifier).pendingPin != null;

    return GlassmorphicContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 12,
      child: Row(
        children: [
          const Icon(
            Icons.info_outline,
            color: AppColors.accentPrimary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hasPendingPin
                  ? 'Make sure to remember your PIN'
                  : 'Choose a PIN you\'ll remember',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
