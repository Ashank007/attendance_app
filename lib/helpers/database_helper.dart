import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/student_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('attendance_v2.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rollNumber TEXT NOT NULL,
        name TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE attendance_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sessionName TEXT NOT NULL,
        date TEXT NOT NULL,
        time TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        studentId INTEGER NOT NULL,
        sessionId INTEGER NOT NULL,
        status TEXT NOT NULL,
        FOREIGN KEY (studentId) REFERENCES students (id) ON DELETE CASCADE,
        FOREIGN KEY (sessionId) REFERENCES attendance_sessions (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> addStudent(Student student) async {
    final db = await instance.database;
    await db.insert('students', student.toMap());
  }

  Future<List<Student>> getStudents() async {
    final db = await instance.database;
    final result = await db.query('students', orderBy: 'rollNumber');
    return result.map((json) => Student(
      id: json['id'] as int,
      rollNumber: json['rollNumber'] as String,
      name: json['name'] as String,
    )).toList();
  }
  
  Future<int> updateStudent(Student student) async {
    final db = await instance.database;
    return await db.update('students', student.toMap(), where: 'id = ?', whereArgs: [student.id]);
  }

  Future<int> deleteStudent(int id) async {
    final db = await instance.database;
    return await db.delete('students', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> insertStudentsInBatch(List<Student> students) async {
    final db = await instance.database;
    Batch batch = db.batch();
    for (var student in students) {
      var studentMap = student.toMap();
      studentMap.remove('id');
      batch.insert('students', studentMap);
    }
    await batch.commit(noResult: true);
  }

  Future<int> getStudentCount() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM students');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<bool> isAttendanceTakenToday(String date) async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM attendance_sessions WHERE date = ?', [date]);
    int? count = Sqflite.firstIntValue(result);
    return count != null && count > 0;
  }

  Future<void> saveAttendance(List<Student> students, String sessionName, String date, String time) async {
    final db = await instance.database;

    int sessionId = await db.insert('attendance_sessions', {
      'sessionName': sessionName,
      'date': date,
      'time': time,
    });

    Batch batch = db.batch();
    for (var student in students) {
      batch.insert('attendance', {
        'studentId': student.id,
        'sessionId': sessionId,
        'status': student.status,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getAttendanceReport() async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT s.rollNumber, s.name, ses.date, ses.time, ses.sessionName, a.status
      FROM attendance a
      INNER JOIN students s ON s.id = a.studentId
      INNER JOIN attendance_sessions ses ON ses.id = a.sessionId
      ORDER BY ses.date DESC, ses.time DESC, s.rollNumber
    ''');
    return result;
  }

  Future<List<Map<String, dynamic>>> getAttendanceReportForDateRange(String startDate, String endDate) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT s.rollNumber, s.name, ses.date, ses.time, ses.sessionName, a.status
      FROM attendance a
      INNER JOIN students s ON s.id = a.studentId
      INNER JOIN attendance_sessions ses ON ses.id = a.sessionId
      WHERE ses.date BETWEEN ? AND ?
      ORDER BY ses.date DESC, ses.time DESC, s.rollNumber
    ''', [startDate, endDate]);
    return result;
  }

  // --- YEH NAYA FUNCTION HAI ---
  Future<List<Map<String, dynamic>>> getLatestSessionReport() async {
    final db = await instance.database;
    // Yeh query aakhri session ki ID dhoond kar sirf usi ka data laati hai
    final result = await db.rawQuery('''
      SELECT s.rollNumber, s.name, ses.date, ses.time, ses.sessionName, a.status
      FROM attendance a
      INNER JOIN students s ON s.id = a.studentId
      INNER JOIN attendance_sessions ses ON ses.id = a.sessionId
      WHERE a.sessionId = (SELECT MAX(id) FROM attendance_sessions)
      ORDER BY s.rollNumber
    ''');
    return result;
  }
}

