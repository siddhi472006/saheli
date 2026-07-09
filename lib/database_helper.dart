import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('saheli.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path   = join(dbPath, fileName);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id       INTEGER PRIMARY KEY AUTOINCREMENT,
        name     TEXT NOT NULL,
        username TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        userType TEXT NOT NULL,
        language TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE screenings (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        userId            INTEGER NOT NULL,
        patientName       TEXT    NOT NULL,
        age               INTEGER NOT NULL,
        reason            TEXT    NOT NULL,
        pregnancyWeeks    INTEGER,
        fatigue           INTEGER DEFAULT 0,
        dizziness         INTEGER DEFAULT 0,
        paleSkin          INTEGER DEFAULT 0,
        shortnessOfBreath INTEGER DEFAULT 0,
        heavyPeriods      INTEGER DEFAULT 0,
        headache          INTEGER DEFAULT 0,
        mlScore           REAL    NOT NULL,
        riskScore         REAL    NOT NULL,
        saheliScore       REAL    NOT NULL DEFAULT 0,
        riskLevel         TEXT    NOT NULL,
        clinicalNote      TEXT    NOT NULL,
        imagePath         TEXT,
        pdfPath           TEXT,
        screenedAt        TEXT    NOT NULL,
        FOREIGN KEY (userId) REFERENCES users(id)
      )
    ''');
  }

  // ── USERS ──────────────────────────────────────────────

  Future<int> registerUser({
    required String name,
    required String username,
    required String password,
    required String userType,
    required String language,
  }) async {
    final db = await database;
    try {
      return await db.insert('users', {
        'name':     name,
        'username': username,
        'password': password,
        'userType': userType,
        'language': language,
      });
    } catch (e) {
      return -1; // username already taken
    }
  }

  Future<Map<String, dynamic>?> loginUser({
    required String username,
    required String password,
  }) async {
    final db     = await database;
    final result = await db.query(
      'users',
      where:     'username = ? AND password = ?',
      whereArgs: [username, password],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<Map<String, dynamic>?> getUserById(int id) async {
    final db     = await database;
    final result = await db.query(
      'users',
      where:     'id = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty ? result.first : null;
  }

  // ── SCREENINGS ─────────────────────────────────────────

  Future<int> saveScreening({
    required int    userId,
    required String patientName,
    required int    age,
    required String reason,
    int?            pregnancyWeeks,
    required double mlScore,
    required double riskScore,
    required double saheliScore,
    required String riskLevel,
    required String clinicalNote,
    String?         imagePath,
    Map<String, bool> symptoms = const {},
  }) async {
    final db = await database;
    return await db.insert('screenings', {
      'userId':            userId,
      'patientName':       patientName,
      'age':               age,
      'reason':            reason,
      'pregnancyWeeks':    pregnancyWeeks,
      'fatigue':           (symptoms['fatigue']           ?? false) ? 1 : 0,
      'dizziness':         (symptoms['dizziness']         ?? false) ? 1 : 0,
      'paleSkin':          (symptoms['paleSkin']          ?? false) ? 1 : 0,
      'shortnessOfBreath': (symptoms['shortnessOfBreath'] ?? false) ? 1 : 0,
      'heavyPeriods':      (symptoms['heavyPeriods']      ?? false) ? 1 : 0,
      'headache':          (symptoms['headache']          ?? false) ? 1 : 0,
      'mlScore':           mlScore,
      'riskScore':         riskScore,
      'riskLevel':         riskLevel,
      'clinicalNote':      clinicalNote,
      'imagePath':         imagePath,
      'saheliScore':       saheliScore, 
      'screenedAt':        DateTime.now().toIso8601String(),
    });
  }

  Future<void> updatePdfPath(int screeningId, String pdfPath) async {
    final db = await database;
    await db.update(
      'screenings',
      {'pdfPath': pdfPath},
      where:     'id = ?',
      whereArgs: [screeningId],
    );
  }

  Future<void> deleteScreening(int id) async {
    final db = await database;
    await db.delete('screenings', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getScreeningsByUser(int userId) async {
    final db = await database;
    return await db.query(
      'screenings',
      where:   'userId = ?',
      whereArgs: [userId],
      orderBy: 'screenedAt DESC',
    );
  }

  Future<Map<String, dynamic>> getStats(int userId) async {
    final db       = await database;
    final all      = await db.query('screenings', where: 'userId = ?', whereArgs: [userId]);
    final total    = all.length;
    final high     = all.where((s) => s['riskLevel'] == 'high').length;
    final moderate = all.where((s) => s['riskLevel'] == 'moderate' || s['riskLevel'] == 'borderline').length;
    final low      = all.where((s) => s['riskLevel'] == 'low').length;
    return {'total': total, 'high': high, 'moderate': moderate, 'low': low};

  }
  Future<List<Map<String, dynamic>>> getScreeningsByPatientName({
  required int userId,
  required String patientName,
}) async {
  final db = await database;
  return await db.query(
    'screenings',
    where: 'userId = ? AND patientName = ?',
    whereArgs: [userId, patientName],
    orderBy: 'screenedAt ASC',
  );
}
}