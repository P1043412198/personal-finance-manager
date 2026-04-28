# Personal Finance Manager

Личный менеджер и финансовый помощник на Flutter (Android).
Personal manager + finance assistant built with Flutter for Android.

## Возможности / Features

- **Главная (Home):** приветствие, donut-диаграмма бюджета (доходы / расходы / остаток), быстрые действия, последние операции.
- **Операции (Operations):** список транзакций с группировкой по дням, фильтры (все / расходы / доходы), добавление и редактирование.
- **Бюджет (Budget):** месячный план, лимиты по категориям, прогноз на конец месяца, шаблоны 50/30/20, нулевой бюджет, конверты, советы.
- **Аналитика (Analytics):** круговая диаграмма по категориям, график динамики расходов, переключатель Неделя / Месяц / Год / Период.
- **Задачи (Tasks):** приоритеты, сроки, категории, прогресс выполнения.
- **Привычки (Habits):** полезные / вредные, streak'и, экономия в день, отметка по дням за неделю.
- **Заметки (Notes):** заголовок, текст, категории, прикрепление изображений и ссылок.
- **Цели (Goals):** sinking funds — целевая сумма, накоплено, прогресс, срок.
- **Категории (Categories):** общая система с областями применения (tx / task / habit / note), эмодзи, цвет.
- **Обучение (Learn):** короткие статьи о финансовой грамотности.
- **Профиль (Profile):** имя, язык (ru/en), тема (system/light/dark), валюта, экспорт JSON/CSV, сброс данных.
- **Локально и приватно:** все данные хранятся на устройстве (Hive). Без аккаунтов, без интернета.

## Стек / Stack

- **Flutter 3.24** + Dart 3.5
- **Material 3**, светлая/тёмная тема
- **Hive** (локальное хранилище)
- **Provider** (state management)
- **fl_chart** (диаграммы)
- **intl** (форматирование), **table_calendar**, **image_picker**, **share_plus**, **url_launcher**

## Сборка / Build

```bash
flutter pub get
flutter build apk --release
# APK: build/app/outputs/flutter-apk/app-release.apk
```

## Структура / Structure

```
lib/
  main.dart                    — entry, MaterialApp, providers
  theme/app_theme.dart         — цветовая схема и Material 3 тема
  utils/
    i18n.dart                  — ru/en строки
    format.dart                — форматирование валют/дат
  models/                      — Category / Transaction / Task / Habit / Note / Goal / Budget
  repos/store.dart             — JSON-string обёртка над Hive
  providers/app_state.dart     — корневой ChangeNotifier со всеми репозиториями
  screens/
    onboarding_screen.dart
    home_shell.dart            — bottom navigation
    home/home_tab.dart
    operations/operations_tab.dart
    budget/budget_tab.dart
    learn/learn_tab.dart
    profile/profile_tab.dart
    transaction/                — добавление и сканер чеков
    tasks/ habits/ notes/ goals/ categories/ analytics/
  widgets/section.dart         — переиспользуемые карточки/секции
```

## Что осталось на следующие итерации

- Полноценный OCR сканер чеков (заглушка готова)
- Локальные уведомления (напоминания о задачах, привычках, регулярных платежах)
- Биометрический замок (PIN-код / отпечаток)
- Виджет на главный экран Android
- Pomodoro-таймер с фоновой работой
- Облачная синхронизация (опционально)
