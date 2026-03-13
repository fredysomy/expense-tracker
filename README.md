# Money Manager

A personal expense and budget tracker for Android, built with Flutter. All data stays on your device — no accounts, no cloud, no subscriptions.

**[⬇ Download APK](https://github.com/fredysomy/expense-tracker/releases/latest)** — install directly on any Android device.

---

## Features

### Core
- **Transactions** — log income and expenses with category, account, date, and notes
- **Accounts** — track multiple accounts (bank, cash, wallet, credit card) with live balances
- **Categories** — fully customizable with parent/child hierarchy and icons
- **Budgets** — set daily, weekly, or monthly spending limits per category and account
- **Analytics** — monthly income vs expense bar chart, category donut breakdown

### Home Screen Widget
Tap the `+` widget on your home screen to open the quick-add sheet instantly — no full app load, no navigation. The sheet slides up from the bottom as a transparent overlay. The activity is excluded from recents.

### Daily Notification Reminder
Set a daily reminder time in Settings. At that time you receive a real spending summary pulled live from your database:

```
Daily Spending Summary
Spent ₹1,250  (5 transactions)
Top: Food & Drinks  ₹450
Earned ₹5,000  (1 transaction)
Net  +₹3,750
```

Powered by WorkManager — fires reliably even on Samsung One UI with aggressive battery management.

### Export & Import
Back up everything to a single JSON file and restore it on any device. The backup includes all accounts, categories, transactions, and budgets.

---

## Tech Stack

| Layer | Library |
|---|---|
| UI | Flutter 3, Material 3 |
| State management | flutter_riverpod 2.x (AsyncNotifier) |
| Database | sqflite (local SQLite, no cloud) |
| Charts | fl_chart |
| Notifications | flutter_local_notifications |
| Background tasks | workmanager |
| Formatting | intl (INR ₹) |
| Home screen widget | Native Android / Kotlin |

---

## Project Structure

```
lib/
  main.dart                         ← app entry + quickAddMain() for widget
  core/
    database/database_helper.dart   ← SQLite singleton, seeds default categories
    theme/app_theme.dart            ← Material 3, green seed color
    utils/                          ← formatters, icon helper
    notifications/notification_service.dart  ← WorkManager + notification logic
    data/export_import_service.dart ← JSON backup & restore
  models/                           ← Account, Category, Transaction, Budget
  repositories/                     ← DB access layer
  providers/                        ← Riverpod AsyncNotifier providers
  screens/
    dashboard/                      ← Home tab with balances & budgets
    transactions/                   ← Transaction list, add, edit
    categories/                     ← Category management
    budgets/                        ← Budget list & detail
    analytics/                      ← Charts & breakdowns
    accounts/                       ← Account management
    settings/                       ← Notifications, export, import
    quick_add/                      ← Bottom sheet quick-entry

android/app/src/main/kotlin/
  MainActivity.kt                   ← Battery optimization MethodChannel
  QuickAddActivity.kt               ← Transparent Flutter activity (widget tap)
  QuickAddWidget.kt                 ← Home screen AppWidgetProvider
```

---

## Building from Source

**Requirements:** Flutter 3.x, Android SDK 21+

```bash
git clone https://github.com/fredysomy/expense-tracker.git
cd expense-tracker
flutter pub get
flutter run                   # debug on connected device
flutter build apk --release   # release APK → build/app/outputs/flutter-apk/
```

---

## Data & Privacy

Everything is stored in a local SQLite database on your device. The app has no internet permission, collects no analytics, and requires no account. Your export files are plain JSON that you fully own.

---

## License

MIT
