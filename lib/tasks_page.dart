
import 'package:flutter/material.dart';

class Task {
  String title;
  String date;
  String subject;
  bool completed;

  Task(this.title, this.date, this.subject, this.completed);
}

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  List<Task> tasks = [
    Task("Tp2", "Feb 8, 2026", "Entrepôts de données", false), 
    Task("Chapter 5", "Feb 10, 2026", "Technologies et programmation web", false), 
    Task("Tp1", "Feb 12, 2026", "Digital Business Transformation", true), 
    Task("Report", "Feb 7, 2026", "IT Law, Data Protection and Ethics", true), 
    Task("Report", "Feb 7, 2026", "Software Testing", true), 
    Task("Chapter 2", "Feb 7, 2026", "Business Intelligence and Data Analytics", true),
  ];

  @override
  Widget build(BuildContext context) {
    List<Task> pendingTasks = [];
    List<Task> completedTasks = [];

    for (var task in tasks) {
      if (!task.completed) {
        pendingTasks.add(task);
      } else {
        completedTasks.add(task);
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        toolbarHeight: 90,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.edit_note, color: Colors.white, size: 28),
                SizedBox(width: 8),
                Text(
                  "Tasks & Note",
                  style: TextStyle(
                    fontFamily: "Roboto",
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                )
              ],
            ),
            SizedBox(height: 6),
            Text(
              'Stay organized and productive',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            )
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Pending (${pendingTasks.length})",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: pendingTasks.length,
                itemBuilder: (context, index) {
                  return taskCard(pendingTasks[index]);
                },
              ),
              SizedBox(height: 24),
              Text(
                "Completed (${completedTasks.length})",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: completedTasks.length,
                itemBuilder: (context, index) {
                  return taskCard(completedTasks[index]);
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        backgroundColor: Colors.green,
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) {
              final _formKey = GlobalKey<FormState>();
              TextEditingController titleController = TextEditingController();
              TextEditingController dateController = TextEditingController();
              TextEditingController subjectController = TextEditingController();

              return AlertDialog(
                title: Text("Add New Task"),
                content: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: titleController,
                        decoration: InputDecoration(labelText: "Title"),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Enter title";
                          }
                          if (!RegExp(r'^[a-zA-Z0-9 ]+$').hasMatch(value)) {
                            return "Letters, numbers and spaces only";
                          }
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: dateController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: "Deadline",
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Choose date";
                          }
                          return null;
                        },
                        onTap: () async {
                          DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2030),
                          );

                          if (pickedDate != null) {
                            dateController.text =
                                "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
                          }
                        },
                      ),
                      TextFormField(
                        controller: subjectController,
                        decoration: InputDecoration(labelText: "Subject"),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Enter subject";
                          }
                          if (!RegExp(r'^[a-zA-Z ]+$').hasMatch(value)) {
                            return "Letters only";
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text("Cancel"),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        setState(() {
                          tasks.add(Task(
                            titleController.text,
                            dateController.text,
                            subjectController.text,
                            false,
                          ));
                        });
                        Navigator.pop(context);
                      }
                    },
                    child: Text("Add"),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget taskCard(Task task) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 5)],
      ),
      child: Row(
        children: [
          Checkbox(
            value: task.completed,
            onChanged: (value) {
              setState(() {
                task.completed = value!;
              });
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 15,
                    decoration:
                        task.completed ? TextDecoration.lineThrough : null,
                  ),
                ),
                SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                    SizedBox(width: 4),
                    Text(
                      task.date,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  task.subject,
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.grey),
            onPressed: () {
              setState(() {
                tasks.remove(task);
              });
            },
          ),
        ],
      ),
    );
  }
}

