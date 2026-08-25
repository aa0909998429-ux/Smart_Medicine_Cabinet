import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import 'db_helper.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '智慧藥櫃',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const SymptomSearchScreen(),
    );
  }
}

class SymptomSearchScreen extends StatefulWidget {
  const SymptomSearchScreen({super.key});

  @override
  State<SymptomSearchScreen> createState() => _SymptomSearchScreenState();
}

class _SymptomSearchScreenState extends State<SymptomSearchScreen> {
  final _controller = TextEditingController();
  final _clinicController = TextEditingController();
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
  String _clinicSearchQuery = '';
  String _statusMessage = '等待測試...';
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
    _clinicController.dispose();
    _chineseRecognizer.close();
    _japaneseRecognizer.close();
    super.dispose();
  }

  int _levenshteinDistance(String s, String t) {
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;
    final d = List.generate(s.length + 1, (_) => List.filled(t.length + 1, 0));
    for (var i = 0; i <= s.length; i++) d[i][0] = i;
    for (var j = 0; j <= t.length; j++) d[0][j] = j;
    for (var i = 1; i <= s.length; i++) {
      for (var j = 1; j <= t.length; j++) {
        final cost = s[i - 1] == t[j - 1] ? 0 : 1;
        final values = [d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost];
        d[i][j] = values.reduce((a, b) => a < b ? a : b);
      }
    }
    return d[s.length][t.length];
  }

  int? _extractQuantityFromText(String text) {
    const validUnits = ['顆', '粒', '錠', '包', '丸', '片'];
    final matches = RegExp(r'(\d+)\s*([^\x00-\x7F\s]{1,2})').allMatches(text);
    for (final match in matches) {
      final unit = match.group(2)!;
      for (final validUnit in validUnits) {
        if (_levenshteinDistance(unit, validUnit) <= 1) {
          return int.tryParse(match.group(1)!);
        }
      }
    }
    final reverse = RegExp(r'(?:錠剤|錠劑|容量|內容)[^\d]*(\d+)', caseSensitive: false).firstMatch(text);
    return reverse == null ? null : int.tryParse(reverse.group(1)!);
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
      final pureText = query.replaceAll(RegExp(r'[^a-zA-Z0-9\u4E00-\u9FA5\u3040-\u30FF\s]'), ' ');
      final cleanQuery = pureText.replaceAll(RegExp(r'錠剤|錠劑|製薬|製藥|容量|內容|毫克|公克|膠囊|錠|丸|包'), ' ');
      final keywords = cleanQuery.split(RegExp(r'\s+')).where((e) => e.trim().length >= 2);
      final unique = <String, Map<String, dynamic>>{};
      final scores = <String, int>{};

      for (var keyword in keywords) {
        keyword = keyword.replaceAll('薬', '藥').replaceAll('剤', '劑');
        final results = <Map<String, dynamic>>[
          ...await _dbHelper.searchMedicineBySymptom(keyword),
          ...await _dbHelper.searchJapaneseMedicine(keyword),
        ];
        for (final med in results) {
          final name = (med['中文品名'] ?? med['chinese_name'] ?? med.toString()).toString();
          unique[name] = med;
          scores[name] = (scores[name] ?? 0) + 1;
        }
      }

      final combined = unique.values.map((e) => Map<String, dynamic>.from(e)).toList()
        ..sort((a, b) {
          final aName = (a['中文品名'] ?? a['chinese_name'] ?? a.toString()).toString();
          final bName = (b['中文品名'] ?? b['chinese_name'] ?? b.toString()).toString();
          return (scores[bName] ?? 0).compareTo(scores[aName] ?? 0);
        });

      if (!mounted) return;
      setState(() {
        _searchResults = combined;
        _isLoading = false;
        _statusMessage = '搜尋完成，共找到 ${combined.length} 筆成藥。';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _statusMessage = '❌ 發生錯誤: $e';
      });
    }
  }

  Future<void> _getAndScanImage(ImageSource source) async {
    final image = await _picker.pickImage(source: source);
    if (image == null) return;
    setState(() {
      _isLoading = true;
      _statusMessage = '🧠 正在進行終端影像文字辨識 (OCR)...';
    });
    try {
      final input = InputImage.fromFilePath(image.path);
      final results = await Future.wait([
        _chineseRecognizer.processImage(input),
        _japaneseRecognizer.processImage(input),
      ]);
      final text = '${results[0].text.replaceAll('\n', ' ')} ${results[1].text.replaceAll('\n', ' ')}';
      if (text.trim().isEmpty) {
        setState(() {
          _isLoading = false;
          _statusMessage = '⚠️ 畫面上找不到清晰的文字，請再試一次。';
        });
        return;
      }
      setState(() => _scannedQuantity = _extractQuantityFromText(text));
      await _performSearch(text, imagePath: image.path);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _statusMessage = '❌ 辨識發生錯誤: $e';
      });
    }
  }

  void _addToCabinet(Map<String, dynamic> medicine) {
    final boxController = TextEditingController(text: '1');
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📦 輸入購入數量'),
        content: TextField(
          controller: boxController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: _scannedQuantity != null ? '請輸入購買盒數（單盒 $_scannedQuantity 單位）' : '請輸入總顆數/包數',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              final input = int.tryParse(boxController.text) ?? 1;
              final quantity = _scannedQuantity == null ? input : input * _scannedQuantity!;
              final name = medicine['中文品名'] ?? medicine['chinese_name'] ?? '未知藥品';
              final index = _myCabinet.indexWhere((m) => (m['中文品名'] ?? m['chinese_name']) == name);
              setState(() {
                if (index >= 0) {
                  _myCabinet[index]['quantity'] = (_myCabinet[index]['quantity'] ?? 0) + quantity;
                } else {
                  final newMed = Map<String, dynamic>.from(medicine)
                    ..['quantity'] = quantity
                    ..['image_path'] = _scannedImagePath;
                  _myCabinet.add(newMed);
                }
              });
              Navigator.pop(context);
            },
            child: const Text('確定進貨'),
          ),
        ],
      ),
    );
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
                  IconButton(icon: const Icon(Icons.photo_library), onPressed: () => _getAndScanImage(ImageSource.gallery)),
                  IconButton(icon: const Icon(Icons.camera_alt), onPressed: () => _getAndScanImage(ImageSource.camera)),
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
                      final med = _searchResults[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.medication),
                          title: Text((med['中文品名'] ?? med['chinese_name'] ?? '未知藥品').toString()),
                          subtitle: Text('成分：${med['主成分略述'] ?? med['ingredients'] ?? '無'}'),
                          trailing: ElevatedButton(onPressed: () => _addToCabinet(med), child: const Text('放入藥櫃')),
                        ),
                      );
                    },
                  ),
          ),
          Text('🏠 目前我家藥櫃共有 ${_myCabinet.length} 款常備藥品'),
        ],
      ),
    );
  }

  Widget _buildAiClinicView() {
    var recommended = _myCabinet.toList();
    if (_clinicSearchQuery.isNotEmpty) {
      recommended = _myCabinet.where((med) {
        final indications = (med['適應症'] ?? med['indications'] ?? '').toString();
        final name = (med['中文品名'] ?? med['chinese_name'] ?? '').toString();
        return indications.contains(_clinicSearchQuery) || name.contains(_clinicSearchQuery);
      }).toList();
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _clinicController,
            decoration: const InputDecoration(
              labelText: '請描述症狀（如：頭痛、發燒、流鼻水）',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.medical_services),
            ),
            onChanged: (value) => setState(() => _clinicSearchQuery = value.trim()),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: recommended.length,
              itemBuilder: (context, index) {
                final med = recommended[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (med['image_path'] != null && File(med['image_path']).existsSync())
                              Image.file(File(med['image_path']), width: 45, height: 45, fit: BoxFit.cover)
                            else
                              const Icon(Icons.medication, size: 45),
                            const SizedBox(width: 10),
                            Expanded(child: Text((med['中文品名'] ?? med['chinese_name'] ?? '未知藥品').toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
                            ElevatedButton(
                              onPressed: () {
                                final warning = InteractionChecker.checkConflict(_pillsToTake, med);
                                if (warning != null) {
                                  showDialog<void>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('⚠️ 混合服藥危險警告'),
                                      content: Text(warning),
                                      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消'))],
                                    ),
                                  );
                                } else {
                                  setState(() => _pillsToTake.add(med));
                                }
                              },
                              child: const Text('吃這款'),
                            ),
                          ],
                        ),
                        Text('🎯 適用症狀: ${med['適應症'] ?? med['indications'] ?? '無特別標示'}'),
                        Text('📦 藥櫃庫存: ${med['quantity'] ?? 0} 單位'),
                        Text('💊 怎麼吃: ${med['用法用量'] ?? med['dosage'] ?? '請參閱包裝或醫師指示'}'),
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
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('確認服藥（自動扣除庫存）'),
                onPressed: () {
                  final lowStock = <String>[];
                  setState(() {
                    for (final pill in _pillsToTake) {
                      final index = _myCabinet.indexWhere((m) => identical(m, pill));
                      if (index >= 0) {
                        _myCabinet[index]['quantity'] = (_myCabinet[index]['quantity'] ?? 1) - 1;
                        if ((_myCabinet[index]['quantity'] ?? 0) < 3) {
                          lowStock.add((_myCabinet[index]['中文品名'] ?? _myCabinet[index]['chinese_name'] ?? '未知藥品').toString());
                        }
                      }
                    }
                    _pillsToTake.clear();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(lowStock.isEmpty ? '💊 已記錄服藥並扣除庫存' : '⚠️ 低庫存：${lowStock.join('、')}')),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_currentIndex == 0 ? '📦 Edge AI 智慧藥櫃' : '🏥 AI 智能問診助理')),
      body: _currentIndex == 0 ? _buildCabinetManagerView() : _buildAiClinicView(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.all_inbox), label: '藥櫃管理'),
          BottomNavigationBarItem(icon: Icon(Icons.psychology), label: '智能問診'),
        ],
      ),
    );
  }
}

class InteractionChecker {
  static const highRiskIngredients = ['ACETAMINOPHEN', 'IBUPROFEN', 'ASPIRIN'];

  static String? checkConflict(List<Map<String, dynamic>> currentPillbox, Map<String, dynamic> newMedicine) {
    if (currentPillbox.isEmpty) return null;
    final newIngredients = (newMedicine['主成分略述'] ?? newMedicine['ingredients'] ?? '').toString().toUpperCase();
    final newName = (newMedicine['中文品名'] ?? newMedicine['chinese_name'] ?? '未知藥品').toString();

    for (final existing in currentPillbox) {
      final existingIngredients = (existing['主成分略述'] ?? existing['ingredients'] ?? '').toString().toUpperCase();
      final existingName = (existing['中文品名'] ?? existing['chinese_name'] ?? '未知藥品').toString();
      for (final ingredient in highRiskIngredients) {
        if (newIngredients.contains(ingredient) && existingIngredients.contains(ingredient)) {
          return '⚠️ 嚴重警告！\n\n「$newName」與「$existingName」皆含有：$ingredient\n\n同時服用可能造成成分重複，請先諮詢醫師或藥師。';
        }
      }
    }
    return null;
  }
}
