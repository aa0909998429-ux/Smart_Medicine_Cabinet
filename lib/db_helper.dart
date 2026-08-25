import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // 1. 取得手機的內部儲存路徑
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, "smart_medicine_cabinet.db");

    // 2. 檢查手機裡是不是已經有這個資料庫了
    bool dbExists = await File(path).exists();

    if (!dbExists) {
      // 3. 如果沒有，就從 assets 裡面複製過去
      print("正在從 Assets 複製資料庫到手機本機...");
      ByteData data = await rootBundle.load(join("assets", "smart_medicine_cabinet.db"));
      List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

      await File(path).writeAsBytes(bytes, flush: true);
      print("資料庫複製完成！");
    }

    // 4. 打開並回傳資料庫連線
    return await openDatabase(path);
  }

  // ⭐️ 這就是你們用來「對症下藥」的核心搜尋功能！
  Future<List<Map<String, dynamic>>> searchMedicineBySymptom(String symptom) async {
    Database db = await database;

    // 用 SQL 的 LIKE 語法，去「適應症」欄位裡面模糊搜尋
    // 這裡的回傳結果會包含藥品的中英文名稱、成分和用法
    List<Map<String, dynamic>> results = await db.query(
      'medicines',
      where: '適應症 LIKE ?',
      whereArgs: ['%$symptom%'],
      limit: 10, // 怕結果太多，先限制回傳前 10 筆
    );
    return results;
  }
  // ⭐️ 專屬日本神藥的搜尋功能
  Future<List<Map<String, dynamic>>> searchJapaneseMedicine(String keyword) async {
    Database db = await database;

    // 用 SQL 的 LIKE 語法，同時去「日文品名」、「中文俗稱」和「適應症」裡面找
    List<Map<String, dynamic>> results = await db.query(
      'japanese_medicines', // 注意！這裡是去查我們剛建好的日本專屬表
      where: 'japanese_name LIKE ? OR chinese_name LIKE ? OR indications LIKE ?',
      whereArgs: ['%$keyword%', '%$keyword%', '%$keyword%'],
    );
    return results;
  }
}
