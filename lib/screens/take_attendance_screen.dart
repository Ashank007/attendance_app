import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../helpers/database_helper.dart';
import '../models/student_model.dart';

class TakeAttendanceScreen extends StatefulWidget {
  final List<Student> students;
  const TakeAttendanceScreen({super.key, required this.students});

  @override
  State<TakeAttendanceScreen> createState() => _TakeAttendanceScreenState();
}

class _TakeAttendanceScreenState extends State<TakeAttendanceScreen> {
  late List<Student> _students;
  int _presentCount = 0;

  @override
  void initState() {
    super.initState();
    _students = widget.students.map((student) {
      student.status = 'Present';
      return student;
    }).toList();
    _updateCounts();
  }

  void _updateCounts() {
    setState(() {
      _presentCount = _students.where((s) => s.status == 'Present').length;
    });
  }

  void _markAll(String status) {
    setState(() {
      for (var student in _students) {
        student.status = status;
      }
    });
    _updateCounts();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('All students marked as $status.'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // --- SAVE FUNCTION AB DIALOG DIKHAYEGA ---
  void _saveAttendance() async {
    final sessionNameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enter Session Name'),
        content: TextField(
          controller: sessionNameController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g., Maths Class, Physics Lab',
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          TextButton(
            child: const Text('Save'),
            onPressed: () async {
              String sessionName = sessionNameController.text;
              if (sessionName.trim().isEmpty) {
                sessionName = 'General';
              }
              
              String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
              String currentTime = DateFormat('hh:mm a').format(DateTime.now());

              await DatabaseHelper.instance.saveAttendance(_students, sessionName, todayDate, currentTime);
              
              if (mounted) {
                Navigator.of(dialogContext).pop(); // Dialog band karo
                Navigator.of(context).pop(); // Screen band karo
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Attendance for session "$sessionName" saved!')),
                );
              }
            },
          ),
        ],
      ),
    );
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
    final totalStudents = _students.length;
    final absentCount = totalStudents - _presentCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Take Attendance'),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.check_circle_outline_rounded), tooltip: 'Mark All Present', onPressed: () => _markAll('Present')),
          IconButton(icon: const Icon(Icons.cancel_outlined), tooltip: 'Mark All Absent', onPressed: () => _markAll('Absent')),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildCounter('Total', totalStudents, Colors.blue),
                    _buildCounter('Present', _presentCount, Colors.green),
                    _buildCounter('Absent', absentCount, Colors.red),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: totalStudents > 0 ? _presentCount / totalStudents : 0,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimationLimiter(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: _students.length,
                itemBuilder: (context, index) {
                  final student = _students[index];
                  final isPresent = student.status == 'Present';
                  return AnimationConfiguration.staggeredList(
                    position: index,
                    duration: const Duration(milliseconds: 375),
                    child: SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(
                        child: Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isPresent ? Colors.green.withOpacity(0.5) : Colors.red.withOpacity(0.5),
                              width: 1.5,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                              child: Text('${index + 1}'),
                            ),
                            title: Text(student.name),
                            subtitle: Text('Roll No: ${student.rollNumber}'),
                            trailing: ToggleButtons(
                              isSelected: [isPresent, !isPresent],
                              onPressed: (int newIndex) {
                                setState(() {
                                  student.status = newIndex == 0 ? 'Present' : 'Absent';
                                });
                                _updateCounts();
                              },
                              selectedColor: Colors.white,
                              fillColor: isPresent ? Colors.green : Colors.red,
                              borderRadius: BorderRadius.circular(8.0),
                              constraints: const BoxConstraints(minHeight: 36, minWidth: 50),
                              children: const [Text('P'), Text('A')],
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveAttendance,
        icon: const Icon(Icons.save_alt_rounded),
        label: const Text('Save Attendance'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
              Text('Developed by Ashank Gupta 💻 | ', style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface)),
              Text('GitHub', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCounter(String title, int count, Color color) {
    return Column(
      children: [
        Text('$count', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
      ],
    );
  }
}

