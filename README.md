# Smart Medicine Cabinet｜智慧藥櫃

以 **Flutter** 製作的智慧藥櫃原型，結合中／日文 OCR、本機 SQLite 藥品搜尋、庫存管理、症狀篩選與簡易重複成分警示。

> **醫療免責聲明**：本專案目前為原型／學習用途，不是醫療器材，也不能取代醫師或藥師的診斷與用藥建議。推薦與成分檢查規則有限，不能視為完整的藥物交互作用判定。

## 功能

- 中／日文藥盒 OCR（相機與相簿）
- 包裝數量文字辨識
- SQLite 台灣／日本藥品搜尋
- 智慧藥櫃庫存管理
- 依症狀篩選目前藥櫃中的藥品
- Acetaminophen、Ibuprofen、Aspirin 重複成分警示
- 服藥後自動扣庫存與低庫存提醒

## 技術

- Flutter / Dart
- `sqflite` + SQLite
- Google ML Kit Text Recognition
- `image_picker`
- `path` / `path_provider`

## 專案結構

```text
Smart_Medicine_Cabinet/
├── lib/
│   ├── main.dart
│   └── db_helper.dart
├── assets/
│   └── README.md
├── test/
│   └── interaction_checker_test.dart
├── pubspec.yaml
├── analysis_options.yaml
├── .gitignore
└── README.md
```

## 藥品資料庫

原始專案使用：

```text
assets/smart_medicine_cabinet.db
```

整理時確認原始 SQLite 資料庫完整性正常，內容約包含：

- `medicines`：15,183 筆
- `japanese_medicines`：5 筆

### 為什麼 Public Repository 目前沒有放 `.db`？

原始專案內沒有附上這份資料的來源網址、版本日期、授權條款或 attribution。為避免在 Public Repository 中重新散布授權狀態不明的藥品資料，目前先不公開資料庫本體。

如果你是 Repository 維護者，在確認資料來源允許公開再散布後，請將資料庫放到：

```text
assets/smart_medicine_cabinet.db
```

並在 README 補上資料來源與 License。`assets/README.md` 也有相同提醒。

## 執行

安裝 Flutter 後：

```bash
flutter pub get
flutter run
```

目前 `pubspec.yaml` 仍保留資料庫 asset 路徑，因此要完整使用藥品搜尋功能，需要先放入上述 SQLite 檔案。

若平台專案檔尚未存在，可在專案根目錄執行：

```bash
flutter create .
```

再執行 `flutter pub get`。

## 測試

```bash
flutter test
```

`test/interaction_checker_test.dart` 包含基本的重複高風險成分檢查測試。

## 目前限制

- 藥櫃庫存主要存在記憶體中，App 重啟後不會自動還原。
- 症狀推薦使用文字比對，不是臨床診斷模型。
- 成分衝突檢查目前只涵蓋少數指定成分。
- OCR 與插件支援情況會依執行平台及套件版本而異。
- Public Repository 目前未包含授權狀態不明的藥品 SQLite 資料庫。

## License

目前尚未指定程式碼 License。若希望其他人可以合法使用、修改或散布程式碼，請再加入合適的 `LICENSE` 檔案。
