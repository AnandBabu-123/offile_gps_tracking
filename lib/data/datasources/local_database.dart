import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../domain/entities/location_record.dart';

class LocalDatabase {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'locations.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE locations(
            id TEXT PRIMARY KEY,
            latitude REAL,
            longitude REAL,
            timestamp INTEGER,
            isSynced INTEGER
          )
        ''');
      },
    );
  }

  Future<void> insertLocation(LocationRecord record) async {
    final db = await database;
    await db.insert('locations', {
      'id': record.id,
      'latitude': record.latitude,
      'longitude': record.longitude,
      'timestamp': record.timestamp.millisecondsSinceEpoch,
      'isSynced': record.isSynced ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<LocationRecord>> getUnsyncedLocations() async {
    final db = await database;
    final maps = await db.query('locations', where: 'isSynced = ?', whereArgs: [0]);

    return maps.map((map) => LocationRecord(
      id: map['id'] as String,
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      isSynced: (map['isSynced'] as int) == 1,
    )).toList();
  }

  Future<void> markAsSynced(String id) async {
    final db = await database;
    await db.update('locations', {'isSynced': 1}, where: 'id = ?', whereArgs: [id]);
  }
  Future<List<LocationRecord>> getAllLocations() async {
    final db = await database;
    final maps = await db.query('locations');

    return maps.map((map) => LocationRecord(
      id: map['id'] as String,
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      isSynced: (map['isSynced'] as int) == 1,
    )).toList();
  }

}