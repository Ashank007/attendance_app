class Student {
  final int? id;
  final String rollNumber;
  final String name;
  String status;

  Student({this.id, required this.rollNumber, required this.name,this.status = 'Present'});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rollNumber': rollNumber,
      'name': name,
    };
  }
}
