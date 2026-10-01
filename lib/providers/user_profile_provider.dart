import 'dart:io';

import 'package:flutter/material.dart';
import 'package:chatbotapp/constants/constants.dart';
import 'package:chatbotapp/hive/boxes.dart';
import 'package:chatbotapp/hive/user_model.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class UserProfileProvider extends ChangeNotifier {
  String _uid = '';
  String _name = 'You';
  String _imagePath = '';

  String get uid => _uid;
  String get name => _name.trim().isEmpty ? 'You' : _name.trim();
  String get firstName => name.split(' ').first;
  String get imagePath => _imagePath;
  bool get hasImage => _imagePath.trim().isNotEmpty;
  String get initials {
    final parts = name.split(' ').where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) {
      return 'Y';
    }
    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Future<void> loadUser() async {
    final userBox = Boxes.getUser();
    if (userBox.isEmpty) {
      _uid = '';
      _name = 'You';
      _imagePath = '';
      notifyListeners();
      return;
    }

    final user = userBox.getAt(0);
    if (user == null) {
      return;
    }

    _uid = user.uid;
    _name = user.name;
    _imagePath = user.image;
    notifyListeners();
  }

  Future<void> saveProfile({
    required String name,
    required String imagePath,
  }) async {
    final trimmedName = name.trim().isEmpty ? 'You' : name.trim();
    final storedImagePath = await _persistImage(imagePath);
    final userBox = Boxes.getUser();
    final user = UserModel(
      uid: _uid.isEmpty ? const Uuid().v4() : _uid,
      name: trimmedName,
      image: storedImagePath,
    );

    if (userBox.isEmpty) {
      await userBox.add(user);
    } else {
      await userBox.putAt(0, user);
    }

    _uid = user.uid;
    _name = user.name;
    _imagePath = user.image;
    notifyListeners();
  }

  /// Copies a picked image into app-owned storage so the avatar survives the
  /// OS clearing the temporary gallery cache.
  Future<String> _persistImage(String imagePath) async {
    final trimmed = imagePath.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final source = File(trimmed);
    if (!await source.exists()) {
      return trimmed;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final targetDir = Directory(
      '${appDir.path}/${Constants.geminiDB}/profile',
    );
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    // Already inside app storage — keep it as is.
    if (source.absolute.path.startsWith(targetDir.absolute.path)) {
      return trimmed;
    }

    final extension = _extensionOf(trimmed);
    final target = File('${targetDir.path}/avatar.$extension');
    await target.writeAsBytes(await source.readAsBytes(), flush: true);
    return target.path;
  }

  String _extensionOf(String pathValue) {
    final lastDot = pathValue.lastIndexOf('.');
    if (lastDot == -1 || lastDot == pathValue.length - 1) {
      return 'jpg';
    }
    return pathValue.substring(lastDot + 1).toLowerCase();
  }
}
