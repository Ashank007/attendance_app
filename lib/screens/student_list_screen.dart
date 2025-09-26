import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../helpers/database_helper.dart';
import '../models/student_model.dart';
import 'add_student_screen.dart';
import 'take_attendance_screen.dart';

class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  late Future<Map<String, dynamic>> _dashboardData;

  @override
  void initState() {
    super.initState();
    _dashboardData = _getDashboardData();
  }

  void _refreshData() {
    setState(() {
      _dashboardData = _getDashboardData();
    });
  }

  Future<Map<String, dynamic>> _getDashboardData() async {
    final dbHelper = DatabaseHelper.instance;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final results = await Future.wait([
      dbHelper.getStudents(),
      dbHelper.getStudentCount(),
      dbHelper.isAttendanceTakenToday(today),
    ]);

    return {
      'students': results[0] as List<Student>,
      'studentCount': results[1] as int,
      'isAttendanceTaken': results[2] as bool,
    };
  }

  void _exportToCsv() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          child: Wrap(
            children: <Widget>[
              const ListTile(
                title: Text('Choose Export Option', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.fiber_new_rounded, color: Colors.purple),
                title: const Text('Export Latest Session'),
                onTap: () {
                  Navigator.pop(context);
                  _onExportOptionSelected('latest');
                },
              ),
              ListTile(
                leading: const Icon(Icons.today),
                title: const Text('Export Today\'s Attendance'),
                onTap: () {
                  Navigator.pop(context);
                  _onExportOptionSelected('today');
                },
              ),
              ListTile(
                leading: const Icon(Icons.view_week),
                title: const Text('Export This Week\'s Attendance'),
                onTap: () {
                  Navigator.pop(context);
                  _onExportOptionSelected('week');
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month),
                title: const Text('Export This Month\'s Attendance'),
                onTap: () {
                  Navigator.pop(context);
                  _onExportOptionSelected('month');
                },
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Export Full History'),
                onTap: () {
                  Navigator.pop(context);
                  _onExportOptionSelected('all');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _onExportOptionSelected(String option) async {
    List<Map<String, dynamic>> data;
    String fileName = 'attendance_report';

    switch (option) {
      case 'latest':
        data = await DatabaseHelper.instance.getLatestSessionReport();
        if (data.isNotEmpty) {
          final sessionName = data.first['sessionName'].toString().replaceAll(' ', '_');
          final sessionDate = data.first['date'];
          fileName = 'session_${sessionName}_${sessionDate}';
        } else {
          fileName = 'latest_session';
        }
        break;
      case 'today':
        final now = DateTime.now();
        final date = DateFormat('yyyy-MM-dd').format(now);
        data = await DatabaseHelper.instance.getAttendanceReportForDateRange(date, date);
        fileName = 'attendance_today_${date}';
        break;
      case 'week':
        final now = DateTime.now();
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 6));
        final startDate = DateFormat('yyyy-MM-dd').format(weekStart);
        final endDate = DateFormat('yyyy-MM-dd').format(weekEnd);
        data = await DatabaseHelper.instance.getAttendanceReportForDateRange(startDate, endDate);
        fileName = 'attendance_week_${startDate}';
        break;
      case 'month':
        final now = DateTime.now();
        final monthStart = DateTime(now.year, now.month, 1);
        final monthEnd = DateTime(now.year, now.month + 1, 0);
        final startDate = DateFormat('yyyy-MM-dd').format(monthStart);
        final endDate = DateFormat('yyyy-MM-dd').format(monthEnd);
        data = await DatabaseHelper.instance.getAttendanceReportForDateRange(startDate, endDate);
        fileName = 'attendance_month_${now.month}-${now.year}';
        break;
      case 'all':
      default:
        data = await DatabaseHelper.instance.getAttendanceReport();
        fileName = 'full_attendance_history';
        break;
    }
    
    await _generateAndShareCsv(data, fileName);
  }

  Future<void> _generateAndShareCsv(List<Map<String, dynamic>> data, String fileName) async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }
    
    if (status.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating CSV report...')),
      );

      if (data.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No attendance records found for this period!')),
        );
        return;
      }

      List<List<dynamic>> rows = [];
      rows.add(['Roll Number', 'Name', 'Date', 'Time', 'Session Name', 'Status']);
      for (var row in data) {
        rows.add([row['rollNumber'], row['name'], row['date'], row['time'], row['sessionName'], row['status']]);
      }

      final directory = await getExternalStorageDirectory();
      final path = "${directory?.path}/${fileName}_${DateTime.now().millisecondsSinceEpoch}.csv";
      final File file = File(path);

      String csv = const ListToCsvConverter().convert(rows);
      await file.writeAsString(csv);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report generated successfully!')),
      );
      await Share.shareXFiles([XFile(path)], text: 'Here is the attendance report.');
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Storage permission is required to export data.')),
      );
    }
  }
  
  void _importFromCsv() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final path = file.path;

      if (path == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get file path.')),
        );
        return;
      }

      final fileContent = await File(path).readAsString();
      final cleanContent = fileContent.replaceAll('\r', '');
      final List<List<dynamic>> csvTable = const CsvToListConverter(eol: '\n').convert(cleanContent);

      List<Student> studentsToInsert = [];
      for (var i = 1; i < csvTable.length; i++) {
        final row = csvTable[i];
        if (row.length >= 2) {
          studentsToInsert.add(Student(rollNumber: row[0].toString().trim(), name: row[1].toString().trim()));
        }
      }

      if (studentsToInsert.isNotEmpty) {
        await DatabaseHelper.instance.insertStudentsInBatch(studentsToInsert);
        _refreshData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully imported ${studentsToInsert.length} students!')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid students found in the CSV file.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error importing file: $e')));
    }
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not launch $url')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.upload_file), tooltip: 'Import Students from CSV', onPressed: _importFromCsv),
          IconButton(icon: const Icon(Icons.download), tooltip: 'Export All Attendance to CSV', onPressed: _exportToCsv),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dashboardData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return _buildEmptyState();
          }

          final data = snapshot.data!;
          final List<Student> students = data['students'];
          final int studentCount = data['studentCount'];
          final bool isAttendanceTaken = data['isAttendanceTaken'];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSummaryItem('Total Students', '$studentCount', Icons.people_rounded, Colors.blue),
                        _buildSummaryItem('Today\'s Status', isAttendanceTaken ? 'Taken' : 'Pending', isAttendanceTaken ? Icons.check_circle_rounded : Icons.pending_actions_rounded, isAttendanceTaken ? Colors.green : Colors.orange),
                      ],
                    ),
                  ),
                ),
              ),
              
              if (students.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.edit_calendar_rounded),
                    label: const Text("Take Today's Attendance"),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => TakeAttendanceScreen(students: students)),
                      ).then((_) => _refreshData());
                    },
                  ),
                ),
              
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text("Student List", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              
              Expanded(
                child: students.isEmpty
                    ? _buildEmptyState()
                    : AnimationLimiter(
                        child: ListView.builder(
                          itemCount: students.length,
                          itemBuilder: (context, index) {
                            final student = students[index];
                            return AnimationConfiguration.staggeredList(
                              position: index,
                              duration: const Duration(milliseconds: 375),
                              child: SlideAnimation(
                                verticalOffset: 50.0,
                                child: FadeInAnimation(
                                  child: Card(
                                    elevation: 2,
                                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                        child: Text('${index + 1}'),
                                      ),
                                      title: Text(student.name),
                                      subtitle: Text('Roll No: ${student.rollNumber}'),
                                      trailing: PopupMenuButton(
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                          const PopupMenuItem(value: 'delete', child: Text('Delete')),
                                        ],
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            Navigator.push(context, MaterialPageRoute(builder: (context) => AddStudentScreen(student: student))).then((_) => _refreshData());
                                          } else if (value == 'delete') {
                                            showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text('Confirm Delete'),
                                                content: Text('Are you sure you want to delete ${student.name}?'),
                                                actions: [
                                                  TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop()),
                                                  TextButton(
                                                    child: const Text('Delete'),
                                                    onPressed: () async {
                                                      await DatabaseHelper.instance.deleteStudent(student.id!);
                                                      Navigator.of(context).pop();
                                                      _refreshData();
                                                      if (!mounted) return;
                                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${student.name} deleted')));
                                                    },
                                                  ),
                                                ],
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add Student',
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddStudentScreen()));
          _refreshData();
        },
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: Container(
        height: 50,
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        child: InkWell(
          onTap: () {
            _launchURL('https://github.com/ashank007'); 
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Developed by Ashank Gupta 💻 | ',
                style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface),
              ),
              Text(
                'GitHub',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Text(title, style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_rounded, size: 80, color: Theme.of(context).colorScheme.secondary),
            const SizedBox(height: 16),
            const Text('No Students Found', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Click the + button to add a student manually\nor use the import button at the top.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

