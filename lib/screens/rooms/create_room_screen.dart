import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/room_service.dart';
import 'room_screen.dart';

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final titleController = TextEditingController();
  bool isPrivate = false;
  bool loading = false;
  String error = '';
  File? _coverImage;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        _coverImage = File(pickedFile.path);
      });
    }
  }

  Future<void> create() async {
    final title = titleController.text.trim();
    if (title.isEmpty) {
      setState(() {
        error = 'Please enter a room title.';
      });
      return;
    }

    setState(() {
      loading = true;
      error = '';
    });

    try {
      final res = await RoomService().createRoom(title, isPrivate: isPrivate, coverImage: _coverImage);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => RoomScreen(roomId: res['roomId']!, code: res['code']!)),
      );
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Room')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(12),
                  image: _coverImage != null ? DecorationImage(image: FileImage(_coverImage!), fit: BoxFit.cover) : null,
                ),
                child: _coverImage == null ? const Icon(Icons.add_a_photo, size: 40, color: Colors.white54) : null,
              ),
            ),
            const SizedBox(height: 16),
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Room title')),
            Row(
              children: [
                const Text('Private'),
                Switch(value: isPrivate, onChanged: (v) => setState(() => isPrivate = v)),
              ],
            ),
            if (error.isNotEmpty) Text(error, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: loading ? null : create, child: loading ? const CircularProgressIndicator() : const Text('Create')),
          ],
        ),
      ),
    );
  }
}
