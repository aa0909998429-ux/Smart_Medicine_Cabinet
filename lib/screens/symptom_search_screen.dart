import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../db_helper.dart';
import '../services/cabinet_storage_service.dart';
import '../services/duplicate_ingredient_checker.dart';
import '../services/inventory_status.dart';
import '../services/medication_history_service.dart';
import '../services/medicine_search_ranker.dart';
import '../services/ocr_quantity_parser.dart';

class SymptomSearchScreen extends StatefulWidget {
  const SymptomSearchScreen({super.key});

  @override
  State<SymptomSearchScreen> createState() => _SymptomSearchScreenState();
}

class _SymptomSearchScreenState extends State<SymptomSearchScreen> {
  final _controller = TextEditingController();
  final _symptomController = TextEditingController();
  final _dbHelper = DatabaseHelper();
  final _storage = CabinetStorageService();
  final _historyStorage = MedicationHistoryService();
  final _picker = ImagePicker();

  late final TextRecognizer _chineseRecognizer;
  late final TextRecognizer _japaneseRecognizer;

  List<Map<String, dynamic>> _searchResults = [];
  final List<Map<String, dynamic>> _myCabinet = [];
  final List<Map<String, dynamic>> _pillsToTake = [];
  final List<Map<String, dynamic>> _medicationHistory = [];
  Map<String, String> _datasetMetadata = {};

  int _currentIndex = 0;
  int? _scannedQuantity;
  String? _scannedImagePath;
  String? _lastRecognizedText;
  String _symptomQuery = '';
  String _statusMessage = '輸入關鍵字或掃描藥盒開始搜尋';
  bool _isLoading = false;
  bool _isConfirmingMedication = false;

  @override
  void initState() {
    super.initState();
    _chineseRecognizer = TextRecognizer(script: TextRecognitionScript.chinese);
    _japaneseRecognizer = TextRecognizer(
      script: TextRecognitionScript.japanese,
    );
    unawaited(_loadCabinet());
    unawaited(_loadHistory());
    unawaited(_loadDatasetMetadata());
  }

  Future<void> _loadDatasetMetadata() async {
    try {
      final metadata = await _dbHelper.loadDatasetMetadata();
      if (!mounted) return;
      setState(() {
        _datasetMetadata = metadata;
        _statusMessage =
            '官方藥品資料已就緒：${metadata['medicine_count'] ?? '未知'} 筆（${metadata['snapshot_date'] ?? '日期不明'}）';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _statusMessage = '藥品資料初始化失敗，請重新啟動 App 後再試。';
      });
    }
  }

  Future<void> _loadHistory() async {
    final saved = await _historyStorage.loadHistory();
    if (!mounted) return;
    setState(() {
      _medicationHistory
        ..clear()
        ..addAll(saved);
    });
  }

  Future<void> _loadCabinet() async {
    final saved = await _storage.loadCabinet();
    if (!mounted) return;
    setState(() {
      _myCabinet
        ..clear()
        ..addAll(saved);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _symptomController.dispose();
    _chineseRecognizer.close();
    _japaneseRecognizer.close();
    super.dispose();
  }

  void _manualSearch(String value) {
    setState(() {
      _scannedQuantity = null;
      _scannedImagePath = null;
      _lastRecognizedText = null;
    });
    unawaited(_performSearch(value.trim()));
  }

  Future<void> _performSearch(String query, {String? imagePath}) async {
    if (query.trim().isEmpty) return;
    if (imagePath != null) _scannedImagePath = imagePath;

    setState(() {
      _isLoading = true;
      _statusMessage = '正在分析文字與搜尋資料庫...';
      _controller.text = query.length > 120 ? query.substring(0, 120) : query;
    });

    try {
      final keywords = MedicineSearchRanker.extractKeywords(query);

      final unique = <String, Map<String, dynamic>>{};

      for (final keyword in keywords) {
        final results = <Map<String, dynamic>>[
          ...await _dbHelper.searchMedicine(keyword),
          ...await _dbHelper.searchJapaneseMedicine(keyword),
        ];
        for (final medicine in results) {
          final name = _medicineName(medicine);
          unique[name] = medicine;
        }
      }

      final combined =
          unique.values
              .map((medicine) => Map<String, dynamic>.from(medicine))
              .toList()
            ..sort((a, b) {
              final scoreComparison = MedicineSearchRanker.score(
                b,
                keywords,
              ).compareTo(MedicineSearchRanker.score(a, keywords));
              return scoreComparison != 0
                  ? scoreComparison
                  : _medicineName(a).compareTo(_medicineName(b));
            });

      if (!mounted) return;
      setState(() {
        _searchResults = combined;
        _isLoading = false;
        _statusMessage = combined.isEmpty
            ? '找不到符合的藥品，請嘗試較短的藥名或症狀關鍵字。'
            : '搜尋完成，共找到 ${combined.length} 筆結果。';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _statusMessage = '搜尋發生錯誤：$error';
      });
    }
  }

  Future<void> _getAndScanImage(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        imageQuality: 95,
        requestFullMetadata: false,
      );
      if (image == null || !mounted) return;

      setState(() {
        _isLoading = true;
        _statusMessage = '正在進行中／日文 OCR...';
        _controller.clear();
        _searchResults = [];
        _scannedQuantity = null;
        _scannedImagePath = image.path;
        _lastRecognizedText = null;
      });

      final input = InputImage.fromFilePath(image.path);
      final results = await Future.wait([
        _chineseRecognizer.processImage(input),
        _japaneseRecognizer.processImage(input),
      ]);
      final text =
          '${results[0].text.replaceAll('\n', ' ')} ${results[1].text.replaceAll('\n', ' ')}';

      if (!mounted) return;
      if (text.trim().isEmpty) {
        setState(() {
          _isLoading = false;
          _statusMessage = '畫面上找不到清晰文字，請重新拍攝。';
        });
        return;
      }

      setState(() {
        _scannedQuantity = OcrQuantityParser.extractQuantity(text);
        _lastRecognizedText = text.trim().replaceAll(RegExp(r'\s+'), ' ');
      });
      await _performSearch(text, imagePath: image.path);
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _statusMessage = _imagePickerErrorMessage(error, source);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _statusMessage = 'OCR 辨識暫時失敗，請換一張清楚、光線均勻的照片再試。';
      });
    }
  }

  String _imagePickerErrorMessage(PlatformException error, ImageSource source) {
    const deniedCodes = {
      'camera_access_denied',
      'camera_access_denied_without_prompt',
      'camera_access_restricted',
      'photo_access_denied',
      'photo_access_denied_without_prompt',
    };
    if (deniedCodes.contains(error.code)) {
      return source == ImageSource.camera
          ? '無法使用相機，請到系統設定允許相機權限。'
          : '無法讀取相簿，請到系統設定允許照片權限。';
    }
    return source == ImageSource.camera
        ? '相機暫時無法使用，請稍後再試或改從相簿選取。'
        : '相簿暫時無法使用，請稍後再試。';
  }

  Future<void> _addToCabinet(Map<String, dynamic> medicine) async {
    final boxController = TextEditingController(text: '1');
    DateTime? expiryDate;
    String? validationMessage;
    var isSaving = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('新增庫存批次'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: boxController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _scannedQuantity != null
                        ? '購買盒數（每盒 $_scannedQuantity 單位）'
                        : '總顆數／包數',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event),
                  title: Text(
                    expiryDate == null
                        ? '選擇包裝上的有效期限'
                        : '有效期限：${_formatDate(expiryDate!)}',
                  ),
                  subtitle: const Text('為避免誤用過期藥品，此欄必填'),
                  onTap: isSaving
                      ? null
                      : () async {
                          final selected = await showDatePicker(
                            context: dialogContext,
                            initialDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 3650),
                            ),
                          );
                          if (selected != null) {
                            setDialogState(() {
                              expiryDate = selected;
                              validationMessage = null;
                            });
                          }
                        },
                ),
                if (validationMessage != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      validationMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final input = int.tryParse(boxController.text);
                      if (input == null || input <= 0 || expiryDate == null) {
                        setDialogState(() {
                          validationMessage = expiryDate == null
                              ? '請選擇有效期限'
                              : '數量必須是大於 0 的整數';
                        });
                        return;
                      }

                      setDialogState(() => isSaving = true);
                      final quantity = _scannedQuantity == null
                          ? input
                          : input * _scannedQuantity!;
                      final expiry = _dateOnlyIso(expiryDate!);
                      final name = _medicineName(medicine);
                      final updated = _myCabinet
                          .map(Map<String, dynamic>.from)
                          .toList();
                      final index = updated.indexWhere(
                        (item) =>
                            _medicineName(item) == name &&
                            item['expiry_date'] == expiry,
                      );

                      try {
                        if (index >= 0) {
                          final current =
                              (updated[index]['quantity'] as num?)?.toInt() ??
                              0;
                          updated[index]['quantity'] = current + quantity;
                        } else {
                          final inventoryId = DateTime.now()
                              .microsecondsSinceEpoch
                              .toString();
                          final storedImagePath = await _persistScannedImage(
                            inventoryId,
                          );
                          updated.add(
                            Map<String, dynamic>.from(medicine)
                              ..['inventory_id'] = inventoryId
                              ..['quantity'] = quantity
                              ..['expiry_date'] = expiry
                              ..['image_path'] = storedImagePath,
                          );
                        }

                        await _storage.saveCabinet(updated);
                        if (!mounted) return;
                        setState(() {
                          _myCabinet
                            ..clear()
                            ..addAll(updated);
                        });
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                      } catch (_) {
                        setDialogState(() {
                          isSaving = false;
                          validationMessage = '儲存失敗，庫存未變更，請稍後再試';
                        });
                      }
                    },
              child: isSaving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('確定進貨'),
            ),
          ],
        ),
      ),
    );
    boxController.dispose();
  }

  Future<String?> _persistScannedImage(String inventoryId) async {
    final sourcePath = _scannedImagePath;
    if (sourcePath == null || sourcePath.isEmpty) return null;
    final source = File(sourcePath);
    if (!await source.exists()) return null;

    final documentsDirectory = await getApplicationDocumentsDirectory();
    final imageDirectory = Directory(
      path.join(documentsDirectory.path, 'cabinet_images'),
    );
    await imageDirectory.create(recursive: true);
    final extension = path.extension(sourcePath).toLowerCase();
    final destination = File(
      path.join(imageDirectory.path, '$inventoryId$extension'),
    );
    return (await source.copy(destination.path)).path;
  }

  Widget _buildCabinetManagerView() {
    final expiredCount = _myCabinet
        .where(
          (item) =>
              InventoryStatus.expirationStatus(item) ==
              ExpirationStatus.expired,
        )
        .length;
    final expiringSoonCount = _myCabinet
        .where(
          (item) =>
              InventoryStatus.expirationStatus(item) ==
              ExpirationStatus.expiringSoon,
        )
        .length;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: '輸入藥品或症狀，或使用 OCR 掃描',
              border: const OutlineInputBorder(),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: '從相簿辨識',
                    icon: const Icon(Icons.photo_library),
                    onPressed: () => _getAndScanImage(ImageSource.gallery),
                  ),
                  IconButton(
                    tooltip: '拍照辨識',
                    icon: const Icon(Icons.camera_alt),
                    onPressed: () => _getAndScanImage(ImageSource.camera),
                  ),
                ],
              ),
            ),
            onSubmitted: _manualSearch,
          ),
          const SizedBox(height: 10),
          Text(_statusMessage),
          if (_lastRecognizedText != null) ...[
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading:
                    _scannedImagePath != null &&
                        File(_scannedImagePath!).existsSync()
                    ? Image.file(
                        File(_scannedImagePath!),
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      )
                    : const Icon(Icons.document_scanner_outlined),
                title: Text(
                  _scannedQuantity == null
                      ? '最近 OCR 辨識文字'
                      : '最近 OCR 辨識文字｜包裝數量 $_scannedQuantity',
                ),
                subtitle: Text(
                  _lastRecognizedText!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: _showRecognizedText,
              ),
            ),
          ],
          if (expiredCount > 0 || expiringSoonCount > 0) ...[
            const SizedBox(height: 8),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.warning_amber),
                title: const Text('庫存效期提醒'),
                subtitle: Text(
                  '已過期 $expiredCount 批、30 天內到期 $expiringSoonCount 批',
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    children: [
                      if (_searchResults.isNotEmpty) ...[
                        Text(
                          '搜尋結果',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        ..._searchResults.map(
                          (medicine) => Card(
                            child: ListTile(
                              leading: const Icon(Icons.medication),
                              title: Text(_medicineName(medicine)),
                              subtitle: Text(
                                '${medicine['藥品類別'] ?? '分類未標示'}｜${medicine['permit_number'] ?? '許可證未標示'}\n'
                                '成分：${medicine['主成分略述'] ?? medicine['ingredients'] ?? '無'}',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              isThreeLine: true,
                              onTap: () => _showMedicineDetails(medicine),
                              trailing: IconButton.filledTonal(
                                tooltip: '放入藥櫃',
                                onPressed: () => _addToCabinet(medicine),
                                icon: const Icon(Icons.add),
                              ),
                            ),
                          ),
                        ),
                        const Divider(height: 32),
                      ],
                      Text(
                        '目前庫存',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (_myCabinet.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(child: Text('藥櫃目前是空的')),
                        )
                      else
                        ..._myCabinet.map(_buildCabinetItem),
                    ],
                  ),
          ),
          Text('目前藥櫃共有 ${_myCabinet.length} 個庫存批次'),
        ],
      ),
    );
  }

  Widget _buildCabinetItem(Map<String, dynamic> medicine) {
    final status = InventoryStatus.expirationStatus(medicine);
    final quantity = (medicine['quantity'] as num?)?.toInt() ?? 0;
    return Card(
      child: ListTile(
        leading: _medicineImage(medicine),
        title: Text(_medicineName(medicine)),
        subtitle: Text('庫存：$quantity 單位\n${_expiryLabel(medicine)}'),
        isThreeLine: true,
        onTap: () => _showMedicineDetails(medicine),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _statusChip(status, medicine),
            IconButton(
              tooltip: '移除此批次',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _removeCabinetItem(medicine),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSymptomMatchView() {
    var recommended = _myCabinet.toList();
    if (_symptomQuery.isNotEmpty) {
      recommended = _myCabinet.where((medicine) {
        final indications = (medicine['適應症'] ?? medicine['indications'] ?? '')
            .toString();
        return indications.contains(_symptomQuery) ||
            _medicineName(medicine).contains(_symptomQuery);
      }).toList();
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _symptomController,
            decoration: const InputDecoration(
              labelText: '輸入症狀關鍵字（如：頭痛、發燒、流鼻水）',
              helperText: '僅做文字篩選，不是診斷或醫療建議。',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _symptomQuery = value.trim()),
          ),
          const SizedBox(height: 8),
          Card(
            child: const ListTile(
              leading: Icon(Icons.health_and_safety_outlined),
              title: Text('使用前請確認包裝與專業指示'),
              subtitle: Text('結果只做庫存文字篩選，不提供診斷、劑量或交互作用判定。'),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: recommended.isEmpty
                ? const Center(child: Text('目前沒有符合條件的藥櫃項目'))
                : ListView.builder(
                    itemCount: recommended.length,
                    itemBuilder: (context, index) {
                      final medicine = recommended[index];
                      final quantity =
                          (medicine['quantity'] as num?)?.toInt() ?? 0;
                      final expirationStatus = InventoryStatus.expirationStatus(
                        medicine,
                      );
                      final isSelected = _pillsToTake.contains(medicine);
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _medicineImage(medicine),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _medicineName(medicine),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  FilledButton.tonal(
                                    onPressed:
                                        quantity <= 0 ||
                                            expirationStatus ==
                                                ExpirationStatus.expired ||
                                            expirationStatus ==
                                                ExpirationStatus.unknown
                                        ? null
                                        : () => _selectMedicine(medicine),
                                    child: Text(isSelected ? '取消選擇' : '加入紀錄'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '適用症狀：${medicine['適應症'] ?? medicine['indications'] ?? '無特別標示'}',
                              ),
                              Text('藥櫃庫存：$quantity 單位'),
                              Text(_expiryLabel(medicine)),
                              Text(
                                '許可資料：${medicine['藥品類別'] ?? '未標示'}｜${medicine['permit_number'] ?? '未標示'}',
                              ),
                              if (expirationStatus == ExpirationStatus.expired)
                                Text(
                                  '此批次已過期，禁止選擇服用',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              if (expirationStatus == ExpirationStatus.unknown)
                                Text(
                                  '此批次缺少有效期限，請確認包裝後重新入庫',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: () =>
                                      _showMedicineDetails(medicine),
                                  icon: const Icon(Icons.description_outlined),
                                  label: const Text('查看官方許可資料'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_pillsToTake.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.check_circle_outline),
                label: Text(
                  _isConfirmingMedication
                      ? '正在儲存...'
                      : '記錄已服用（${_pillsToTake.length} 款，各 1 單位）',
                ),
                onPressed: _isConfirmingMedication ? null : _confirmMedication,
              ),
            ),
        ],
      ),
    );
  }

  void _selectMedicine(Map<String, dynamic> medicine) {
    final status = InventoryStatus.expirationStatus(medicine);
    if (status == ExpirationStatus.expired ||
        status == ExpirationStatus.unknown) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('此批次已過期或缺少有效期限，不能加入服藥清單')));
      return;
    }

    if (_pillsToTake.contains(medicine)) {
      setState(() => _pillsToTake.remove(medicine));
      return;
    }

    final warning = DuplicateIngredientChecker.checkDuplicate(
      _pillsToTake,
      medicine,
    );
    if (warning != null) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('重複有效成分警告'),
          content: Text(warning),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
      return;
    }
    setState(() => _pillsToTake.add(medicine));
  }

  Future<void> _confirmMedication() async {
    if (_isConfirmingMedication || _pillsToTake.isEmpty) return;
    setState(() => _isConfirmingMedication = true);

    final lowStock = <String>[];
    final takenAt = DateTime.now().toIso8601String();
    final historyEntries = <Map<String, dynamic>>[];
    final updatedCabinet = _myCabinet.map(Map<String, dynamic>.from).toList();

    for (final pill in _pillsToTake) {
      final index = _myCabinet.indexWhere((item) => identical(item, pill));
      if (index < 0) continue;

      final current = (updatedCabinet[index]['quantity'] as num?)?.toInt() ?? 0;
      final status = InventoryStatus.expirationStatus(updatedCabinet[index]);
      if (current <= 0 ||
          status == ExpirationStatus.expired ||
          status == ExpirationStatus.unknown) {
        continue;
      }

      final next = current > 0 ? current - 1 : 0;
      updatedCabinet[index]['quantity'] = next;
      historyEntries.add({
        'medicine_name': _medicineName(updatedCabinet[index]),
        'ingredients':
            updatedCabinet[index]['主成分略述'] ??
            updatedCabinet[index]['ingredients'] ??
            '',
        'quantity': 1,
        'taken_at': takenAt,
      });
      if (next < 3) lowStock.add(_medicineName(updatedCabinet[index]));
    }

    if (historyEntries.isEmpty) {
      if (!mounted) return;
      setState(() => _isConfirmingMedication = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('沒有可記錄的有效庫存，請重新選擇')));
      return;
    }

    final persistedHistory = await _historyStorage.loadHistory();
    final updatedHistory = [...historyEntries, ...persistedHistory];

    var cabinetSaved = false;
    try {
      await _storage.saveCabinet(updatedCabinet);
      cabinetSaved = true;
      await _historyStorage.saveHistory(updatedHistory);
    } catch (_) {
      if (cabinetSaved) {
        try {
          await _storage.saveCabinet(_myCabinet);
        } catch (_) {
          // The user is informed below; a later reload reflects persisted state.
        }
      }
      if (!mounted) return;
      setState(() => _isConfirmingMedication = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('儲存失敗，畫面與庫存未變更，請再試一次')));
      return;
    }

    if (!mounted) return;
    setState(() {
      _myCabinet
        ..clear()
        ..addAll(updatedCabinet);
      _medicationHistory
        ..clear()
        ..addAll(updatedHistory);
      _pillsToTake.clear();
      _isConfirmingMedication = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          lowStock.isEmpty ? '已記錄服藥並扣除庫存' : '低庫存：${lowStock.join('、')}',
        ),
      ),
    );
  }

  Future<void> _removeCabinetItem(Map<String, dynamic> medicine) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('移除庫存批次？'),
        content: Text(
          '將移除「${_medicineName(medicine)}」效期 ${_expiryDateText(medicine)} 的整批庫存。此動作無法復原。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('確認移除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final updated = _myCabinet
        .where((item) => !identical(item, medicine))
        .toList();
    try {
      await _storage.saveCabinet(updated);
      if (!mounted) return;
      setState(() {
        _myCabinet
          ..clear()
          ..addAll(updated);
        _pillsToTake.removeWhere((item) => identical(item, medicine));
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('移除失敗，庫存未變更')));
      return;
    }

    try {
      await _deleteStoredImage(medicine);
    } catch (_) {
      // The inventory is already removed. A stale private image can be safely
      // cleaned up by the operating system later without reporting data loss.
    }
  }

  Future<void> _deleteStoredImage(Map<String, dynamic> medicine) async {
    final imagePath = medicine['image_path']?.toString() ?? '';
    if (imagePath.isEmpty) return;

    final documentsDirectory = await getApplicationDocumentsDirectory();
    final allowedDirectory = path.normalize(
      path.absolute(path.join(documentsDirectory.path, 'cabinet_images')),
    );
    final normalizedImagePath = path.normalize(path.absolute(imagePath));
    if (!path.isWithin(allowedDirectory, normalizedImagePath)) return;

    final image = File(normalizedImagePath);
    if (await image.exists()) await image.delete();
  }

  Widget _statusChip(ExpirationStatus status, Map<String, dynamic> medicine) {
    final colorScheme = Theme.of(context).colorScheme;
    final (label, color) = switch (status) {
      ExpirationStatus.expired => ('已過期', colorScheme.errorContainer),
      ExpirationStatus.expiringSoon => ('即將到期', colorScheme.tertiaryContainer),
      ExpirationStatus.unknown => ('缺少效期', colorScheme.errorContainer),
      ExpirationStatus.valid when InventoryStatus.isLowStock(medicine) => (
        '低庫存',
        colorScheme.secondaryContainer,
      ),
      ExpirationStatus.valid => ('效期正常', colorScheme.primaryContainer),
    };
    return Chip(label: Text(label), backgroundColor: color);
  }

  String _expiryLabel(Map<String, dynamic> medicine) {
    return '有效期限：${_expiryDateText(medicine)}';
  }

  String _expiryDateText(Map<String, dynamic> medicine) {
    final expiry = DateTime.tryParse(medicine['expiry_date']?.toString() ?? '');
    return expiry == null ? '未設定' : _formatDate(expiry);
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  String _dateOnlyIso(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Widget _buildMedicationHistoryView() {
    if (_medicationHistory.isEmpty) {
      return const Center(child: Text('尚無服藥紀錄'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _medicationHistory.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = _medicationHistory[index];
        final takenAt = DateTime.tryParse(entry['taken_at']?.toString() ?? '');
        final timeText = takenAt == null
            ? '時間不明'
            : '${takenAt.year}/${takenAt.month.toString().padLeft(2, '0')}/${takenAt.day.toString().padLeft(2, '0')} '
                  '${takenAt.hour.toString().padLeft(2, '0')}:${takenAt.minute.toString().padLeft(2, '0')}';
        return Card(
          child: ListTile(
            leading: const Icon(Icons.history),
            title: Text(entry['medicine_name']?.toString() ?? '未知藥品'),
            subtitle: Text('$timeText\n成分：${entry['ingredients'] ?? '無'}'),
            isThreeLine: true,
            trailing: Text('${entry['quantity'] ?? 1} 單位'),
          ),
        );
      },
    );
  }

  Future<void> _clearMedicationHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清除全部服藥紀錄？'),
        content: const Text('這只會清除服藥紀錄，不會改變目前庫存。此動作無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('確認清除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _historyStorage.saveHistory([]);
      if (!mounted) return;
      setState(_medicationHistory.clear);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('服藥紀錄已清除')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('清除失敗，紀錄未變更')));
    }
  }

  void _showDatasetInformation() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('藥品資料來源'),
        content: SingleChildScrollView(
          child: Text(
            '${_datasetMetadata['title'] ?? '衛福部食藥署藥品許可證資料'}\n\n'
            '資料快照：${_datasetMetadata['snapshot_date'] ?? '載入中'}\n'
            '筆數：${_datasetMetadata['medicine_count'] ?? '載入中'}\n'
            '篩選規則：${_datasetMetadata['selection_rule'] ?? '載入中'}\n\n'
            '${_datasetMetadata['medical_disclaimer'] ?? '請核對實體包裝並諮詢醫師或藥師。'}\n\n'
            '資料集：${_datasetMetadata['dataset_page'] ?? 'https://data.gov.tw/dataset/9122'}\n'
            '授權：${_datasetMetadata['license'] ?? '政府資料開放授權條款－第1版'}',
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  void _showRecognizedText() {
    final text = _lastRecognizedText;
    if (text == null) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('OCR 辨識文字'),
        content: SingleChildScrollView(child: SelectableText(text)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }

  void _showMedicineDetails(Map<String, dynamic> medicine) {
    String value(String key, [String? fallbackKey]) {
      final raw =
          medicine[key] ?? (fallbackKey == null ? null : medicine[fallbackKey]);
      final text = raw?.toString().trim() ?? '';
      return text.isEmpty ? '未標示' : text;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_medicineName(medicine)),
        content: SingleChildScrollView(
          child: SelectableText(
            '英文品名：${value('英文品名')}\n'
            '許可證字號：${value('permit_number')}\n'
            '藥品類別：${value('藥品類別')}\n'
            '劑型：${value('劑型')}\n'
            '成分：${value('主成分略述', 'ingredients')}\n'
            '適應症：${value('適應症', 'indications')}\n'
            '用法用量：${value('用法用量', 'dosage')}\n'
            '許可證有效日期：${value('許可證有效日期')}\n'
            '申請商：${value('申請商名稱')}\n'
            '包裝：${value('包裝')}\n\n'
            '以上是資料快照中的官方許可欄位，不是個人化醫療建議。請核對實體包裝與最新官方資料，並依醫師或藥師指示使用。',
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }

  Widget _medicineImage(Map<String, dynamic> medicine) {
    final path = medicine['image_path']?.toString();
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      return Image.file(File(path), width: 45, height: 45, fit: BoxFit.cover);
    }
    return const Icon(Icons.medication, size: 45);
  }

  String _medicineName(Map<String, dynamic> medicine) {
    return (medicine['中文品名'] ?? medicine['chinese_name'] ?? '未知藥品').toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (_currentIndex) {
          0 => '智慧藥櫃',
          1 => '症狀篩選',
          _ => '服藥紀錄',
        }),
        actions: [
          IconButton(
            tooltip: '藥品資料來源',
            onPressed: _showDatasetInformation,
            icon: const Icon(Icons.info_outline),
          ),
          if (_currentIndex == 2 && _medicationHistory.isNotEmpty)
            IconButton(
              tooltip: '清除全部服藥紀錄',
              onPressed: _clearMedicationHistory,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: switch (_currentIndex) {
        0 => _buildCabinetManagerView(),
        1 => _buildSymptomMatchView(),
        _ => _buildMedicationHistoryView(),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.all_inbox), label: '藥櫃管理'),
          NavigationDestination(
            icon: Icon(Icons.medical_information_outlined),
            label: '症狀篩選',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: '服藥紀錄'),
        ],
      ),
    );
  }
}
