import 'dart:io';

import 'package:flutter/services.dart';
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
      'smart_medicine_cabinet.db',
    );

    if (!await File(databasePath).exists()) {
      final data = await rootBundle.load('assets/smart_medicine_cabinet.db');
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      await File(databasePath).writeAsBytes(bytes, flush: true);
    }

    return openDatabase(databasePath);
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
