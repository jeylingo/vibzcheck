import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage storage = FirebaseStorage.instance;

  Future<String> uploadFile(File file, String path) async {
    final ref = storage.ref().child(path);
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  Future<String> uploadProfilePicture(String uid, File file) async {
    final ext = file.path.split('.').last;
    final path = 'users/$uid/profile.$ext';
    return await uploadFile(file, path);
  }

  Future<String> uploadRoomCover(String roomId, File file) async {
    final ext = file.path.split('.').last;
    final path = 'rooms/$roomId/cover.$ext';
    return await uploadFile(file, path);
  }
}