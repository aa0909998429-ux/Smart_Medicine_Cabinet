import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../db_helper.dart';
import '../services/duplicate_ingredient_checker.dart';
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
  final _picker = ImagePicker();

  late final TextRecognizer _chineseRecognizer;
  late final TextRecognizer _japaneseRecognizer;

  List<Map<String, dynamic>> _searchResults = [];
  final List<Map<String, dynamic>> _myCabinet = [];
  final List<Map<String, dynamic>> _pillsToTake = [];

  int _currentIndex = 0;
  int? _scannedQuantity;
  String? _scannedImagePath;
  String _symptomQuery = '';
  String _statusMessage = '輸入關鍵字或掃描藥盒開始搜尋';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _chineseRecognizer = TextRecognizer(script: TextRecognitionScript.chinese);
    _japaneseRecognizer = TextRecognizer(script: TextRecognitionScript.japanese);
  }

  @override
  void dispose() {
    _controller.dispose();
    _symptomController.dispose();
    _chineseRecognizer.close();
    _japaneseRecognizer.close();
    super.dispose();
  }

  Future<void> _performSearch(String query, {String? imagePath}) async {
    if (query.trim().isEmpty) return;
    if (imagePath != null) _scannedImagePath = imagePath;

    setState(() {
      _isLoading = true;
      _statusMessage = '正在分析文字與搜尋資料庫...';
      _controller.text = query;
    });

    try {
      final pureText = query.replaceAll(
        RegExp(r'[^a-zA-Z0-9\u4E00-\u9FA5\u3040-\u30FF\s]'),
        ' ',
      );
      final cleanQuery = pureText.replaceAll(
        RegExp(r'錠剤|錠劑|製薬|製藥|容量|內容|内容|毫克|公克|膠囊|錠|丸|包'),
        ' ',
      );
      final keywords = cleanQuery
          .split(RegExp(r'\s+'))
          .where((value) => value.trim().length >= 2);

      final unique = <String, Map<String, dynamic>>{};
      final scores = <String, int>{};

      for (var keyword in keywords) {
        keyword = keyword.replaceAll('薬', '藥').replaceAll('剤', '劑');
        final results = <Map<String, dynamic>>[
          ...await _dbHelper.searchMedicine(keyword),
          ...await _dbHelper.searchJapaneseMedicine(keyword),
        ];

        for (final medicine in results) {
          final name = _medicineName(medicine);
          unique[name] = medicine;
          scores[name] = (scores[name] ?? 0) + 1;
        }
      }

      final combined = unique.values
          .map((medicine) => Map<String, dynamic>.from(medicine))
          .toList()
        ..sort((a, b) =>
            (scores[_medicineName(b)] ?? 0)
                .compareTo(scores[_medicineName(a)] ?? 0));

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
    final image = await _picker.pickImage(source: source);
    if (image == null || !mounted) return;

    setState(() {
      _isLoading = true;
      _statusMessage = '正在進行中／日文 OCR...';
    });

    try {
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
      });
      await _performSearch(text, imagePath: image.path);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _statusMessage = 'OCR 辨識發生錯誤：$error';
      });
    }
  }

  Future<void> _addToCabinet(Map<String, dynamic> medicine) async {
    final boxController = TextEditingController(text: '1');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('輸入購入數量'),
        content: TextField(
          controller: boxController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: _scannedQuantity != null
                ? '購買盒數（每盒 $_scannedQuantity 單位）'
                : '總顆數／包數',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final input = int.tryParse(boxController.text);
              if (input == null || input <= 0) return;

              final quantity = _scannedQuantity == null
                  ? input
                  : input * _scannedQuantity!;
              final name = _medicineName(medicine);
              final index = _myCabinet.indexWhere(
                (item) => _medicineName(item) == name,
              );

              setState(() {
                if (index >= 0) {
                  final current = (_myCabinet[index]['quantity'] as num?)?.toInt() ?? 0;
                  _myCabinet[index]['quantity'] = current + quantity;
                } else {
                  _myCabinet.add(
                    Map<String, dynamic>.from(medicine)
                      ..['quantity'] = quantity
                      ..['image_path'] = _scannedImagePath,
                  );
                }
              });
              Navigator.pop(dialogContext);
            },
            child: const Text('確定進貨'),
          ),
        ],
      ),
    );
    boxController.dispose();
  }

  Widget _buildCabinetManagerView() {
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
            onSubmitted: (value) => _performSearch(value.trim()),
          ),
          const SizedBox(height: 10),
          Text(_statusMessage),
          const SizedBox(height: 10),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final medicine = _searchResults[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.medication),
                          title: Text(_medicineName(medicine)),
                          subtitle: Text(
                            '成分：${medicine['主成分略述'] ?? medicine['ingredients'] ?? '無'}',
                          ),
                          trailing: FilledButton.tonal(
                            onPressed: () => _addToCabinet(medicine),
                            child: const Text('放入藥櫃'),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Text('目前藥櫃共有 ${_myCabinet.length} 款藥品'),
        ],
      ),
    );
  }

  Widget _buildSymptomMatchView() {
    var recommended = _myCabinet.toList();
    if (_symptomQuery.isNotEmpty) {
      recommended = _myCabinet.where((medicine) {
        final indications =
            (medicine['適應症'] ?? medicine['indications'] ?? '').toString();
        final name = _medicineName(medicine);
        return indications.contains(_symptomQuery) || name.contains(_symptomQuery);
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
                                    onPressed: quantity <= 0
                                        ? null
                                        : () => _selectMedicine(medicine),
                                    child: const Text('選擇服用'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '適用症狀：${medicine['適應症'] ?? medicine['indications'] ?? '無特別標示'}',
                              ),
                              Text('藥櫃庫存：$quantity 單位'),
                              Text(
                                '用法資訊：${medicine['用法用量'] ?? medicine['dosage'] ?? '請參閱包裝或醫師／藥師指示'}',
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
                label: Text('確認服藥（${_pillsToTake.length} 款）'),
                onPressed: _confirmMedication,
              ),
            ),
        ],
      ),
    );
  }

  void _selectMedicine(Map<String, dynamic> medicine) {
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

  void _confirmMedication() {
    final lowStock = <String>[];
    setState(() {
      for (final pill in _pillsToTake) {
        final index = _myCabinet.indexWhere((item) => identical(item, pill));
        if (index < 0) continue;

        final current = (_myCabinet[index]['quantity'] as num?)?.toInt() ?? 0;
        final next = current > 0 ? current - 1 : 0;
        _myCabinet[index]['quantity'] = next;
        if (next < 3) lowStock.add(_medicineName(_myCabinet[index]));
      }
      _pillsToTake.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          lowStock.isEmpty
              ? '已記錄服藥並扣除庫存'
              : '低庫存：${lowStock.join('、')}',
        ),
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
    return (medicine['中文品名'] ?? medicine['chinese_name'] ?? '未知藥品')
        .toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? '智慧藥櫃' : '症狀篩選'),
      ),
      body: _currentIndex == 0
          ? _buildCabinetManagerView()
          : _buildSymptomMatchView(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.all_inbox),
            label: '藥櫃管理',
          ),
          NavigationDestination(
            icon: Icon(Icons.medical_information_outlined),
            label: '症狀篩選',
          ),
        ],
      ),
    );
  }
}
