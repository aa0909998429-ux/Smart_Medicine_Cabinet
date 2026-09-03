# Smart Medicine Cabinet｜智慧藥櫃

![Flutter CI](https://github.com/aa0909998429-ux/Smart_Medicine_Cabinet/actions/workflows/flutter-ci.yml/badge.svg)

以 **Flutter** 製作的智慧藥櫃原型，結合中／日文 OCR、本機 SQLite 藥品搜尋、持久化庫存管理、症狀文字篩選與重複有效成分提醒。

> **醫療免責聲明**：本專案為原型／學習用途，不是醫療器材，也不能取代醫師或藥師的診斷與用藥建議。症狀篩選只做文字匹配；成分檢查也不是完整的藥物交互作用判定。

## 功能

- 中／日文藥盒 OCR（相機與相簿，辨識模型隨 App 安裝，不依賴首次下載）
- OCR 完整藥名優先排序，避免包裝上的一般說明文字蓋過正確品項
- 顯示最近一次 OCR 原文與圖片；入庫後把圖片保存於 App 私有目錄
- 較嚴格的包裝數量辨識（如 `30 錠`、`24錠剤`、`20 tablets`）
- SQLite 中文名／英文名／別名／許可證／成分／適應症搜尋
- 藥櫃庫存透過 `SharedPreferences` 持久化，App 重啟後仍保留
- 依症狀關鍵字篩選目前藥櫃中的藥品
- Acetaminophen、Ibuprofen、Aspirin 的重複有效成分提醒
- 服藥後扣除庫存與低庫存提示
- 服藥紀錄持久化，保留服用時間、藥名與數量
- 可由使用者清除全部服藥紀錄
- 依有效期限分批管理庫存，阻擋過期或缺少效期的批次
- 30 天內到期、已過期與低庫存提示
- 內建 5,297 筆 TFDA 有效成藥、乙類成藥與指示藥許可證快照
- 「大正百保能／百保能／パブロン／Pabron」跨語言別名搜尋

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
│   ├── db_helper.dart                    # SQLite 初始化、TFDA 匯入與搜尋
│   ├── screens/
│   │   └── symptom_search_screen.dart    # 藥櫃與症狀篩選 UI
│   └── services/
│       ├── cabinet_storage_service.dart  # 藥櫃持久化
│       ├── duplicate_ingredient_checker.dart
│       ├── inventory_status.dart
│       ├── medication_history_service.dart
│       ├── medicine_search_ranker.dart   # OCR 關鍵字清理與結果排序
│       └── ocr_quantity_parser.dart
├── assets/
│   ├── README.md                         # TFDA 來源、授權與篩選規則
│   └── data/tfda_common_drugs.json       # 有效非處方／指示藥子集
├── tool/
│   └── update_tfda_dataset.ps1           # 官方資料更新工具
├── test/
│   ├── interaction_checker_test.dart
│   └── ocr_quantity_parser_test.dart
├── pubspec.yaml
└── README.md
```

## 藥品資料

App 內建衛福部食藥署「全部藥品許可證資料集」的離線衍生子集。本次快照日期為 **2026-09-02**，只保留當日未註銷、許可證仍有效，且分類為成藥、乙類成藥或醫師藥師藥劑生指示藥品的 5,297 張許可證。

- 資料集：https://data.gov.tw/dataset/9122
- 原始檔：https://data.fda.gov.tw/data/opendata/export/36/csv
- 授權：政府資料開放授權條款－第1版
- 產生工具：`tool/update_tfda_dataset.ps1`

這只是定期快照，不保證使用當下許可狀態或仿單仍相同。App 不會根據資料自動決定用藥；請核對實體包裝與最新官方資訊，並依醫師或藥師指示使用。

更新資料：

```powershell
.\tool\update_tfda_dataset.ps1
```

## 執行

```bash
flutter pub get
flutter run
```

Android 已在 App 模組明確加入 ML Kit 中文與日文辨識模型；iOS `Podfile` 也加入對應的 `TextRecognitionChinese` 與 `TextRecognitionJapanese` Pods。若只安裝套件而沒有這些平台依賴，預設通常只能可靠辨識拉丁文字。

拍攝藥盒時請讓藥名正面朝向鏡頭、填滿畫面、避免反光與手震。OCR 結果只用來協助搜尋；加入藥櫃前仍須核對畫面上的正式品名、許可證字號、數量與實體有效期限。

入庫時必須依照實體包裝選擇有效期限。同藥名但不同效期會保留為不同批次；已過期或舊版資料中缺少效期的批次不能加入服藥紀錄。

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
- OCR 完整藥名排序與中／日文字元正規化
- 避免把一般年份／價格誤判成藥品數量
- TFDA 資料來源、授權、許可證唯一性與分類完整性
- 大正百保能中／英／日別名存在性

每次 push / pull request 到 `main` 時，GitHub Actions 會自動執行：

```bash
flutter analyze
flutter test
flutter build apk --debug
```

## 工程改善

這個版本已將原本集中在 `main.dart` 的功能拆成 App、Screen、Database 與 Services，讓 OCR、資料持久化、成分檢查都能獨立維護與測試。

原本介面中的「AI 問診」也改名為「症狀篩選」，因目前實作是文字匹配，不宣稱提供 AI 診斷。

未使用的 Generative AI 與 Barcode dependencies 已先移除，等功能真的實作時再加入，避免不必要的 dependency surface。

## Roadmap

- [x] 藥品有效期限管理與到期提醒
- [x] 服藥紀錄（medication history）
- [ ] Barcode / QR code 掃描流程
- [x] 具明確來源與授權的 TFDA 非處方／指示藥資料
- [ ] 更完整的成分標準化與安全規則
- [ ] App screenshots / demo GIF
- [x] 持久化藥櫃庫存
- [x] TFDA 離線資料匯入與資料庫升級
- [x] GitHub Actions：`flutter analyze` + `flutter test`

## License

目前尚未指定程式碼 License。若希望其他人可以合法使用、修改或散布程式碼，請加入合適的 `LICENSE` 檔案。

## 發布注意事項

目前仍是原型，不應直接以醫療產品名義公開發行。實機測試、簽章、隱私政策、藥品資料授權與專業內容審查等必要事項請見 [發布前安全檢查清單](docs/RELEASE_CHECKLIST.md)。
