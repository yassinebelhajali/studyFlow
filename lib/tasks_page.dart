import 'package:flutter/material.dart';

import 'domain/models/study_task.dart';
import 'domain/repositories/task_repository.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key, required this.repository});

  final TaskRepository repository;

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  List<StudyTask> _tasks = const [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final tasks = await widget.repository.getTasks();
      if (!mounted) {
        return;
      }
      setState(() {
        _tasks = _sortTasks(tasks);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Unable to load tasks right now.';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveTasks(List<StudyTask> nextTasks) async {
    setState(() {
      _tasks = _sortTasks(nextTasks);
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await widget.repository.saveTasks(_tasks);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Changes were saved locally but sync failed.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _toggleTask(StudyTask task, bool completed) {
    final updatedTasks = _tasks
        .map(
          (item) =>
              item.id == task.id ? item.copyWith(completed: completed) : item,
        )
        .toList(growable: false);
    return _saveTasks(updatedTasks);
  }

  Future<void> _deleteTask(StudyTask task) {
    final updatedTasks = _tasks
        .where((item) => item.id != task.id)
        .toList(growable: false);
    return _saveTasks(updatedTasks);
  }

  Future<void> _openAddTaskDialog() async {
    final task = await showDialog<StudyTask>(
      context: context,
      builder: (context) => const _AddTaskDialog(),
    );

    if (task == null) {
      return;
    }

    await _saveTasks([..._tasks, task]);
  }

  @override
  Widget build(BuildContext context) {
    final pendingTasks = _tasks.where((task) => !task.completed).toList();
    final completedTasks = _tasks.where((task) => task.completed).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        toolbarHeight: 90,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.edit_note, color: Colors.white, size: 28),
                SizedBox(width: 8),
                Text(
                  'Tasks & Note',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _isSaving ? 'Saving changes...' : 'Stay organized and productive',
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadTasks,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_errorMessage != null) ...[
                    _InfoBanner(message: _errorMessage!),
                    const SizedBox(height: 16),
                  ],
                  _SectionHeader(title: 'Pending', count: pendingTasks.length),
                  const SizedBox(height: 12),
                  if (pendingTasks.isEmpty)
                    const _EmptyState(message: 'No pending tasks.')
                  else
                    ...pendingTasks.map(
                      (task) => _TaskCard(
                        task: task,
                        onToggle: (value) => _toggleTask(task, value),
                        onDelete: () => _deleteTask(task),
                      ),
                    ),
                  const SizedBox(height: 24),
                  _SectionHeader(
                    title: 'Completed',
                    count: completedTasks.length,
                  ),
                  const SizedBox(height: 12),
                  if (completedTasks.isEmpty)
                    const _EmptyState(message: 'No completed tasks yet.')
                  else
                    ...completedTasks.map(
                      (task) => _TaskCard(
                        task: task,
                        onToggle: (value) => _toggleTask(task, value),
                        onDelete: () => _deleteTask(task),
                      ),
                    ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        onPressed: _isSaving ? null : _openAddTaskDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  List<StudyTask> _sortTasks(List<StudyTask> tasks) {
    final sorted = List<StudyTask>.from(tasks);
    sorted.sort((a, b) {
      if (a.completed != b.completed) {
        return a.completed ? 1 : -1;
      }
      final dueComparison = a.dueAt.compareTo(b.dueAt);
      if (dueComparison != 0) {
        return dueComparison;
      }
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return sorted;
  }
}

class _AddTaskDialog extends StatefulWidget {
  const _AddTaskDialog();

  @override
  State<_AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<_AddTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _subjectController = TextEditingController();
  DateTime? _dueDate;
  TaskPriority _priority = TaskPriority.medium;

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 18, minute: 0),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _dueDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime?.hour ?? 18,
        pickedTime?.minute ?? 0,
      );
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate() || _dueDate == null) {
      setState(() {});
      return;
    }

    Navigator.of(context).pop(
      StudyTask(
        id: createStudyTaskId(),
        title: _titleController.text.trim(),
        dueAt: _dueDate!,
        subject: _subjectController.text.trim(),
        completed: false,
        priority: _priority,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Task'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter title';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _subjectController,
              decoration: const InputDecoration(labelText: 'Subject'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter subject';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: InputDecoration(
                labelText: 'Priority',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<TaskPriority>(
                  value: _priority,
                  isExpanded: true,
                  items: TaskPriority.values
                      .map(
                        (priority) => DropdownMenuItem<TaskPriority>(
                          value: priority,
                          child: Text(priority.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _priority = value;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDueDate,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Deadline',
                  errorText: _dueDate == null ? 'Choose a deadline' : null,
                  suffixIcon: const Icon(Icons.calendar_today),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  _dueDate == null
                      ? 'Select date and time'
                      : _formatDateTime(_dueDate!),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.onToggle,
    required this.onDelete,
  });

  final StudyTask task;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 5)],
      ),
      child: Row(
        children: [
          Checkbox(
            value: task.completed,
            onChanged: (value) => onToggle(value ?? false),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    decoration: task.completed
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDateTime(task.dueAt),
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  task.subject,
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                _PriorityChip(priority: task.priority),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.grey),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.priority});

  final TaskPriority priority;

  @override
  Widget build(BuildContext context) {
    final color = switch (priority) {
      TaskPriority.low => Colors.blue,
      TaskPriority.medium => Colors.orange,
      TaskPriority.high => Colors.red,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        priority.label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$title ($count)',
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(message, style: const TextStyle(color: Colors.grey)),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFC2410C)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFF9A3412)),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  const monthNames = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  final local = value.toLocal();
  final month = monthNames[local.month - 1];
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$month $day, ${local.year} - $hour:$minute';
}
