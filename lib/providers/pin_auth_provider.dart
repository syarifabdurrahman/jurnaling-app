import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// PIN authentication state
enum PinAuthState {
  /// No PIN has been set (first time user)
  notSet,

  /// PIN has been set and user needs to authenticate
  locked,

  /// User is authenticated
  authenticated,

  /// PIN is currently being set up
  settingUp,

  /// Verifying PIN for change
  verifying,

  /// Setting new PIN after verification
  changing,
}

/// PIN authentication state class
class PinAuth {
  const PinAuth({
    required this.state,
    this.error,
    this.attemptsRemaining = 3,
    this.pendingPin,
  });

  final PinAuthState state;
  final String? error;
  final int attemptsRemaining;
  final String? pendingPin;

  PinAuth copyWith({
    PinAuthState? state,
    String? error,
    int? attemptsRemaining,
    String? pendingPin,
  }) {
    return PinAuth(
      state: state ?? this.state,
      error: error,
      attemptsRemaining: attemptsRemaining ?? this.attemptsRemaining,
      pendingPin: pendingPin ?? this.pendingPin,
    );
  }
}

/// PIN authentication repository interface (SOLID - Dependency Inversion)
abstract class PinAuthRepository {
  Future<bool> hasPinSet();
  Future<bool> verifyPin(String pin);
  Future<void> setPin(String pin);
  Future<void> changePin(String oldPin, String newPin);
  Future<void> removePin();
}

/// Shared preferences implementation of PIN auth repository
class SharedPreferencesPinAuthRepository implements PinAuthRepository {
  SharedPreferencesPinAuthRepository(this.prefs);

  final SharedPreferences prefs;
  static const String _pinKey = 'user_pin_hash';
  static const String _saltKey = 'pin_salt';

  String _generateSalt() {
    final random = DateTime.now().millisecondsSinceEpoch.toString();
    return random;
  }

  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode(pin + salt);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  @override
  Future<bool> hasPinSet() async {
    final pinHash = prefs.getString(_pinKey);
    return pinHash != null && pinHash.isNotEmpty;
  }

  @override
  Future<bool> verifyPin(String pin) async {
    final pinHash = prefs.getString(_pinKey);
    final salt = prefs.getString(_saltKey);

    if (pinHash == null || salt == null) return false;

    final inputHash = _hashPin(pin, salt);
    return inputHash == pinHash;
  }

  @override
  Future<void> setPin(String pin) async {
    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);

    await prefs.setString(_pinKey, hash);
    await prefs.setString(_saltKey, salt);
  }

  @override
  Future<void> changePin(String oldPin, String newPin) async {
    if (await verifyPin(oldPin)) {
      await setPin(newPin);
    } else {
      throw Exception('Current PIN is incorrect');
    }
  }

  @override
  Future<void> removePin() async {
    await prefs.remove(_pinKey);
    await prefs.remove(_saltKey);
  }
}

/// SharedPreferences provider
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return await SharedPreferences.getInstance();
});

/// PIN auth repository provider
final pinAuthRepositoryProvider = Provider<PinAuthRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).value;
  if (prefs == null) {
    throw UnimplementedError('SharedPreferences not initialized');
  }
  return SharedPreferencesPinAuthRepository(prefs);
});

/// PIN authentication state notifier
class PinAuthNotifier extends StateNotifier<PinAuth> {
  PinAuthNotifier(this._repository) : super(const PinAuth(state: PinAuthState.notSet)) {
    _initialize();
  }

  final PinAuthRepository _repository;
  String? _pendingPin;
  int _failedAttempts = 0;

  Future<void> _initialize() async {
    try {
      final hasPin = await _repository.hasPinSet();
      state = PinAuth(
        state: hasPin ? PinAuthState.locked : PinAuthState.notSet,
        attemptsRemaining: 3,
      );
    } catch (e) {
      state = PinAuth(
        state: PinAuthState.notSet,
        error: 'Failed to initialize: $e',
      );
    }
  }

  Future<void> verifyPin(String pin) async {
    state = state.copyWith(error: null);

    if (pin.length != 4) {
      state = state.copyWith(error: 'PIN must be 4 digits');
      return;
    }

    try {
      final isValid = await _repository.verifyPin(pin);
      if (isValid) {
        _failedAttempts = 0;
        state = PinAuth(
          state: PinAuthState.authenticated,
          attemptsRemaining: 3,
        );
      } else {
        _failedAttempts++;
        final remaining = 3 - _failedAttempts;
        if (remaining <= 0) {
          state = PinAuth(
            state: PinAuthState.locked,
            error: 'Too many failed attempts',
            attemptsRemaining: 0,
          );
        } else {
          state = PinAuth(
            state: PinAuthState.locked,
            error: 'Incorrect PIN',
            attemptsRemaining: remaining,
          );
        }
      }
    } catch (e) {
      state = state.copyWith(error: 'Verification failed: $e');
    }
  }

  Future<void> setPin(String pin) async {
    state = state.copyWith(error: null);

    if (pin.length != 4) {
      state = state.copyWith(error: 'PIN must be 4 digits');
      return;
    }

    // Optimistically update state immediately for UI responsiveness
    _failedAttempts = 0;
    final previousState = state;
    state = const PinAuth(
      state: PinAuthState.authenticated,
      attemptsRemaining: 3,
    );

    try {
      await _repository.setPin(pin);
      // State already updated, nothing more to do
    } catch (e) {
      // Revert state on error
      state = previousState.copyWith(error: 'Failed to set PIN: $e');
    }
  }

  void startSetup() {
    state = const PinAuth(state: PinAuthState.settingUp);
    _pendingPin = null;
  }

  void cancelSetup() {
    _pendingPin = null;
    state = const PinAuth(state: PinAuthState.notSet);
  }

  void startChange() {
    state = const PinAuth(state: PinAuthState.verifying);
    _pendingPin = null;
  }

  void confirmSetupPin(String pin) {
    if (pin.length != 4) {
      state = state.copyWith(error: 'PIN must be 4 digits');
      return;
    }

    if (_pendingPin == null) {
      _pendingPin = pin;
    } else if (_pendingPin == pin) {
      setPin(pin);
    } else {
      state = state.copyWith(error: 'PINs do not match');
      _pendingPin = null;
    }
  }

  Future<void> verifyAndChange(String oldPin, String newPin) async {
    state = state.copyWith(error: null);

    if (oldPin.length != 4 || newPin.length != 4) {
      state = state.copyWith(error: 'PIN must be 4 digits');
      return;
    }

    try {
      await _repository.changePin(oldPin, newPin);
      state = PinAuth(
        state: PinAuthState.authenticated,
        attemptsRemaining: 3,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> signOut() async {
    state = PinAuth(
      state: PinAuthState.locked,
      attemptsRemaining: 3,
    );
  }

  String? get pendingPin => _pendingPin;
}

/// PIN auth state notifier provider
final pinAuthProvider = StateNotifierProvider<PinAuthNotifier, PinAuth>((ref) {
  final repository = ref.watch(pinAuthRepositoryProvider);
  return PinAuthNotifier(repository);
});
