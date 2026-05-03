import 'dart:io';
import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage storage = FirebaseStorage.instance;

  // Convert an image file directly to a Base64 data URI string to store in Firestore.
  // This bypasses Firebase Storage entirely so you don't have to pay or set it up!
  Future<String> _convertToBase64(File file) async {
    final bytes = await file.readAsBytes();
    final ext = file.path.split('.').last.toLowerCase();
    final mimeType = (ext == 'png') ? 'image/png' : 'image/jpeg';
    final base64String = base64Encode(bytes);
    return 'data:$mimeType;base64,$base64String';
  }

  Future<String> uploadProfilePicture(String uid, File file) async {
    return await _convertToBase64(file);
  }

  Future<String> uploadRoomCover(String roomId, File file) async {
    return await _convertToBase64(file);
  }
}