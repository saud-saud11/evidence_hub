import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'l10n_en.dart';
import 'l10n_ar.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  String translate(String key) {
    if (locale.languageCode == 'ar') {
      return arTranslation[key] ?? key;
    }
    return enTranslation[key] ?? key;
  }
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'ar'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('ar')); // Default to Arabic

  void setLocale(Locale locale) {
    state = locale;
  }

  void toggleLocale() {
    if (state.languageCode == 'ar') {
      state = const Locale('en');
    } else {
      state = const Locale('ar');
    }
  }
}

extension LocalizationExtension on BuildContext {
  String tr(String key) {
    return AppLocalizations.of(this)?.translate(key) ?? key;
  }
  
  bool get isRTL => Localizations.localeOf(this).languageCode == 'ar';
}
