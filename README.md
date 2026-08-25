# Smart Med Cabinet｜智慧藥櫃

一個以 **Flutter** 製作的智慧藥櫃原型，結合本機 SQLite 藥品資料庫、Google ML Kit 中／日文 OCR、藥品庫存管理、症狀篩選與簡易重複成分警示。

> **重要提醒**：本專案目前是原型／學習用途，不是醫療器材，也不能取代醫師、藥師的診斷與用藥建議。程式中的藥品推薦與成分衝突檢查規則有限，不能視為完整的藥物交互作用判定。

## 功能

- **中／日文藥盒 OCR**：可從相機或相簿讀取藥盒文字。
- **包裝數量辨識**：以正規表示式與模糊比對嘗試擷取「30 錠、12 包」等數量資訊。
- **本機藥品搜尋**：使用 SQLite 依藥名／適應症查詢台灣與日本藥品資料。
- **智慧藥櫃管理**：把搜尋到的藥品加入目前藥櫃並記錄數量。
- **症狀篩選**：在目前藥櫃中依症狀或藥名篩出可能相關的藥品。
- **重複成分警示**：目前針對 Acetaminophen、Ibuprofen、Aspirin 做簡易重複成分攔截。
- **服藥扣庫存與低庫存提醒**：確認服藥後自動扣除數量，低於門檻時顯示提醒。

## 技術棧

- Flutter / Dart
- `sqflite` + SQLite
- `google_mlkit_text_recognition`
- `image_picker`
- `path` / `path_provider`

專案的 Dart SDK 約束為 `^3.12.2`，Android `minSdk` 為 24。

## 專案結構

```text
smart_med_cabinet/
├── lib/
│   ├── main.dart              # 主要 UI、OCR、庫存、症狀篩選與衝突檢查
│   └── db_helper.dart         # SQLite 初始化與藥品查詢
├── assets/
│   └── smart_medicine_cabinet.db
├── test/
│   └── interaction_checker_test.dart
├── android/ ios/ macos/ ...   # Flutter 平台專案骨架
├── pubspec.yaml
├── pubspec.lock
└── README.md
```

## 本機資料庫

`assets/smart_medicine_cabinet.db` 會在 App 第一次啟動時複製到應用程式文件目錄後開啟。整理時確認資料庫完整性正常，內容目前包含：

- `medicines`：15,183 筆
- `japanese_medicines`：5 筆

### 公開資料前請注意

目前專案內沒有找到這份藥品資料庫的**資料來源、授權條款或 attribution**。如果資料來自政府開放資料、第三方網站或自行整理資料，建議在公開 Repository 前補上來源網址、資料版本日期與授權說明。

## 開始使用

先確認電腦已安裝 Flutter，接著執行：

```bash
flutter pub get
flutter run
```

若使用 Android，請自行在本機準備 Android SDK。`android/local.properties` 屬於每台電腦的本機設定，已排除於 Git 版本控制之外。

## 測試

```bash
flutter test
```

原本 Flutter 範本內的 Counter 測試已移除，改成針對目前專案的 `InteractionChecker` 做基本測試。

## 目前限制

- 藥櫃庫存 `_myCabinet` 目前主要存在記憶體中，App 重啟後不會自動還原。
- 症狀推薦目前是文字包含比對，不是臨床診斷模型。
- 成分衝突檢查只涵蓋少數指定成分，無法取代完整藥物交互作用資料庫。
- 專案雖保留 Flutter 多平台骨架，但 OCR 與相關插件的實際平台支援仍需依插件版本確認。
- `pubspec.yaml` 內仍有部分目前程式碼未直接使用的套件，可在後續重構時再移除並重新產生 lockfile。

## GitHub 建議

第一次建立 Repository 後，可在專案根目錄執行：

```bash
git init
git add .
git commit -m "Initial commit: Smart Med Cabinet"
git branch -M main
git remote add origin <YOUR_REPOSITORY_URL>
git push -u origin main
```

## License

目前尚未指定 License。若要公開讓其他人使用或修改程式碼，建議先決定合適的開源授權方式，再加入 `LICENSE` 檔案。
