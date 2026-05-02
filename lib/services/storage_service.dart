import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage storage = FirebaseStorage.instance;

  Future<String> uploadFile(File file, String path) async {
    final ref = storage.ref().child(path);
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }
}