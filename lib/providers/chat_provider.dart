import 'dart:io';

import 'package:flutter/material.dart';
import 'package:chatbotapp/apis/ai_provider.dart';
import 'package:chatbotapp/apis/ai_types.dart';
import 'package:chatbotapp/apis/api_service.dart';
import 'package:chatbotapp/constants/constants.dart';
import 'package:chatbotapp/hive/boxes.dart';
import 'package:chatbotapp/hive/chat_history.dart';
import 'package:chatbotapp/hive/settings.dart';
import 'package:chatbotapp/hive/user_model.dart';
import 'package:chatbotapp/models/message.dart';
import 'package:chatbotapp/utilities/chat_error_formatter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart' as path;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class ChatProvider extends ChangeNotifier {
  static const _requestTimeout = Duration(seconds: 60);

  final List<Message> _inChatMessages = [];
  List<XFile>? _imagesFileList = [];
  String _currentChatId = '';
  bool _isLoading = false;

  List<Message> get inChatMessages => _inChatMessages;
  List<XFile>? get imagesFileList => _imagesFileList;
  String get currentChatId => _currentChatId;
  bool get isLoading => _isLoading;
  bool get hasMessages => _inChatMessages.isNotEmpty;

  int get messageCount => _inChatMessages.length;

  Future<void> setInChatMessages({required String chatId}) async {
    final messagesFromDB = await loadMessagesFromDB(chatId: chatId);
    _inChatMessages
      ..clear()
      ..addAll(messagesFromDB);
    notifyListeners();
  }

  Future<List<Message>> loadMessagesFromDB({required String chatId}) async {
    final boxName = '${Constants.chatMessagesBox}$chatId';
    await Hive.openBox(boxName);
    final messageBox = Hive.box(boxName);
    final newData = messageBox.keys.map((e) {
      final message = messageBox.get(e);
      return Message.fromMap(Map<String, dynamic>.from(message));
    }).toList();
    return newData;
  }

  void setImagesFileList({required List<XFile> listValue}) {
    _imagesFileList = listValue;
    notifyListeners();
  }

  void removeImageAt(int index) {
    if (_imagesFileList == null || index >= _imagesFileList!.length) {
      return;
    }
    final updated = List<XFile>.from(_imagesFileList!)..removeAt(index);
    _imagesFileList = updated;
    notifyListeners();
  }

  void clearDraft() {
    _imagesFileList = [];
    notifyListeners();
  }

  void setCurrentChatId({required String newChatId}) {
    _currentChatId = newChatId;
    notifyListeners();
  }

  void setLoading({required bool value}) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> deleteChatMessages({required String chatId}) async {
    final storedImagePaths = await _storedImagePathsForChat(chatId: chatId);
    await _deleteImageFiles(storedImagePaths);

    final boxName = '${Constants.chatMessagesBox}$chatId';
    final messagesBox = await Hive.openBox(boxName);
    await messagesBox.clear();
    await messagesBox.close();

    if (currentChatId.isNotEmpty && currentChatId == chatId) {
      setCurrentChatId(newChatId: '');
      _inChatMessages.clear();
      notifyListeners();
    }
  }

  Future<void> clearAllChats() async {
    final historyBox = Boxes.getChatHistory();
    final chatIds = historyBox.keys.cast<String>().toList(growable: false);

    for (final chatId in chatIds) {
      await deleteChatMessages(chatId: chatId);
    }

    await historyBox.clear();
    _inChatMessages.clear();
    _currentChatId = '';
    notifyListeners();
  }

  Future<void> prepareChatRoom({
    required bool isNewChat,
    required String chatID,
  }) async {
    if (!isNewChat) {
      final chatHistory = await loadMessagesFromDB(chatId: chatID);
      _inChatMessages.clear();
      _inChatMessages.addAll(chatHistory);
      setCurrentChatId(newChatId: chatID);
    } else {
      _inChatMessages.clear();
      setCurrentChatId(newChatId: chatID);
    }
    clearDraft();
    notifyListeners();
  }

  Future<void> sentMessage({
    required String message,
    required bool isTextOnly,
    List<XFile>? draftImages,
  }) async {
    final trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty) {
      return;
    }
    if (!ApiService.isConfigured) {
      throw StateError('Add your Gemini API key to continue.');
    }

    setLoading(value: true);
    final chatId = getChatId();
    var imageFiles = const <XFile>[];
    var imagesUrls = const <String>[];
    Message? userMessage;
    Message? assistantMessage;
    Box<dynamic>? messagesBox;

    try {
      imageFiles = isTextOnly
          ? const <XFile>[]
          : await _storeDraftImages(chatId: chatId, draftImages: draftImages);
      imagesUrls = getImagesUrls(imageFiles: imageFiles);

      messagesBox = await Hive.openBox('${Constants.chatMessagesBox}$chatId');
      final userMessageId = messagesBox.keys.length;
      final assistantMessageId = messagesBox.keys.length + 1;

      userMessage = Message(
        messageId: userMessageId.toString(),
        chatId: chatId,
        role: Role.user,
        message: StringBuffer(trimmedMessage),
        imagesUrls: imagesUrls,
        timeSent: DateTime.now(),
      );

      _inChatMessages.add(userMessage);
      if (currentChatId.isEmpty) {
        setCurrentChatId(newChatId: chatId);
      }
      notifyListeners();

      final history = await getHistory(chatId: chatId);

      assistantMessage = userMessage.copyWith(
        messageId: assistantMessageId.toString(),
        role: Role.assistant,
        message: StringBuffer(),
        timeSent: DateTime.now(),
      );
      _inChatMessages.add(assistantMessage);
      notifyListeners();

      final responseText = await _requestAssistantResponse(
        history: history,
        prompt: trimmedMessage,
        imageFiles: imageFiles,
      );
      _applyAssistantText(
        assistantMessage: assistantMessage,
        text: responseText,
      );

      await saveMessagesToDB(
        chatID: chatId,
        userMessage: userMessage,
        assistantMessage: assistantMessage,
        messagesBox: messagesBox,
      );
    } catch (error, stackTrace) {
      // Roll back the optimistic bubbles and any copied images so a retry does
      // not duplicate the prompt or leak files.
      if (userMessage != null) {
        _inChatMessages.removeWhere(
          (element) =>
              element.messageId == userMessage!.messageId &&
              element.role == Role.user,
        );
      }
      if (assistantMessage != null) {
        _removeAssistantDraft(assistantMessage);
      }
      await _deleteImageFiles(imagesUrls);
      notifyListeners();
      Error.throwWithStackTrace(StateError(formatChatError(error)), stackTrace);
    } finally {
      if (messagesBox != null && messagesBox.isOpen) {
        await messagesBox.close();
      }
      setLoading(value: false);
    }
  }

  Future<String> _requestAssistantResponse({
    required List<ChatTurn> history,
    required String prompt,
    required List<XFile> imageFiles,
  }) async {
    final providerId = ApiService.providerId;
    final provider = AiProviders.create(
      providerId,
      baseUrl: ApiService.baseUrlFor(providerId),
    );
    final apiKey = ApiService.apiKeyFor(providerId);
    final model = ApiService.modelFor(providerId);

    try {
      final turns = [
        ...history,
        ChatTurn(
          role: 'user',
          text: prompt,
          images: await _readImages(imageFiles),
        ),
      ];

      try {
        return await provider.generateContent(
          turns: turns,
          apiKey: apiKey,
          model: model,
          systemInstruction: Constants.assistantSystemInstruction,
          timeout: _requestTimeout,
        );
      } catch (error) {
        if (!shouldRetryRequest(error)) rethrow;
        return await provider.generateContent(
          turns: turns,
          apiKey: apiKey,
          model: model,
          systemInstruction: Constants.assistantSystemInstruction,
          timeout: _requestTimeout,
        );
      }
    } finally {
      provider.dispose();
    }
  }

  void _removeAssistantDraft(Message assistantMessage) {
    _inChatMessages.removeWhere(
      (element) =>
          element.messageId == assistantMessage.messageId &&
          element.role == Role.assistant &&
          element.message.isEmpty,
    );
  }

  void _applyAssistantText({
    required Message assistantMessage,
    required String text,
  }) {
    if (text.isEmpty) {
      throw StateError('No response returned. Try again.');
    }

    assistantMessage.message = StringBuffer(text);
    notifyListeners();
  }

  Future<void> saveMessagesToDB({
    required String chatID,
    required Message userMessage,
    required Message assistantMessage,
    required Box messagesBox,
  }) async {
    final settings =
        Boxes.getSettings().isNotEmpty ? Boxes.getSettings().getAt(0) : null;
    final saveChatHistory = settings?.saveChatHistory ?? true;

    if (!saveChatHistory) {
      return;
    }

    await messagesBox.add(userMessage.toMap());
    await messagesBox.add(assistantMessage.toMap());
    final chatHistoryBox = Boxes.getChatHistory();
    final chatHistory = ChatHistory(
      chatId: chatID,
      prompt: userMessage.message.toString(),
      response: assistantMessage.message.toString(),
      imagesUrls: userMessage.imagesUrls,
      timestamp: DateTime.now(),
    );
    await chatHistoryBox.put(chatID, chatHistory);
  }

  Future<List<ChatTurn>> getHistory({required String chatId}) async {
    final messages = await loadMessagesFromDB(chatId: chatId);
    return messages
        .map(
          (message) => ChatTurn(
            role: message.role == Role.user ? 'user' : 'assistant',
            text: message.message.toString(),
          ),
        )
        .toList(growable: false);
  }

  Future<List<InlineImage>> _readImages(List<XFile> imageFiles) async {
    final images = <InlineImage>[];
    for (final imageFile in imageFiles) {
      images.add(
        InlineImage(
          bytes: await imageFile.readAsBytes(),
          mimeType: _mimeTypeFor(imageFile.path),
        ),
      );
    }
    return images;
  }

  String _mimeTypeFor(String filePath) {
    return switch (_fileExtension(filePath)) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'heic' => 'image/heic',
      'bmp' => 'image/bmp',
      _ => 'image/jpeg',
    };
  }

  List<String> getImagesUrls({required List<XFile> imageFiles}) {
    return imageFiles.map((image) => image.path).toList(growable: false);
  }

  Future<List<XFile>> _storeDraftImages({
    required String chatId,
    List<XFile>? draftImages,
  }) async {
    final images = draftImages ?? _imagesFileList ?? const <XFile>[];
    if (images.isEmpty) {
      return const <XFile>[];
    }

    final appDir = await path.getApplicationDocumentsDirectory();
    final mediaDir = Directory(
      '${appDir.path}/${Constants.geminiDB}/chat_media/$chatId',
    );
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }

    final storedImages = <XFile>[];
    for (final imageFile in images) {
      final extension = _fileExtension(imageFile.path);
      final storedFile = File(
        '${mediaDir.path}/${const Uuid().v4()}.$extension',
      );
      await storedFile.writeAsBytes(
        await imageFile.readAsBytes(),
        flush: true,
      );
      storedImages.add(XFile(storedFile.path));
    }
    return storedImages;
  }

  String _fileExtension(String pathValue) {
    final lastDot = pathValue.lastIndexOf('.');
    if (lastDot == -1 || lastDot == pathValue.length - 1) {
      return 'jpg';
    }
    return pathValue.substring(lastDot + 1).toLowerCase();
  }

  Future<Set<String>> _storedImagePathsForChat({
    required String chatId,
  }) async {
    final imagePaths = <String>{};
    final storedMessages = await loadMessagesFromDB(chatId: chatId);
    for (final message in storedMessages) {
      imagePaths.addAll(message.imagesUrls);
    }

    if (currentChatId == chatId) {
      for (final message in _inChatMessages) {
        imagePaths.addAll(message.imagesUrls);
      }
    }

    return imagePaths;
  }

  Future<void> _deleteImageFiles(Iterable<String> imagePaths) async {
    for (final imagePath in imagePaths) {
      if (imagePath.isEmpty) {
        continue;
      }
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  String getChatId() {
    if (currentChatId.isEmpty) {
      return const Uuid().v4();
    } else {
      return currentChatId;
    }
  }

  static Future<void> initHive() async {
    await Hive.initFlutter(Constants.geminiDB);

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ChatHistoryAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(UserModelAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(SettingsAdapter());
    }

    if (!Hive.isBoxOpen(Constants.chatHistoryBox)) {
      await Hive.openBox<ChatHistory>(Constants.chatHistoryBox);
    }
    if (!Hive.isBoxOpen(Constants.userBox)) {
      await Hive.openBox<UserModel>(Constants.userBox);
    }
    if (!Hive.isBoxOpen(Constants.settingsBox)) {
      await Hive.openBox<Settings>(Constants.settingsBox);
    }
    if (!Hive.isBoxOpen(Constants.apiKeyBox)) {
      await Hive.openBox<dynamic>(Constants.apiKeyBox);
    }
  }
}
