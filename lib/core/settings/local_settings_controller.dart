import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The ringtone that plays on an incoming call. Values are the old app's
/// three options (see `old app ss/IMG-20260709-WA0039.jpg`).
enum CallRingtone {
  classic('Classic', 'Traditional two-tone phone ring'),
  modern('Modern', 'Crisp twin-beep alert'),
  marimba('Marimba', 'Cheerful melodic chime');

  const CallRingtone(this.label, this.description);

  final String label;
  final String description;

  static CallRingtone fromName(String? name) => CallRingtone.values.firstWhere(
    (r) => r.name == name,
    orElse: () => CallRingtone.classic,
  );
}

/// Device-local settings — the ones with **no backing database column**,
/// because they describe how *this phone* behaves, not the account.
///
/// (The Group-A pass wrongly deleted these from Settings on the grounds that
/// no column existed. The old app has them; they belong here, not on the
/// server. See UI_REBUILD_PLAN.md §0.5.)
class LocalSettings {
  const LocalSettings({
    this.vibrateOnCall = true,
    this.ringtone = CallRingtone.classic,
    this.rememberEmail = false,
    this.rememberedEmail,
  });

  /// "Vibrate on incoming call" — buzz alongside the ringtone.
  final bool vibrateOnCall;

  /// Which sound plays when someone calls you.
  final CallRingtone ringtone;

  /// "Remember email after inactivity logout" — pre-fills the Auth screen's
  /// email field with [rememberedEmail] on future sign-ins from this device.
  final bool rememberEmail;

  /// The last email successfully signed in with, saved only while
  /// [rememberEmail] is on. Cleared when the toggle is switched off.
  final String? rememberedEmail;

  LocalSettings copyWith({
    bool? vibrateOnCall,
    CallRingtone? ringtone,
    bool? rememberEmail,
    String? rememberedEmail,
    bool clearRememberedEmail = false,
  }) => LocalSettings(
    vibrateOnCall: vibrateOnCall ?? this.vibrateOnCall,
    ringtone: ringtone ?? this.ringtone,
    rememberEmail: rememberEmail ?? this.rememberEmail,
    rememberedEmail: clearRememberedEmail
        ? null
        : (rememberedEmail ?? this.rememberedEmail),
  );
}

class LocalSettingsController extends Notifier<LocalSettings> {
  static const _kVibrate = 'settings.vibrate_on_call';
  static const _kRingtone = 'settings.call_ringtone';
  static const _kRememberEmail = 'settings.remember_email';
  static const _kRememberedEmail = 'settings.remembered_email';

  @override
  LocalSettings build() {
    _load();
    return const LocalSettings();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = LocalSettings(
      vibrateOnCall: prefs.getBool(_kVibrate) ?? true,
      ringtone: CallRingtone.fromName(prefs.getString(_kRingtone)),
      rememberEmail: prefs.getBool(_kRememberEmail) ?? false,
      rememberedEmail: prefs.getString(_kRememberedEmail),
    );
  }

  Future<void> setVibrateOnCall(bool enabled) async {
    state = state.copyWith(vibrateOnCall: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kVibrate, enabled);
  }

  Future<void> setRingtone(CallRingtone ringtone) async {
    state = state.copyWith(ringtone: ringtone);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRingtone, ringtone.name);
  }

  Future<void> setRememberEmail(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kRememberEmail, enabled);
    if (!enabled) {
      await prefs.remove(_kRememberedEmail);
      state = state.copyWith(rememberEmail: false, clearRememberedEmail: true);
    } else {
      state = state.copyWith(rememberEmail: true);
    }
  }

  /// Called after a successful sign-in — saves the email only if the user
  /// has opted in via [setRememberEmail].
  Future<void> rememberEmailIfEnabled(String email) async {
    if (!state.rememberEmail) return;
    state = state.copyWith(rememberedEmail: email);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRememberedEmail, email);
  }
}

final localSettingsProvider =
    NotifierProvider<LocalSettingsController, LocalSettings>(
      LocalSettingsController.new,
    );
