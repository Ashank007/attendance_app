import 'package:flutter/material.dart';
import '../helpers/database_helper.dart';
import '../models/student_model.dart';

class AddStudentScreen extends StatefulWidget {
  final Student? student;
  
  const AddStudentScreen({super.key, this.student});

  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>(); // Form validation ke liye
  final _rollNumberController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    if (widget.student != null) {
      _isEditMode = true;
      _rollNumberController.text = widget.student!.rollNumber;
      _nameController.text = widget.student!.name;
    }
  }

  void _saveStudent() async {
    // Form ko validate karo
    if (_formKey.currentState!.validate()) {
      if (_isEditMode) {
        final updatedStudent = Student(
          id: widget.student!.id,
          rollNumber: _rollNumberController.text,
          name: _nameController.text,
        );
        await DatabaseHelper.instance.updateStudent(updatedStudent);
      } else {
        final newStudent = Student(
          rollNumber: _rollNumberController.text,
          name: _nameController.text,
        );
        await DatabaseHelper.instance.addStudent(newStudent);
      }
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Student Details' : 'Add New Student'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 20),
              // --- YEH TEXTFIELD UPDATE HUA HAI ---
              TextFormField(
                controller: _rollNumberController,
                decoration: InputDecoration(
                  labelText: 'Roll Number',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a roll number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              // --- YEH TEXTFIELD BHI UPDATE HUA HAI ---
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const Spacer(), // Yeh saare content ko upar push karega
              // --- YEH BUTTON UPDATE HUA HAI ---
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveStudent,
                  icon: Icon(_isEditMode ? Icons.edit_note_rounded : Icons.person_add_alt_1_rounded),
                  label: Text(_isEditMode ? 'Update Student' : 'Save Student'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

