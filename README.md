# Smart Medicine Cabinet｜智慧藥櫃

![Flutter CI](https://github.com/aa0909998429-ux/Smart_Medicine_Cabinet/actions/workflows/flutter-ci.yml/badge.svg)

以 **Flutter** 製作的智慧藥櫃原型，結合中／日文 OCR、本機 SQLite 藥品搜尋、持久化庫存管理、症狀文字篩選與重複有效成分提醒。

> **醫療免責聲明**：本專案為原型／學習用途，不是醫療器材，也不能取代醫師或藥師的診斷與用藥建議。症狀篩選只做文字匹配；成分檢查也不是完整的藥物交互作用判定。

## 功能

- 中／日文藥盒 OCR（相機與相簿）
- 較嚴格的包裝數量辨識（如 `30 錠`、`24錠剤`、`20 tablets`）
- SQLite 藥名／英文名／成分／適應症搜尋
- 藥櫃庫存透過 `SharedPreferences` 持久化，App 重啟後仍保留
- 依症狀關鍵字篩選目前藥櫃中的藥品
- Acetaminophen、Ibuprofen、Aspirin 的重複有效成分提醒
- 服藥後扣除庫存與低庫存提示
- 第一次啟動自動建立 synthetic demo SQLite 資料，clone 後即可展示搜尋流程

## 技術

- Flutter / Dart
- `sqflite` + SQLite
- `shared_preferences`
- Google ML Kit Text Recognition
- `image_picker`
- `path` / `path_provider`
- GitHub Actions

## 專案結構

```text
Smart_Medicine_Cabinet/
├── .github/workflows/
│   └── flutter-ci.yml                    # analyze + test
├── lib/
│   ├── main.dart                         # App 入口
│   ├── app.dart                          # MaterialApp / Theme
│   ├── db_helper.dart                    # SQLite 初始化、demo seed 與搜尋
│   ├── screens/
│   │   └── symptom_search_screen.dart    # 藥櫃與症狀篩選 UI
│   └── services/
│       ├── cabinet_storage_service.dart  # 藥櫃持久化
│       ├── duplicate_ingredient_checker.dart
│       └── ocr_quantity_parser.dart
├── assets/
│   └── README.md                         # 真實資料集公開注意事項
├── test/
│   ├── interaction_checker_test.dart
│   └── ocr_quantity_parser_test.dart
├── pubspec.yaml
└── README.md
```

## Demo data 與真實資料

Public Repository **不包含原始的大型藥品資料庫**。第一次啟動時，`DatabaseHelper` 會在 App 本機建立一個非常小的 synthetic demo database；所有記錄都標示為示範資料，只用來展示搜尋、庫存與重複有效成分流程，不能作為真實用藥資訊。

原始專案曾使用較大的藥品資料庫（約 15,183 筆 Taiwan medicines + 5 筆 Japanese medicines）。因原專案沒有附上完整資料來源、版本日期、授權條款與 attribution，目前不在 Public Repository 中重新散布。

未來若確認真實資料允許公開，請補上：

- 資料來源 URL
- 資料版本／更新日期
- License
- Attribution requirements

## 執行

```bash
flutter pub get
flutter run
```

如果 clone 後缺少平台骨架，可先執行：

```bash
flutter create .
```

## 測試與 CI

```bash
flutter test
```

目前測試包含：

- 重複有效成分偵測
- 不同成分不誤報
- OCR 包裝數量格式解析
- 避免把一般年份／價格誤判成藥品數量

每次 push / pull request 到 `main` 時，GitHub Actions 會自動執行：

```bash
flutter analyze
flutter test
```

## 工程改善

這個版本已將原本集中在 `main.dart` 的功能拆成 App、Screen、Database 與 Services，讓 OCR、資料持久化、成分檢查都能獨立維護與測試。

原本介面中的「AI 問診」也改名為「症狀篩選」，因目前實作是文字匹配，不宣稱提供 AI 診斷。

未使用的 Generative AI 與 Barcode dependencies 已先移除，等功能真的實作時再加入，避免不必要的 dependency surface。

## Roadmap

- [ ] 藥品有效期限管理與到期提醒
- [ ] 服藥紀錄（medication history）
- [ ] Barcode / QR code 掃描流程
- [ ] 更完整、具明確授權的藥品資料來源
- [ ] 更完整的成分標準化與安全規則
- [ ] App screenshots / demo GIF
- [x] 持久化藥櫃庫存
- [x] Synthetic demo database
- [x] GitHub Actions：`flutter analyze` + `flutter test`

## License

目前尚未指定程式碼 License。若希望其他人可以合法使用、修改或散布程式碼，請加入合適的 `LICENSE` 檔案。
