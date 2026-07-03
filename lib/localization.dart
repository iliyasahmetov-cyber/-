import 'package:flutter/foundation.dart';

/// Supported languages. The game is strictly bilingual: Russian and English.
enum AppLanguage { ru, en }

/// App-wide language controller. Notifies listeners so the whole UI rebuilds
/// dynamically when the player flips the "Language / Язык" switch.
class LocaleController extends ChangeNotifier {
  LocaleController._();
  static final LocaleController instance = LocaleController._();

  AppLanguage _language = AppLanguage.ru;
  AppLanguage get language => _language;

  bool get isEnglish => _language == AppLanguage.en;

  void setLanguage(AppLanguage language) {
    if (_language == language) return;
    _language = language;
    notifyListeners();
  }

  void toggle() {
    _language =
        _language == AppLanguage.ru ? AppLanguage.en : AppLanguage.ru;
    notifyListeners();
  }

  /// Translate a [key] using the current language.
  String t(String key) => AppStrings.of(_language, key);

  /// Translate a [key] with `{n}` style placeholder substitution.
  String tp(String key, Map<String, Object> params) {
    var value = t(key);
    params.forEach((k, v) {
      value = value.replaceAll('{$k}', '$v');
    });
    return value;
  }
}

/// Rigid RU/EN string table. Every user-visible label lives here so that the
/// two supported languages stay perfectly in sync.
class AppStrings {
  static const Map<String, Map<AppLanguage, String>> _values = {
    'appTitle': {
      AppLanguage.ru: 'Пао Пао',
      AppLanguage.en: 'Pao Pao',
    },
    'appSubtitle': {
      AppLanguage.ru: 'Классическая головоломка «Соедини пары»',
      AppLanguage.en: 'Classic Onet Connect Puzzle',
    },
    'play': {
      AppLanguage.ru: 'Играть',
      AppLanguage.en: 'Play',
    },
    'howToPlay': {
      AppLanguage.ru: 'Как играть',
      AppLanguage.en: 'How to Play',
    },
    'howToPlayBody': {
      AppLanguage.ru:
          'Соединяйте две одинаковые плитки линией не более чем с двумя '
              'поворотами. Очистите всё поле, пока не вышло время.',
      AppLanguage.en:
          'Connect two identical tiles with a line of no more than two '
              'turns. Clear the whole board before the time runs out.',
    },
    'language': {
      AppLanguage.ru: 'Язык',
      AppLanguage.en: 'Language',
    },
    'languageToggle': {
      AppLanguage.ru: 'Язык / Language',
      AppLanguage.en: 'Language / Язык',
    },
    'score': {
      AppLanguage.ru: 'Очки',
      AppLanguage.en: 'Score',
    },
    'time': {
      AppLanguage.ru: 'Время',
      AppLanguage.en: 'Time',
    },
    'lives': {
      AppLanguage.ru: 'Жизни',
      AppLanguage.en: 'Lives',
    },
    'level': {
      AppLanguage.ru: 'Уровень',
      AppLanguage.en: 'Level',
    },
    'hint': {
      AppLanguage.ru: 'Подсказка',
      AppLanguage.en: 'Hint',
    },
    'pause': {
      AppLanguage.ru: 'Пауза',
      AppLanguage.en: 'Pause',
    },
    'resume': {
      AppLanguage.ru: 'Продолжить',
      AppLanguage.en: 'Resume',
    },
    'restart': {
      AppLanguage.ru: 'Заново',
      AppLanguage.en: 'Restart',
    },
    'mainMenu': {
      AppLanguage.ru: 'Главное меню',
      AppLanguage.en: 'Main Menu',
    },
    'paused': {
      AppLanguage.ru: 'Пауза',
      AppLanguage.en: 'Paused',
    },
    'quitTitle': {
      AppLanguage.ru: 'Выйти в меню?',
      AppLanguage.en: 'Quit to menu?',
    },
    'quitBody': {
      AppLanguage.ru: 'Текущий прогресс уровня будет потерян.',
      AppLanguage.en: 'Your current level progress will be lost.',
    },
    'yes': {
      AppLanguage.ru: 'Да',
      AppLanguage.en: 'Yes',
    },
    'no': {
      AppLanguage.ru: 'Нет',
      AppLanguage.en: 'No',
    },
    'ok': {
      AppLanguage.ru: 'OK',
      AppLanguage.en: 'OK',
    },
    // --- Ad / reward loop strings ---
    'adTimeUpTitle': {
      AppLanguage.ru: 'Время вышло!',
      AppLanguage.en: 'Time is up!',
    },
    'adLivesTitle': {
      AppLanguage.ru: 'Жизни закончились!',
      AppLanguage.en: 'Out of lives!',
    },
    'adRewardPrompt': {
      AppLanguage.ru: 'Просмотри видео, чтобы получить +60 секунд',
      AppLanguage.en: 'Watch video for +60 seconds',
    },
    'adHintPrompt': {
      AppLanguage.ru:
          'Просмотри видео, чтобы получить подсказку — мы подсветим пару.',
      AppLanguage.en:
          'Watch a video to get a hint — we will highlight one pair.',
    },
    'watchVideo': {
      AppLanguage.ru: 'Смотреть видео',
      AppLanguage.en: 'Watch Video',
    },
    'noThanks': {
      AppLanguage.ru: 'Нет, спасибо',
      AppLanguage.en: 'No, thanks',
    },
    'adWatching': {
      AppLanguage.ru: 'Реклама… {n} сек',
      AppLanguage.en: 'Advertisement… {n}s',
    },
    'adSkipInfo': {
      AppLanguage.ru: 'Награда будет начислена после просмотра.',
      AppLanguage.en: 'Your reward is granted after the video.',
    },
    'adLoading': {
      AppLanguage.ru: 'Загрузка рекламы…',
      AppLanguage.en: 'Loading ad…',
    },
    'adUnavailable': {
      AppLanguage.ru: 'Реклама сейчас недоступна. Попробуйте позже.',
      AppLanguage.en: 'Ad unavailable right now. Please try again later.',
    },
    'rewardGranted': {
      AppLanguage.ru: 'Награда получена!',
      AppLanguage.en: 'Reward granted!',
    },
    // --- End states ---
    'gameOverTitle': {
      AppLanguage.ru: 'Игра окончена',
      AppLanguage.en: 'Game Over',
    },
    'gameOverBody': {
      AppLanguage.ru: 'Вы набрали {n} очков.',
      AppLanguage.en: 'You scored {n} points.',
    },
    'youWinTitle': {
      AppLanguage.ru: 'Уровень пройден!',
      AppLanguage.en: 'Level Complete!',
    },
    'youWinBody': {
      AppLanguage.ru: 'Отлично! Итог: {n} очков.',
      AppLanguage.en: 'Well done! Final score: {n} points.',
    },
    'playAgain': {
      AppLanguage.ru: 'Играть ещё',
      AppLanguage.en: 'Play Again',
    },
    'nextLevel': {
      AppLanguage.ru: 'Следующий уровень',
      AppLanguage.en: 'Next Level',
    },
    'shuffling': {
      AppLanguage.ru: 'Нет ходов — перемешиваем плитки…',
      AppLanguage.en: 'No moves left — shuffling tiles…',
    },
    'tilesLeft': {
      AppLanguage.ru: 'Осталось',
      AppLanguage.en: 'Left',
    },
  };

  static String of(AppLanguage language, String key) {
    final entry = _values[key];
    if (entry == null) return key;
    return entry[language] ?? entry[AppLanguage.en] ?? key;
  }
}
