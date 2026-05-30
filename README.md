# AIScan
這是首款檢查文章是否為 AI 或詐騙集團所製作出的假訊息或文章軟體，支援 Android 與 iOS。

## 功能

- 文章檢測
- 連結檢測

## 系統需求

| 項目 | 需求 |
| --- | --- |
| Flutter | 3.0.0 以上 |
| Dart | 3.0.0 以上 |
| Android SDK | 21 以上 |
| iOS | 12.0 以上 |

## 安裝方式

### 方法一:使用安裝腳本(Windows，推薦)

```powershell
git clone https://github.com/RoyZeng0317/AIScan.git
cd AIScan
.\install.ps1
```

### 方法二:手動安裝

```bash
# 1. Clone 專案
git clone https://github.com/RoyZeng0317/AIScan.git
cd AIScan/scaner

# 2. 安裝套件
flutter pub get

# 3. 執行 App
flutter run
```

## 執行 App

```bash
cd AIScan/scaner

# 執行在預設裝置
flutter run

# 列出可用裝置
flutter devices

# 指令裝置執行
flutter run -d <device_id>

# 建置 Android APK
flutter build apk --release

# 建置 iOS (需要 Mac)
flutter build ios --release
```

## 專案結構

```
scanner/
├── lib/
│   ├── main.dart              # 進入點
│   ├── services/
│   │   ├── ai_detector.dart   # API 呼叫
│   │   ├── article_fetcher.dart # 文章配對器
│   │   ├── ai_scan_dector.dart  # Firebase Auth
│   │   └── url_scanner_services.dart # Url 掃描服務
│   ├── screens/
│   │   ├── home_screen.dart   # 首頁（搜尋）
│   │   ├── text_scanner_screen.dart # 文章掃描
│   │   └── url_scann_screen.dart # 連結掃描
│   └── widgets/
│       └── scan_resilt_card.dart  # 掃描結果
└── pubspec.yaml

## 常見問題

**Q: `flutter run` 出現套件找不到的錯誤**

```bash
flutter clean
flutter pub get
flutter run
```

**Q: Android 裝置沒有出現**

確認已開啟手機的「開發人員選項」與「USB 偵錯」。
