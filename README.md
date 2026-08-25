# Smart Medicine Cabinet｜智慧藥櫃

以 **Flutter** 製作的智慧藥櫃原型，結合中／日文 OCR、本機 SQLite 藥品搜尋、持久化庫存管理、症狀文字篩選與重複有效成分提醒。

> **醫療免責聲明**：本專案為原型／學習用途，不是醫療器材，也不能取代醫師或藥師的診斷與用藥建議。症狀篩選只做文字匹配；成分檢查也不是完整的藥物交互作用判定。

## 功能

- 中／日文藥盒 OCR（相機與相簿）
- 較嚴格的包裝數量辨識（如 `30 錠`、`24錠剤`、`20 tablets`）
- SQLite 藥名／英文名／成分／適應症搜尋
- 藥櫃庫存管理，並透過 `SharedPreferences` 在 App 重啟後保留
- 依症狀關鍵字篩選目前藥櫃中的藥品
- Acetaminophen、Ibuprofen、Aspirin 的重複有效成分提醒
- 服藥後扣除庫存與低庫存提示
- Public repo 內附可再散布的 synthetic sample database，clone 後即可測試搜尋流程

## 技術

- Flutter / Dart
- `sqflite` + SQLite
- `shared_preferences`
- Google ML Kit Text Recognition
- `image_picker`
- `path` / `path_provider`

## 專案結構

```text
Smart_Medicine_Cabinet/
├── lib/
│   ├── main.dart                         # App 入口
│   ├── app.dart                          # MaterialApp / Theme
│   ├── db_helper.dart                    # SQLite 初始化與搜尋
│   ├── screens/
│   │   └── symptom_search_screen.dart    # 主要藥櫃與症狀篩選 UI
│   └── services/
│       ├── cabinet_storage_service.dart  # 藥櫃持久化
│       ├── duplicate_ingredient_checker.dart
│       └── ocr_quantity_parser.dart
├── assets/
│   ├── smart_medicine_cabinet.db         # Synthetic demo data
│   └── README.md
├── test/
│   ├── interaction_checker_test.dart
│   └── ocr_quantity_parser_test.dart
├── pubspec.yaml
└── README.md
```

## Sample database

Public Repository 內的 `assets/smart_medicine_cabinet.db` 是**刻意製作的示範資料**，只用來讓專案可以直接執行與展示搜尋／重複成分流程，不代表真實藥品資料，也不可作為用藥依據。

原始專案曾使用較大的藥品資料庫（約 15,183 筆 Taiwan medicines + 5 筆 Japanese medicines）。由於原專案沒有附上完整資料來源、版本日期、授權條款與 attribution，該原始資料庫目前沒有放進 Public Repository。

若未來確認資料允許再散布，請在公開前補上：

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

## 測試

```bash
flutter test
```

目前測試包含：

- 重複有效成分偵測
- 不同成分不誤報
- OCR 包裝數量格式解析
- 避免把一般年份／價格誤判成藥品數量

## 工程改善

這個版本已將原本集中在 `main.dart` 的功能拆成 App、Screen、Database 與 Services，讓 OCR、資料持久化、成分檢查都可以獨立測試與維護。

另外，介面中的原「AI 問診」改名為「症狀篩選」，因目前實作是文字匹配，不宣稱提供 AI 診斷。

## Roadmap

- [ ] 藥品有效期限管理與到期提醒
- [ ] 服藥紀錄（medication history）
- [ ] Barcode / QR code 掃描流程
- [ ] 更完整、具明確授權的藥品資料來源
- [ ] 更完整的成分標準化與安全規則
- [ ] App screenshots / demo GIF
- [ ] GitHub Actions：`flutter analyze` + `flutter test`

## License

目前尚未指定程式碼 License。若希望其他人可以合法使用、修改或散布程式碼，請加入合適的 `LICENSE` 檔案。
