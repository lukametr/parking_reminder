import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/parking_zone.dart';

class ParkingDatabase {
  static final ParkingDatabase _instance = ParkingDatabase._internal();
  factory ParkingDatabase() => _instance;
  ParkingDatabase._internal();

  Database? _database;

  // ბაზის გახსნა
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  // ბაზის ინიციალიზაცია
  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'parking_database.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  // ცხრილების შექმნა
  Future<void> _createDB(Database db, int version) async {
    // პარკინგის ზონების ცხრილი
    await db.execute('''
      CREATE TABLE parking_zones(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        radius REAL NOT NULL,
        is_paid INTEGER NOT NULL,
        description TEXT,
        price_per_hour REAL,
        created_at TEXT
      )
    ''');

    // პარკინგის ისტორიის ცხრილი
    await db.execute('''
      CREATE TABLE parking_history(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        zone_id TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT,
        duration_minutes INTEGER,
        cost REAL,
        FOREIGN KEY (zone_id) REFERENCES parking_zones (id)
      )
    ''');

    // დემო მონაცემების დამატება
    await _insertDemoData(db);
  }

  // დემო მონაცემები
  Future<void> _insertDemoData(Database db) async {
    List<Map<String, dynamic>> demoZones = [
      {
        'id': 'zone_001',
        'name': 'რუსთაველის მოედანი',
        'latitude': 41.6935,
        'longitude': 44.8015,
        'radius': 200.0,
        'is_paid': 1,
        'description': 'ცენტრალური ფასიანი პარკინგი',
        'price_per_hour': 2.5,
        'created_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'zone_002', 
        'name': 'თბილისის მერია',
        'latitude': 41.6928,
        'longitude': 44.8001,
        'radius': 150.0,
        'is_paid': 1,
        'description': 'მერიის მიმდებარე პარკინგი',
        'price_per_hour': 2.0,
        'created_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'zone_003',
        'name': 'ვაკის პარკი',
        'latitude': 41.7185,
        'longitude': 44.7756,
        'radius': 300.0,
        'is_paid': 0,
        'description': 'უფასო პარკინგი',
        'price_per_hour': null,
        'created_at': DateTime.now().toIso8601String(),
      },
    ];

    for (var zone in demoZones) {
      await db.insert('parking_zones', zone);
    }
  }

  // ყველა პარკინგის ზონის მიღება
  Future<List<ParkingZone>> getParkingZones() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('parking_zones');
    
    return List.generate(maps.length, (i) {
      return ParkingZone.fromMap(maps[i]);
    });
  }

  // ზონის მიღება ID-ით
  Future<ParkingZone?> getParkingZoneById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'parking_zones',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return ParkingZone.fromMap(maps.first);
    }
    return null;
  }

  // ახალი ზონის დამატება
  Future<void> insertParkingZone(ParkingZone zone) async {
    final db = await database;
    await db.insert('parking_zones', zone.toMap());
  }

  // ზონის განახლება
  Future<void> updateParkingZone(ParkingZone zone) async {
    final db = await database;
    await db.update(
      'parking_zones',
      zone.toMap(),
      where: 'id = ?',
      whereArgs: [zone.id],
    );
  }

  // ზონის წაშლა
  Future<void> deleteParkingZone(String id) async {
    final db = await database;
    await db.delete(
      'parking_zones',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ბაზის დახურვა
  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
