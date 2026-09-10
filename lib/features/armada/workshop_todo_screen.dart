import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/watermarked_camera_capture.dart';

/// Workshop To-Do List & Riwayat Servis (Section 21.9):
/// Teknisi workshop melihat daftar tugas harian/mingguan,
/// centang yang sudah selesai, upload foto hasil perbaikan.
class WorkshopTodoScreen extends ConsumerStatefulWidget {
  const WorkshopTodoScreen({super.key});

  @override
  ConsumerState<WorkshopTodoScreen> createState() => _WorkshopTodoScreenState();
}

class _WorkshopTodoScreenState extends ConsumerState<WorkshopTodoScreen> {
  final List<WorkshopTodo> _todos = [
    WorkshopTodo(id: '1', title: 'Ganti oli mesin Excavator PC200', isDone: false),
    WorkshopTodo(id: '2', title: 'Periksa rem Dump Truck DT-01', isDone: false),
    WorkshopTodo(id: '3', title: 'Service filter udara Mixer Beton', isDone: true),
    WorkshopTodo(id: '4', title: 'Ganti ban serepa Mobil Pickup', isDone: false),
  ];

  String? _photoPath;
  bool _isSubmitting = false;

  Future<void> _takePhotoForTodo(String todoId) async {
    final photo = await takeWatermarkedPhoto(ref);
    if (photo == null) return;

    setState(() {
      _photoPath = photo.path;
    });

    // Tandai todo selesai dengan foto
    setState(() {
      final idx = _todos.indexWhere((t) => t.id == todoId);
      if (idx >= 0) {
        _todos[idx] = _todos[idx].copyWith(isDone: true, photoPath: _photoPath);
      }
      _photoPath = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tugas ditandai selesai dengan foto')),
      );
    }
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      // TODO: Kirim ke backend POST /workshop/todo/check
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workshop to-do tersimpan')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final completed = _todos.where((t) => t.isDone).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workshop To-Do'),
        actions: const [PortalSwitchButton()],
      ),
      body: Column(
        children: [
          // Progress header
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.primaryColor.withValues(alpha: 0.05),
            child: Row(
              children: [
                Icon(Icons.build_rounded, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tugas Hari Ini',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$completed dari ${_todos.length} selesai',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                CircularProgressIndicator(
                  value: _todos.isEmpty ? 0 : completed / _todos.length,
                  backgroundColor: Colors.grey.shade200,
                ),
              ],
            ),
          ),

          // Todo list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _todos.length,
              itemBuilder: (context, index) {
                final todo = _todos[index];
                return _TodoTile(
                  todo: todo,
                  index: index + 1,
                  onToggle: () {
                    setState(() {
                      _todos[index] = todo.copyWith(isDone: !todo.isDone);
                    });
                  },
                  onTakePhoto: () => _takePhotoForTodo(todo.id),
                );
              },
            ),
          ),

          // Submit button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Simpan Progress'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WorkshopTodo {
  const WorkshopTodo({
    required this.id,
    required this.title,
    required this.isDone,
    this.photoPath,
  });

  final String id;
  final String title;
  final bool isDone;
  final String? photoPath;

  WorkshopTodo copyWith({bool? isDone, String? photoPath}) {
    return WorkshopTodo(
      id: id,
      title: title,
      isDone: isDone ?? this.isDone,
      photoPath: photoPath ?? this.photoPath,
    );
  }
}

class _TodoTile extends StatelessWidget {
  const _TodoTile({
    required this.todo,
    required this.index,
    required this.onToggle,
    required this.onTakePhoto,
  });

  final WorkshopTodo todo;
  final int index;
  final VoidCallback onToggle;
  final VoidCallback onTakePhoto;

  @override
  Widget build(BuildContext context) {
    final displayNum = index.toString().padLeft(2, '0');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: todo.isDone
                    ? Colors.green.withValues(alpha: 0.1)
                    : AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                displayNum,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: todo.isDone ? Colors.green.shade700 : AppTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Checkbox(
              value: todo.isDone,
              onChanged: (_) => onToggle(),
            ),
          ],
        ),
        title: Text(
          todo.title,
          style: TextStyle(
            decoration: todo.isDone ? TextDecoration.lineThrough : null,
            color: todo.isDone ? AppTheme.textTertiary : AppTheme.textPrimary,
          ),
        ),
        subtitle: todo.photoPath != null
            ? Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(todo.photoPath!),
                    height: 60,
                    width: 60,
                    fit: BoxFit.cover,
                  ),
                ),
              )
            : null,
        trailing: todo.isDone
            ? const Icon(Icons.check_circle, color: Colors.green)
            : IconButton(
                icon: const Icon(Icons.camera_alt_outlined),
                onPressed: onTakePhoto,
                tooltip: 'Ambil foto bukti',
              ),
      ),
    );
  }
}
