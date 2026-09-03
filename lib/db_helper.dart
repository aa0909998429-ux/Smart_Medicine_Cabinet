import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static const datasetAsset = 'assets/data/tfda_common_drugs.json';
  static const databaseVersion = 2;

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
      version: databaseVersion,
      onCreate: _createDatabase,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('DROP TABLE IF EXISTS medicines');
          await db.execute('DROP TABLE IF EXISTS japanese_medicines');
          await db.execute('DROP TABLE IF EXISTS dataset_metadata');
          await _createDatabase(db, newVersion);
        }
      },
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE medicines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        permit_number TEXT NOT NULL UNIQUE,
        中文品名 TEXT NOT NULL,
        英文品名 TEXT,
        主成分略述 TEXT,
        適應症 TEXT,
        用法用量 TEXT,
        藥品類別 TEXT,
        劑型 TEXT,
        包裝 TEXT,
        許可證有效日期 TEXT,
        申請商名稱 TEXT,
        包裝與國際條碼 TEXT,
        aliases TEXT,
        source_url TEXT NOT NULL
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

    await db.execute('''
      CREATE TABLE dataset_metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await _importTfdaDataset(db);
  }

  Future<void> _importTfdaDataset(Database db) async {
    final raw = await rootBundle.loadString(datasetAsset);
    final payload = jsonDecode(raw) as Map<String, dynamic>;
    final metadata = Map<String, dynamic>.from(payload['metadata'] as Map);
    final medicines = (payload['medicines'] as List).whereType<Map>();
    final sourceUrl = metadata['source_url']?.toString() ?? '';

    var batch = db.batch();
    var pending = 0;
    for (final rawMedicine in medicines) {
      final medicine = Map<String, dynamic>.from(rawMedicine);
      final aliases =
          (medicine['aliases'] as List?)
              ?.map((value) => value.toString())
              .join(' ') ??
          '';
      batch.insert('medicines', {
        'permit_number': medicine['permit_number'],
        '中文品名': medicine['chinese_name'],
        '英文品名': medicine['english_name'],
        '主成分略述': medicine['ingredients'],
        '適應症': medicine['indications'],
        '用法用量': medicine['dosage'],
        '藥品類別': medicine['category'],
        '劑型': medicine['dosage_form'],
        '包裝': medicine['packaging'],
        '許可證有效日期': medicine['license_expiry_date'],
        '申請商名稱': medicine['applicant_name'],
        '包裝與國際條碼': medicine['barcodes'],
        'aliases': aliases,
        'source_url': sourceUrl,
      });
      pending++;

      if (pending >= 400) {
        await batch.commit(noResult: true);
        batch = db.batch();
        pending = 0;
      }
    }
    if (pending > 0) await batch.commit(noResult: true);

    final metadataBatch = db.batch();
    for (final entry in metadata.entries) {
      metadataBatch.insert('dataset_metadata', {
        'key': entry.key,
        'value': entry.value.toString(),
      });
    }
    await metadataBatch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> searchMedicine(String keyword) async {
    final db = await database;
    final pattern = '%${keyword.trim()}%';

    return db.query(
      'medicines',
      where:
          '中文品名 LIKE ? OR 英文品名 LIKE ? OR aliases LIKE ? OR permit_number LIKE ? OR 主成分略述 LIKE ? OR 適應症 LIKE ?',
      whereArgs: [pattern, pattern, pattern, pattern, pattern, pattern],
      orderBy: '中文品名 COLLATE NOCASE',
      limit: 20,
    );
  }

  Future<List<Map<String, dynamic>>> searchMedicineBySymptom(String symptom) {
    return searchMedicine(symptom);
  }

  Future<List<Map<String, dynamic>>> searchJapaneseMedicine(
    String keyword,
  ) async {
    return const [];
  }

  Future<Map<String, String>> loadDatasetMetadata() async {
    final db = await database;
    final rows = await db.query('dataset_metadata');
    return {
      for (final row in rows) row['key'].toString(): row['value'].toString(),
    };
  }
}
