import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final databasePath = join(
      documentsDirectory.path,
      'smart_medicine_cabinet_demo.db',
    );

    return openDatabase(
      databasePath,
      version: 1,
      onCreate: _createDemoDatabase,
    );
  }

  Future<void> _createDemoDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE medicines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        中文品名 TEXT NOT NULL,
        英文品名 TEXT,
        主成分略述 TEXT,
        適應症 TEXT,
        用法用量 TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE japanese_medicines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        japanese_name TEXT NOT NULL,
        chinese_name TEXT,
        ingredients TEXT,
        indications TEXT,
        dosage TEXT
      )
    ''');

    final batch = db.batch();
    batch.insert('medicines', {
      '中文品名': '示範退燒止痛錠 A',
      '英文品名': 'Demo Fever & Pain Tablet A',
      '主成分略述': 'ACETAMINOPHEN 500 MG',
      '適應症': '示範資料：頭痛、發燒',
      '用法用量': '示範資料，請勿作為醫療建議',
    });
    batch.insert('medicines', {
      '中文品名': '示範止痛錠 B',
      '英文品名': 'Demo Pain Tablet B',
      '主成分略述': 'IBUPROFEN 200 MG',
      '適應症': '示範資料：頭痛、肌肉痠痛',
      '用法用量': '示範資料，請勿作為醫療建議',
    });
    batch.insert('medicines', {
      '中文品名': '示範感冒錠 C',
      '英文品名': 'Demo Cold Tablet C',
      '主成分略述': 'ACETAMINOPHEN 250 MG',
      '適應症': '示範資料：感冒不適、頭痛',
      '用法用量': '示範資料，請勿作為醫療建議',
    });
    batch.insert('japanese_medicines', {
      'japanese_name': 'デモかぜ薬A',
      'chinese_name': '示範日本感冒藥 A',
      'ingredients': 'DEMO INGREDIENT',
      'indications': '示範資料：感冒不適',
      'dosage': '示範資料，請勿作為醫療建議',
    });
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> searchMedicine(String keyword) async {
    final db = await database;
    final pattern = '%${keyword.trim()}%';

    return db.query(
      'medicines',
      where: '中文品名 LIKE ? OR 英文品名 LIKE ? OR 主成分略述 LIKE ? OR 適應症 LIKE ?',
      whereArgs: [pattern, pattern, pattern, pattern],
      limit: 20,
    );
  }

  Future<List<Map<String, dynamic>>> searchMedicineBySymptom(
    String symptom,
  ) {
    return searchMedicine(symptom);
  }

  Future<List<Map<String, dynamic>>> searchJapaneseMedicine(
    String keyword,
  ) async {
    final db = await database;
    final pattern = '%${keyword.trim()}%';

    return db.query(
      'japanese_medicines',
      where: 'japanese_name LIKE ? OR chinese_name LIKE ? OR ingredients LIKE ? OR indications LIKE ?',
      whereArgs: [pattern, pattern, pattern, pattern],
      limit: 20,
    );
  }
}
