import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── SharedPreferences provider (overridden in main) ─────────────────────────
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('Override in ProviderScope'),
);

// ─── Settings state ────────────────────────────────────────────────────────
class SettingsState {
  final String language;
  final ThemeMode themeMode;
  final String currency;

  const SettingsState({
    this.language = 'ar',
    this.themeMode = ThemeMode.system,
    this.currency = 'IQD',
  });

  SettingsState copyWith({
    String? language,
    ThemeMode? themeMode,
    String? currency,
  }) =>
      SettingsState(
        language: language ?? this.language,
        themeMode: themeMode ?? this.themeMode,
        currency: currency ?? this.currency,
      );
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier(this._prefs) : super(_load(_prefs));

  final SharedPreferences _prefs;

  static SettingsState _load(SharedPreferences prefs) {
    final lang = prefs.getString('language') ?? 'ar';
    final themeIndex = prefs.getInt('theme_mode') ?? ThemeMode.system.index;
    final currency = prefs.getString('currency') ?? 'IQD';
    return SettingsState(
      language: lang,
      themeMode: ThemeMode.values[themeIndex],
      currency: currency,
    );
  }

  Future<void> setLanguage(String lang) async {
    await _prefs.setString('language', lang);
    state = state.copyWith(language: lang);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setInt('theme_mode', mode.index);
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setCurrency(String currency) async {
    await _prefs.setString('currency', currency);
    state = state.copyWith(currency: currency);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) => SettingsNotifier(ref.watch(sharedPreferencesProvider)),
);
