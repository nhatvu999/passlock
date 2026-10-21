import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

// ============================================================================
// 1. MODEL DỮ LIỆU TÀI KHOẢN (ACCOUNT CREDENTIAL MODEL)
// ============================================================================
class CredentialItem {
  final String id;
  final String service;
  final String username;
  final String password;
  final String category;
  final String? notes;
  final int updatedAt;

  CredentialItem({
    required this.id,
    required this.service,
    required this.username,
    required this.password,
    this.category = 'Khác',
    this.notes,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'service': service,
      'username': username,
      'password': password,
      'category': category,
      'notes': notes,
      'updatedAt': updatedAt,
    };
  }

  factory CredentialItem.fromMap(Map<String, dynamic> map) {
    return CredentialItem(
      id: map['id'] ?? '',
      service: map['service'] ?? '',
      username: map['username'] ?? '',
      password: map['password'] ?? '',
      category: map['category'] ?? 'Khác',
      notes: map['notes'],
      updatedAt: map['updatedAt'] ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  String toJson() => json.encode(toMap());

  factory CredentialItem.fromJson(String source) =>
      CredentialItem.fromMap(json.decode(source));
}

// ============================================================================
// 2. DỊCH VỤ LƯU TRỮ MÃ HÓA CỤC BỘ OFFLINE (SECURE STORAGE SERVICE)
// ============================================================================
class SecureStorageService {
  static const _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
    resetOnError: true,
  );
  static const _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock,
  );

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: _androidOptions,
    iOptions: _iosOptions,
  );

  static const String _keyPasscode = 'app_passcode';
  static const String _keyCredentials = 'vault_credentials';
  static const String _defaultPasscode = '123456';

  Future<void> init() async {
    final currentPasscode = await _storage.read(key: _keyPasscode);
    if (currentPasscode == null || currentPasscode.isEmpty) {
      await _storage.write(key: _keyPasscode, value: _defaultPasscode);
      
      // Khởi tạo một số tài khoản mẫu ban đầu
      final defaultList = [
        CredentialItem(
          id: 'demo_google',
          service: 'Google Account',
          username: 'example.user@gmail.com',
          password: 'GoogleSecurePass#992',
          category: 'Email',
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
        CredentialItem(
          id: 'demo_facebook',
          service: 'Facebook',
          username: '0901234567',
          password: 'FbPassword2026!',
          category: 'Mạng xã hội',
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
        CredentialItem(
          id: 'demo_bank',
          service: 'Techcombank Digital',
          username: 'techcom_user99',
          password: 'Bank@StrongPin9811',
          category: 'Ngân hàng',
          notes: 'Mã Smart OTP: 9821',
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      ];
      await saveCredentials(defaultList);
    }
  }

  Future<bool> verifyPasscode(String input) async {
    final stored = await _storage.read(key: _keyPasscode);
    return (stored ?? _defaultPasscode) == input;
  }

  Future<void> updatePasscode(String newPasscode) async {
    await _storage.write(key: _keyPasscode, value: newPasscode);
  }

  static const String _keyThemeMode = 'app_theme_mode';

  Future<bool> getIsDarkMode() async {
    final val = await _storage.read(key: _keyThemeMode);
    return val == 'dark';
  }

  Future<void> saveIsDarkMode(bool isDark) async {
    await _storage.write(key: _keyThemeMode, value: isDark ? 'dark' : 'light');
  }

  Future<List<CredentialItem>> getCredentials() async {
    final rawJson = await _storage.read(key: _keyCredentials);
    if (rawJson == null || rawJson.isEmpty) return [];
    try {
      final List<dynamic> decoded = json.decode(rawJson);
      return decoded.map((e) => CredentialItem.fromMap(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveCredentials(List<CredentialItem> list) async {
    final encoded = json.encode(list.map((e) => e.toMap()).toList());
    await _storage.write(key: _keyCredentials, value: encoded);
  }

  Future<void> addCredential(CredentialItem item) async {
    final list = await getCredentials();
    list.insert(0, item);
    await saveCredentials(list);
  }

  Future<void> updateCredential(CredentialItem item) async {
    final list = await getCredentials();
    final index = list.indexWhere((element) => element.id == item.id);
    if (index != -1) {
      list[index] = item;
      await saveCredentials(list);
    }
  }

  Future<void> deleteCredential(String id) async {
    final list = await getCredentials();
    list.removeWhere((element) => element.id == id);
    await saveCredentials(list);
  }
}

// ============================================================================
// 3. DỊCH VỤ SAO LƯU & XUẤT/NHẬP FILE (EXCEL/CSV, TXT, JSON BACKUP SERVICE)
// ============================================================================
class BackupService {
  static String exportToCSV(List<CredentialItem> items) {
    final buffer = StringBuffer();
    // Thêm ký tự UTF-8 BOM (﻿) ở đầu file để Microsoft Excel hiển thị chuẩn 100% tiếng Việt
    buffer.write('﻿');
    buffer.writeln('"Dịch vụ","Danh mục","Tài khoản/Email","Mật khẩu","Ghi chú"');
    for (final it in items) {
      final s = it.service.replaceAll('"', '""');
      final c = it.category.replaceAll('"', '""');
      final u = it.username.replaceAll('"', '""');
      final p = it.password.replaceAll('"', '""');
      final n = (it.notes ?? '').replaceAll('"', '""');
      buffer.writeln('"${s}","${c}","${u}","${p}","${n}"');
    }
    return buffer.toString();
  }

  static String exportToTXT(List<CredentialItem> items) {
    final buffer = StringBuffer();
    // Thêm ký tự UTF-8 BOM (﻿) để Notepad hiển thị chuẩn font tiếng Việt
    buffer.write('﻿');
    buffer.writeln('==================================================');
    buffer.writeln('       BẢN SAO LƯU MẬT KHẨU PASSLOCK VAULT        ');
    buffer.writeln('       Ngày xuất: ${DateTime.now().toLocal()}     ');
    buffer.writeln('       Tổng số tài khoản: ${items.length}        ');
    buffer.writeln('       Định dạng: Chuẩn PassLock Vault UTF-8      ');
    buffer.writeln('==================================================');
    buffer.writeln();

    for (int i = 0; i < items.length; i++) {
      final it = items[i];
      final cat = it.category.isEmpty ? 'Khác' : it.category;
      buffer.writeln('[MỤC ${i + 1}] Dịch vụ: ${it.service} (${cat})');
      buffer.writeln('Dịch vụ           : ${it.service}');
      buffer.writeln('Danh mục          : ${cat}');
      buffer.writeln('Tài khoản / Email : ${it.username}');
      buffer.writeln('Mật khẩu          : ${it.password}');
      if (it.notes != null && it.notes!.isNotEmpty) {
        buffer.writeln('Ghi chú           : ${it.notes}');
      }
      buffer.writeln('--------------------------------------------------');
      buffer.writeln();
    }
    return buffer.toString();
  }

  static String exportToJSON(List<CredentialItem> items) {
    final data = {
      'app': 'PassLock',
      'version': '1.0',
      'format': 'passlock-vault',
      'exportedAt': DateTime.now().toIso8601String(),
      'count': items.length,
      'items': items.map((e) => e.toMap()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  static Future<void> exportAndShare({
    required BuildContext context,
    required List<CredentialItem> items,
    required String format, // 'csv', 'txt' hoặc 'json'
  }) async {
    String content;
    if (format == 'csv') {
      content = exportToCSV(items);
    } else if (format == 'txt') {
      content = exportToTXT(items);
    } else {
      content = exportToJSON(items);
    }

    final timeStamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'passlock_backup_${timeStamp}.${format}';

    // Chèn chính xác mảng 3 byte UTF-8 BOM: 0xEF, 0xBB, 0xBF vào nhị phân file
    // Điều này đảm bảo 100% Microsoft Excel, Notepad, Google Sheets không bị lỗi font Tiếng Việt
    final cleanContent = content.startsWith('﻿') ? content.substring(1) : content;
    final fileBytes = format == 'json'
        ? utf8.encode(content)
        : [0xEF, 0xBB, 0xBF, ...utf8.encode(cleanContent)];

    // 1. Lưu bản sao lưu vào thư mục Documents của ứng dụng (luôn đọc được 100% không bị Scoped Storage chặn)
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${appDocDir.path}/PassLock_Backups');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      final localBackupFile = File('${backupDir.path}/${fileName}');
      await localBackupFile.writeAsBytes(fileBytes);
    } catch (_) {}

    // 2. Lưu vào thư mục tạm và kích hoạt chia sẻ hệ thống với mimeType utf-8 chuẩn
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${fileName}');
    await file.writeAsBytes(fileBytes);

    final mimeType = format == 'csv'
        ? 'text/csv;charset=utf-8'
        : (format == 'json' ? 'application/json;charset=utf-8' : 'text/plain;charset=utf-8');

    await Share.shareXFiles(
      [XFile(file.path, mimeType: mimeType, name: fileName)],
      text: 'Bản sao lưu mật khẩu PassLock (${items.length} tài khoản)',
      subject: 'Sao lưu PassLock Vault',
    );
  }

  static List<CredentialItem> parseUniversal(String content) {
    var clean = content.trim();
    while (clean.isNotEmpty && (clean.startsWith('﻿') || clean.codeUnitAt(0) == 0xFEFF)) {
      clean = clean.substring(1).trim();
    }
    final trimmed = clean;
    final List<CredentialItem> imported = [];

    // 1. Parse JSON
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        final parsed = json.decode(trimmed);
        final list = parsed is List ? parsed : (parsed['items'] as List? ?? parsed['credentials'] as List? ?? []);
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            final s = item['service'] ?? item['dich_vu'] ?? item['name'] ?? item['title'];
            final u = item['username'] ?? item['tai_khoan'] ?? item['email'] ?? item['user'] ?? item['account'];
            final p = item['password'] ?? item['mat_khau'] ?? item['pass'] ?? item['pwd'];
            if (s != null && (u != null || p != null)) {
              imported.add(CredentialItem(
                id: item['id']?.toString() ?? 'json_${DateTime.now().millisecondsSinceEpoch}_${imported.length}',
                service: s.toString().trim(),
                category: item['category']?.toString() ?? item['danh_muc']?.toString() ?? 'Khác',
                username: u?.toString().trim() ?? '',
                password: p?.toString() ?? '',
                notes: item['notes']?.toString() ?? item['ghi_chu']?.toString(),
                updatedAt: DateTime.now().millisecondsSinceEpoch,
              ));
            }
          }
        }
        if (imported.isNotEmpty) return imported;
      } catch (_) {}
    }

    // 2. Parse CSV (Dùng LineSplitter chuẩn thư viện Dart, không dùng regex phân tách)
    final lines = const LineSplitter().convert(trimmed).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isNotEmpty) {
      final firstLine = lines[0];
      String delimiter = ',';
      final commaCount = ','.allMatches(firstLine).length;
      final semiCount = ';'.allMatches(firstLine).length;
      final tabCount = '	'.allMatches(firstLine).length;
      if (semiCount > commaCount && semiCount >= tabCount) {
        delimiter = ';';
      } else if (tabCount > commaCount && tabCount > semiCount) {
        delimiter = '	';
      }

      if (lines.length > 1 || (lines.length == 1 && lines[0].contains(delimiter))) {
        List<String> parseCsvLine(String line) {
          final values = <String>[];
          var inQuotes = false;
          var current = '';
          for (int c = 0; c < line.length; c++) {
            final char = line[c];
            if (char == '"') {
              inQuotes = !inQuotes;
            } else if (char == delimiter && !inQuotes) {
              values.add(_cleanCsvCell(current));
              current = '';
            } else {
              current += char;
            }
          }
          values.add(_cleanCsvCell(current));
          return values;
        }

        final headerValues = parseCsvLine(firstLine).map((v) => v.toLowerCase()).toList();
        final isHeader = headerValues.any((h) =>
          h.contains('dịch vụ') || h.contains('service') || h.contains('tài khoản') || h.contains('user') || h.contains('mật khẩu') || h.contains('pass')
        );

        int sIdx = 0;
        int cIdx = 1;
        int uIdx = 2;
        int pIdx = 3;
        int nIdx = 4;

        if (isHeader) {
          for (int h = 0; h < headerValues.length; h++) {
            final hv = headerValues[h];
            if (hv.contains('dịch vụ') || hv.contains('service') || hv.contains('app')) {
              sIdx = h;
            } else if (hv.contains('danh mục') || hv.contains('category') || hv.contains('nhóm')) {
              cIdx = h;
            } else if (hv.contains('tài khoản') || hv.contains('user') || hv.contains('email') || hv.contains('account')) {
              uIdx = h;
            } else if (hv.contains('mật khẩu') || hv.contains('pass') || hv.contains('pwd')) {
              pIdx = h;
            } else if (hv.contains('ghi chú') || hv.contains('note')) {
              nIdx = h;
            }
          }
        }

        final startRow = isHeader ? 1 : 0;
        for (int i = startRow; i < lines.length; i++) {
          final values = parseCsvLine(lines[i]);
          if (values.length >= 2) {
            final s = sIdx < values.length ? values[sIdx] : values[0];
            final c = (cIdx < values.length && values[cIdx].isNotEmpty) ? values[cIdx] : 'Khác';
            final u = uIdx < values.length ? values[uIdx] : (values.length > 2 ? values[2] : values[1]);
            final p = pIdx < values.length ? values[pIdx] : (values.length > 3 ? values[3] : values.last);
            final n = nIdx < values.length && values[nIdx].isNotEmpty ? values[nIdx] : null;

            if (s.isNotEmpty && (u.isNotEmpty || p.isNotEmpty)) {
              imported.add(CredentialItem(
                id: 'csv_${DateTime.now().millisecondsSinceEpoch}_${i}',
                service: s,
                category: c,
                username: u,
                password: p,
                notes: n,
                updatedAt: DateTime.now().millisecondsSinceEpoch,
              ));
            }
          }
        }
        if (imported.isNotEmpty) return imported;
      }
    }

    // 3. Parse TXT (LineSplitter, StateMachine, không dùng regex phân tách)
    final allTextLines = const LineSplitter().convert(trimmed).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    String curService = '';
    String curCat = 'Khác';
    String curUser = '';
    String curPass = '';
    String curNote = '';

    void commitCurrent() {
      if (curService.isNotEmpty && (curUser.isNotEmpty || curPass.isNotEmpty)) {
        imported.add(CredentialItem(
          id: 'txt_${DateTime.now().millisecondsSinceEpoch}_${imported.length}',
          service: curService,
          category: curCat.isNotEmpty ? curCat : 'Khác',
          username: curUser,
          password: curPass,
          notes: curNote.isNotEmpty ? curNote : null,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ));
      }
      curService = '';
      curCat = 'Khác';
      curUser = '';
      curPass = '';
      curNote = '';
    }

    for (final line in allTextLines) {
      if (line.length >= 4 && line.split('').every((c) => c == '-' || c == '=')) {
        commitCurrent();
        continue;
      }

      if (line.startsWith('[') && line.contains(']')) {
        commitCurrent();
        final after = line.substring(line.indexOf(']') + 1).trim();
        var rest = after;
        if (rest.toLowerCase().startsWith('dịch vụ:')) {
          rest = rest.substring(8).trim();
        }
        if (rest.contains('(') && rest.contains(')')) {
          curService = rest.split('(')[0].trim();
          curCat = rest.split('(')[1].replaceAll(')', '').trim();
        } else {
          curService = rest.trim();
        }
        continue;
      }

      final lower = line.toLowerCase();
      if (lower.startsWith('dịch vụ:') || lower.startsWith('service:') || lower.startsWith('ứng dụng:')) {
        final parts = line.split(':');
        final val = parts.length > 1 ? parts.sublist(1).join(':').trim() : '';
        if (curService.isNotEmpty && (curUser.isNotEmpty || curPass.isNotEmpty)) {
          commitCurrent();
          curService = val;
        } else {
          curService = val;
        }
      } else if (lower.startsWith('danh mục:') || lower.startsWith('category:') || lower.startsWith('nhóm:')) {
        final parts = line.split(':');
        if (parts.length > 1) curCat = parts.sublist(1).join(':').trim();
      } else if (lower.contains('tài khoản') || lower.contains('email') || lower.startsWith('username:') || lower.startsWith('user:')) {
        final parts = line.split(':');
        if (parts.length > 1) curUser = parts.sublist(1).join(':').trim();
      } else if (lower.contains('mật khẩu') || lower.contains('password:') || lower.startsWith('pass:') || lower.startsWith('pwd:')) {
        final parts = line.split(':');
        if (parts.length > 1) curPass = parts.sublist(1).join(':').trim();
      } else if (lower.contains('ghi chú') || lower.startsWith('notes:') || lower.startsWith('note:')) {
        final parts = line.split(':');
        if (parts.length > 1) curNote = parts.sublist(1).join(':').trim();
      }
    }
    commitCurrent();

    return imported;
  }

  static String _cleanCsvCell(String raw) {
    String val = raw.trim();
    if (val.startsWith('"') && val.endsWith('"') && val.length >= 2) {
      val = val.substring(1, val.length - 1);
    }
    return val.replaceAll('""', '"').trim();
  }
}

// ============================================================================
// 3.5. DỊCH VỤ SAO LƯU GOOGLE DRIVE CLOUD (GOOGLE DRIVE AUTO-BACKUP SERVICE)
// ============================================================================
class GoogleAccountUser {
  final String email;
  final String displayName;
  final String? accessToken;

  GoogleAccountUser({
    required this.email,
    required this.displayName,
    this.accessToken,
  });
}

class GoogleDriveBackupFile {
  final String id;
  final String name;
  final DateTime createdAt;
  final int sizeBytes;
  final String? localPath;

  GoogleDriveBackupFile({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.sizeBytes,
    this.localPath,
  });
}

class GoogleDriveBackupService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const String _prefAutoBackup = 'passlock_auto_backup_enabled';
  static const String _prefGoogleEmail = 'passlock_google_email';
  static const String _prefGoogleName = 'passlock_google_name';
  static const String _prefGoogleToken = 'passlock_google_token';

  GoogleAccountUser? _currentUser;
  bool _autoBackupEnabled = true;

  GoogleAccountUser? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;
  bool get isAutoBackupEnabled => _autoBackupEnabled;

  static String formatFileTimestamp(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return '$y$m${d}_$hh$mm$ss';
  }

  static String formatDisplayDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString().padLeft(4, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return '$d/$m/$y $hh:$mm:$ss';
  }

  Future<void> init() async {
    final autoPref = await _storage.read(key: _prefAutoBackup);
    if (autoPref != null) {
      _autoBackupEnabled = autoPref == 'true';
    }
    final savedEmail = await _storage.read(key: _prefGoogleEmail);
    final savedName = await _storage.read(key: _prefGoogleName);
    final savedToken = await _storage.read(key: _prefGoogleToken);
    if (savedEmail != null && savedEmail.isNotEmpty) {
      _currentUser = GoogleAccountUser(
        email: savedEmail,
        displayName: savedName ?? savedEmail.split('@').first,
        accessToken: savedToken,
      );
    }
  }

  Future<void> setAutoBackupEnabled(bool enabled) async {
    _autoBackupEnabled = enabled;
    await _storage.write(key: _prefAutoBackup, value: enabled ? 'true' : 'false');
  }

  Future<GoogleAccountUser?> signInWithAccount({
    required String email,
    String? displayName,
    String? accessToken,
  }) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty) return null;
    final cleanName = (displayName != null && displayName.trim().isNotEmpty)
        ? displayName.trim()
        : cleanEmail.split('@').first;
    final cleanToken = (accessToken != null && accessToken.trim().isNotEmpty)
        ? accessToken.trim()
        : null;

    await _storage.write(key: _prefGoogleEmail, value: cleanEmail);
    await _storage.write(key: _prefGoogleName, value: cleanName);
    if (cleanToken != null) {
      await _storage.write(key: _prefGoogleToken, value: cleanToken);
    } else {
      await _storage.delete(key: _prefGoogleToken);
    }

    _currentUser = GoogleAccountUser(
      email: cleanEmail,
      displayName: cleanName,
      accessToken: cleanToken,
    );
    return _currentUser;
  }

  Future<void> signOut() async {
    await _storage.delete(key: _prefGoogleEmail);
    await _storage.delete(key: _prefGoogleName);
    await _storage.delete(key: _prefGoogleToken);
    _currentUser = null;
  }

  Future<Directory> _getOrCreateLocalDriveSyncFolder() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final folder = Directory('${appDocDir.path}/PassLock_Backups');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    return folder;
  }

  Future<String?> _getOrCreateCloudFolder(String token) async {
    final client = HttpClient();
    try {
      final q = Uri.encodeQueryComponent(
        "mimeType = 'application/vnd.google-apps.folder' and name = 'PassLock_Backups' and trashed = false",
      );
      final listUri = Uri.parse('https://www.googleapis.com/drive/v3/files?q=$q&spaces=drive&fields=files(id,name)');
      final req = await client.getUrl(listUri);
      req.headers.set('Authorization', 'Bearer $token');
      final res = await req.close();
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final data = json.decode(body) as Map<String, dynamic>;
        final files = data['files'] as List?;
        if (files != null && files.isNotEmpty) {
          return files.first['id']?.toString();
        }
      }

      // Tạo mới thư mục PassLock_Backups trên Google Drive
      final createUri = Uri.parse('https://www.googleapis.com/drive/v3/files?fields=id');
      final createReq = await client.postUrl(createUri);
      createReq.headers.set('Authorization', 'Bearer $token');
      createReq.headers.set('Content-Type', 'application/json; charset=UTF-8');
      createReq.add(utf8.encode(json.encode({
        'name': 'PassLock_Backups',
        'mimeType': 'application/vnd.google-apps.folder',
      })));
      final createRes = await createReq.close();
      if (createRes.statusCode == 200 || createRes.statusCode == 201) {
        final body = await createRes.transform(utf8.decoder).join();
        final data = json.decode(body) as Map<String, dynamic>;
        return data['id']?.toString();
      }
    } catch (e) {
      debugPrint('Cloud Drive folder check error: $e');
    } finally {
      client.close();
    }
    return null;
  }

  Future<String?> backupToDrive(List<CredentialItem> credentials, {bool isAuto = false}) async {
    try {
      if (_currentUser == null) return null;

      final now = DateTime.now();
      final dateStr = formatFileTimestamp(now);
      final filename = 'PassLock_Backup_$dateStr.csv';

      final csvContent = BackupService.exportToCSV(credentials);
      final cleanContent = csvContent.startsWith('﻿') ? csvContent.substring(1) : csvContent;
      final fileBytes = <int>[0xEF, 0xBB, 0xBF, ...utf8.encode(cleanContent)];

      // 1. Lưu trực tiếp vào thư mục riêng PassLock_Backups
      final folder = await _getOrCreateLocalDriveSyncFolder();
      final localFile = File('${folder.path}/$filename');
      await localFile.writeAsBytes(fileBytes);

      // 2. Nếu có OAuth Access Token, đồng bộ trực tiếp lên Google Drive Cloud API v3
      final token = _currentUser?.accessToken;
      if (token != null && token.isNotEmpty) {
        final folderId = await _getOrCreateCloudFolder(token);
        if (folderId != null) {
          final client = HttpClient();
          try {
            const boundary = 'passlock_drive_multipart_boundary';
            final uploadUri = Uri.parse('https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart');
            final req = await client.postUrl(uploadUri);
            req.headers.set('Authorization', 'Bearer $token');
            req.headers.set('Content-Type', 'multipart/related; boundary=$boundary');

            final metadataJson = json.encode({
              'name': filename,
              'parents': [folderId],
              'mimeType': 'text/csv',
            });

            final bodyBytes = <int>[
              ...utf8.encode('--$boundary
Content-Type: application/json; charset=UTF-8

$metadataJson
--$boundary
Content-Type: text/csv; charset=UTF-8

'),
              ...fileBytes,
              ...utf8.encode('
--$boundary--
'),
            ];
            req.add(bodyBytes);
            await req.close();
          } catch (e) {
            debugPrint('Cloud upload error: $e');
          } finally {
            client.close();
          }
        }
      }

      return filename;
    } catch (e) {
      debugPrint('Error backing up to Drive: $e');
      return null;
    }
  }

  Future<List<GoogleDriveBackupFile>> listBackups() async {
    final List<GoogleDriveBackupFile> backups = [];
    try {
      final folder = await _getOrCreateLocalDriveSyncFolder();
      if (await folder.exists()) {
        final entities = await folder.list().toList();
        for (final entity in entities) {
          if (entity is File && entity.path.toLowerCase().endsWith('.csv')) {
            final stat = await entity.stat();
            final name = entity.path.split(Platform.pathSeparator).last;
            backups.add(
              GoogleDriveBackupFile(
                id: entity.path,
                name: name,
                createdAt: stat.modified,
                sizeBytes: stat.size,
                localPath: entity.path,
              ),
            );
          }
        }
      }
      backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      debugPrint('Error listing backups: $e');
    }
    return backups;
  }

  Future<String?> downloadBackupContent(String fileIdOrPath) async {
    try {
      final file = File(fileIdOrPath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        return utf8.decode(bytes, allowMalformed: true);
      }
      return null;
    } catch (e) {
      debugPrint('Error reading backup file: $e');
      return null;
    }
  }
}

// ============================================================================
// 4. MÀN HÌNH KHÓA PASSCODE 6 SỐ (PASSCODE SCREEN)
// ============================================================================
class PasscodeScreen extends StatefulWidget {
  final SecureStorageService storageService;
  final VoidCallback onUnlock;

  const PasscodeScreen({
    super.key,
    required this.storageService,
    required this.onUnlock,
  });

  @override
  State<PasscodeScreen> createState() => _PasscodeScreenState();
}

class _PasscodeScreenState extends State<PasscodeScreen>
    with SingleTickerProviderStateMixin {
  String _enteredCode = '';
  bool _isError = false;
  String _message = 'Nhập mật mã 6 chữ số để mở khóa';
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onDigitPressed(String digit) {
    if (_enteredCode.length >= 6) return;
    HapticFeedback.lightImpact();

    setState(() {
      _isError = false;
      _enteredCode += digit;
    });

    if (_enteredCode.length == 6) {
      _verifyCode();
    }
  }

  void _onDeletePressed() {
    if (_enteredCode.isNotEmpty) {
      HapticFeedback.selectionClick();
      setState(() {
        _isError = false;
        _enteredCode = _enteredCode.substring(0, _enteredCode.length - 1);
      });
    }
  }

  Future<void> _verifyCode() async {
    final isValid = await widget.storageService.verifyPasscode(_enteredCode);
    if (isValid) {
      HapticFeedback.mediumImpact();
      widget.onUnlock();
    } else {
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0.0);
      setState(() {
        _isError = true;
        _message = 'Mật mã không đúng. Vui lòng thử lại!';
        _enteredCode = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                size: 42,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'PassLock Vault',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              _message,
              style: TextStyle(
                color: _isError ? const Color(0xFFF87171) : const Color(0xFF94A3B8),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Mã mặc định: 123456',
                style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12),
              ),
            ),

            const SizedBox(height: 36),

            // 6 Chấm tròn PIN dots
            AnimatedBuilder(
              animation: _shakeController,
              builder: (context, child) {
                final double offset = 10 *
                    (1 - _shakeController.value) *
                    ((_shakeController.value * 6).toInt().isEven ? 1 : -1);
                return Transform.translate(
                  offset: Offset(_isError ? offset : 0, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (index) {
                      final isFilled = index < _enteredCode.length;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isFilled
                              ? (_isError ? const Color(0xFFEF4444) : Colors.white)
                              : Colors.transparent,
                          border: Border.all(
                            color: _isError
                                ? const Color(0xFFEF4444)
                                : Colors.white.withOpacity(0.4),
                            width: 2,
                          ),
                        ),
                      );
                    }),
                  ),
                );
              },
            ),

            const Spacer(flex: 2),

            // Bàn phím số Keypad tối giản
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  _buildKeypadRow(['1', '2', '3']),
                  const SizedBox(height: 18),
                  _buildKeypadRow(['4', '5', '6']),
                  const SizedBox(height: 18),
                  _buildKeypadRow(['7', '8', '9']),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildActionKey(
                        child: const Text(
                          'Xóa hết',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        ),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _enteredCode = '');
                        },
                      ),
                      _buildNumberKey('0'),
                      _buildActionKey(
                        child: const Icon(
                          Icons.backspace_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                        onTap: _onDeletePressed,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypadRow(List<String> numbers) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: numbers.map((n) => _buildNumberKey(n)).toList(),
    );
  }

  Widget _buildNumberKey(String number) {
    return InkWell(
      onTap: () => _onDigitPressed(number),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.06),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        alignment: Alignment.center,
        child: Text(
          number,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildActionKey({required Widget child, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

// ============================================================================
// 4B. TRÌNH CHỌN FILE HỆ THỐNG GỐC ANDROID (NATIVE SAF FILE PICKER DỰ PHÒNG)
// ============================================================================
class NativeFilePicker {
  static const MethodChannel _channel = MethodChannel('com.example.passlock/file_picker');

  static Future<Map<String, String>?> pickFile() async {
    try {
      final res = await _channel.invokeMethod<dynamic>('pickFile');
      if (res is Map) {
        return {
          'name': res['name']?.toString() ?? '',
          'content': res['content']?.toString() ?? '',
          'uri': res['uri']?.toString() ?? '',
        };
      }
      return null;
    } on MissingPluginException {
      throw 'Dự án Android chưa liên kết MainActivity.kt (MethodChannel chưa khả dụng). Vui lòng thêm file_picker: ^8.1.7 vào pubspec.yaml và chạy flutter pub get.';
    } on PlatformException catch (pe) {
      throw 'Không thể mở bộ chọn file hệ thống: ${pe.message ?? pe.code}';
    } catch (e) {
      throw 'Lỗi gọi trình chọn tệp: $e';
    }
  }
}

// ============================================================================
// 5. MÀN HÌNH CHÍNH SIÊU GỌN & MỞ PASS TRỰC TIẾP (HOME SCREEN)
// ============================================================================
class HomeScreen extends StatefulWidget {
  final SecureStorageService storageService;
  final VoidCallback onLock;
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const HomeScreen({
    super.key,
    required this.storageService,
    required this.onLock,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<CredentialItem> _credentials = [];
  List<CredentialItem> _filteredCredentials = [];
  bool _isLoading = true;
  String _searchQuery = '';
  late bool _isDarkMode;
  String? _expandedItemId;
  final GoogleDriveBackupService _googleDriveService = GoogleDriveBackupService();

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
    _loadData();
    _googleDriveService.init().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDarkMode != widget.isDarkMode) {
      _isDarkMode = widget.isDarkMode;
    }
  }

  Future<void> _toggleTheme() async {
    final next = !_isDarkMode;
    setState(() => _isDarkMode = next);
    await widget.storageService.saveIsDarkMode(next);
    widget.onThemeChanged(next);
    HapticFeedback.selectionClick();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final items = await widget.storageService.getCredentials();
    setState(() {
      _credentials = items;
      _applySearch();
      _isLoading = false;
    });
  }

  void _applySearch() {
    if (_searchQuery.trim().isEmpty) {
      _filteredCredentials = List.from(_credentials);
    } else {
      final q = _searchQuery.toLowerCase();
      _filteredCredentials = _credentials.where((c) {
        return c.service.toLowerCase().contains(q) ||
            c.username.toLowerCase().contains(q) ||
            c.category.toLowerCase().contains(q);
      }).toList();
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('Đã chép $label vào bộ nhớ tạm!'),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openAddEditModal([CredentialItem? existing]) async {
    final result = await showModalBottomSheet<CredentialItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CredentialDialog(item: existing, isDarkMode: _isDarkMode),
    );

    if (result != null) {
      if (existing != null) {
        await widget.storageService.updateCredential(result);
      } else {
        await widget.storageService.addCredential(result);
      }
      await _loadData();
      _triggerGoogleDriveAutoBackup();
    }
  }

  Future<void> _triggerGoogleDriveAutoBackup() async {
    if (!_googleDriveService.isSignedIn || !_googleDriveService.isAutoBackupEnabled) {
      return;
    }
    final items = await widget.storageService.getCredentials();
    final filename = await _googleDriveService.backupToDrive(items, isAuto: true);
    if (filename != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.cloud_done_rounded, color: Colors.greenAccent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '☁️ Auto-Backup: Đã lưu "$filename" vào thư mục PassLock_Backups trên Google Drive',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _confirmDelete(CredentialItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF0F172A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Xác nhận xóa',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        content: Text(
          'Bạn có chắc muốn xóa "${item.service}" không?',
          style: TextStyle(
            color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF475569),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Hủy',
              style: TextStyle(
                color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.storageService.deleteCredential(item.id);
      await _loadData();
      _triggerGoogleDriveAutoBackup();
    }
  }

  Future<void> _openChangePasscodeDialog() async {
    final oldPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    String? errorMessage;
    bool obscureCurrent = true;
    bool obscureNew = true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _isDarkMode ? const Color(0xFF0F172A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.key_rounded, color: Color(0xFF0284C7), size: 24),
              const SizedBox(width: 8),
              Text(
                'Đổi Mã PIN 6 Số',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mã PIN 6 số bảo vệ kho mật khẩu khi khởi động ứng dụng hoặc khi chuyển ra nền.',
                  style: TextStyle(
                    fontSize: 12,
                    color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 16),

                // 1. PIN hiện tại
                TextField(
                  controller: oldPassController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  obscureText: obscureCurrent,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(
                    color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
                    fontFamily: 'monospace',
                  ),
                  decoration: InputDecoration(
                    labelText: 'Mã PIN hiện tại *',
                    hintText: 'Mặc định ban đầu: 123456',
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: _isDarkMode ? const Color(0xFF64748B) : Colors.grey,
                    ),
                    counterText: '',
                    filled: true,
                    fillColor: _isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    prefixIcon: Icon(
                      Icons.lock_open_rounded,
                      size: 20,
                      color: _isDarkMode ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureCurrent ? Icons.visibility_off : Icons.visibility,
                        size: 18,
                        color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: _isDarkMode ? const Color(0xFF334155) : Colors.grey.shade300,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: _isDarkMode ? const Color(0xFF334155) : Colors.grey.shade200,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),

                // 2. PIN 6 số mới
                TextField(
                  controller: newPassController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  obscureText: obscureNew,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(
                    color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
                    fontFamily: 'monospace',
                  ),
                  decoration: InputDecoration(
                    labelText: 'Mã PIN 6 số mới *',
                    hintText: 'Nhập 6 số mới',
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: _isDarkMode ? const Color(0xFF64748B) : Colors.grey,
                    ),
                    counterText: '',
                    filled: true,
                    fillColor: _isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    prefixIcon: Icon(
                      Icons.key_rounded,
                      size: 20,
                      color: _isDarkMode ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureNew ? Icons.visibility_off : Icons.visibility,
                        size: 18,
                        color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: _isDarkMode ? const Color(0xFF334155) : Colors.grey.shade300,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: _isDarkMode ? const Color(0xFF334155) : Colors.grey.shade200,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),

                // 3. Xác nhận PIN mới
                TextField(
                  controller: confirmPassController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  obscureText: obscureNew,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(
                    color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
                    fontFamily: 'monospace',
                  ),
                  decoration: InputDecoration(
                    labelText: 'Xác nhận mã PIN mới *',
                    hintText: 'Nhập lại đúng 6 số mới',
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: _isDarkMode ? const Color(0xFF64748B) : Colors.grey,
                    ),
                    counterText: '',
                    filled: true,
                    fillColor: _isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    prefixIcon: Icon(
                      Icons.check_circle_outline,
                      size: 20,
                      color: _isDarkMode ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: _isDarkMode ? const Color(0xFF334155) : Colors.grey.shade300,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: _isDarkMode ? const Color(0xFF334155) : Colors.grey.shade200,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),

                if (errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isDarkMode ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isDarkMode ? const Color(0xFF991B1B) : const Color(0xFFF87171),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            errorMessage!,
                            style: TextStyle(
                              color: _isDarkMode ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Hủy',
                style: TextStyle(
                  color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isDarkMode ? const Color(0xFF0284C7) : const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final oldP = oldPassController.text.trim();
                final newP = newPassController.text.trim();
                final confP = confirmPassController.text.trim();

                final isOldValid = await widget.storageService.verifyPasscode(oldP);
                if (!isOldValid) {
                  setDialogState(() {
                    errorMessage = 'Mã PIN hiện tại không chính xác!';
                  });
                  return;
                }

                if (newP.length != 6 || !RegExp(r'^[0-9]{6}$').hasMatch(newP)) {
                  setDialogState(() {
                    errorMessage = 'Mã PIN mới phải gồm đúng 6 chữ số!';
                  });
                  return;
                }

                if (newP != confP) {
                  setDialogState(() {
                    errorMessage = 'Mã PIN xác nhận không trùng khớp!';
                  });
                  return;
                }

                await widget.storageService.updatePasscode(newP);
                Navigator.pop(ctx);
                HapticFeedback.mediumImpact();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 18),
                          SizedBox(width: 8),
                          Text('Đã đổi mã PIN 6 số thành công!'),
                        ],
                      ),
                      backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('Lưu Mã PIN Mới'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFileFromDevice() async {
    try {
      String? fileContent;
      String? fileName;

      // 1. Thử dùng thư viện chuẩn file_picker (file_picker: ^8.1.7)
      try {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['csv', 'txt', 'json'],
          withData: true,
        );

        if (result == null || result.files.isEmpty) {
          // Người dùng chủ động hủy hoặc đóng trình chọn tệp
          return;
        }

        final file = result.files.first;
        fileName = file.name;

        if (file.bytes != null) {
          fileContent = utf8.decode(file.bytes!, allowMalformed: true);
        } else if (file.path != null) {
          final ioFile = File(file.path!);
          if (await ioFile.exists()) {
            fileContent = await ioFile.readAsString();
          }
        }
      } catch (pickerErr) {
        // 2. Dự phòng: Thử qua Native SAF MethodChannel nếu cần
        final picked = await NativeFilePicker.pickFile();
        if (picked == null) {
          return;
        }
        fileName = picked['name'];
        fileContent = picked['content'];
      }

      if (fileContent == null || fileContent.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File "${fileName ?? "đã chọn"}" trống hoặc không có nội dung hợp lệ!'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final imported = BackupService.parseUniversal(fileContent);
      if (imported.isNotEmpty) {
        for (final item in imported) {
          await widget.storageService.addCredential(item);
        }
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Đã nạp thành công ${imported.length} tài khoản từ "$fileName"!'),
                  ),
                ],
              ),
              backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không tìm thấy tài khoản hợp lệ trong file đã chọn (.csv, .txt, .json)!'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.amber, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Không Thể Mở Trình Chọn File',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chi tiết lỗi: ${e.toString()}',
                  style: TextStyle(
                    fontSize: 13,
                    color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.3)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cách khắc phục khi tự build:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '1. Đảm bảo file pubspec.yaml có: file_picker: ^8.1.7\n2. Chạy lệnh "flutter pub get" trước khi gõ "flutter build apk".',
                        style: TextStyle(fontSize: 11, color: Color(0xFFE2E8F0)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Đóng'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Thử Lại'),
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  _pickFileFromDevice();
                },
              ),
            ],
          ),
        );
      }
    }
  }

  Future<GoogleAccountUser?> _showGoogleSignInDialog() async {
    final emailCtrl = TextEditingController(text: 'nhatvu999@gmail.com');
    final nameCtrl = TextEditingController(text: 'Nhật Vũ');
    final tokenCtrl = TextEditingController();

    return showDialog<GoogleAccountUser>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF0F172A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.account_circle_rounded, color: Color(0xFF4285F4), size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Sign in with Google',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Liên kết tài khoản Google để tự động sao lưu file Excel (.csv) vào thư mục riêng PassLock_Backups:',
                style: TextStyle(
                  fontSize: 12,
                  color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(
                  fontSize: 13,
                  color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  labelText: 'Email Google Drive *',
                  hintText: 'example@gmail.com',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nameCtrl,
                style: TextStyle(
                  fontSize: 13,
                  color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  labelText: 'Tên hiển thị',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: tokenCtrl,
                style: TextStyle(
                  fontSize: 12,
                  color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  labelText: 'Google Drive OAuth Token (Tùy chọn)',
                  hintText: 'Để trống nếu dùng chế độ đồng bộ thư mục máy/Drive',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Hủy'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.check_circle_outline, size: 16),
            label: const Text('Kết nối Google Drive'),
            onPressed: () async {
              final user = await _googleDriveService.signInWithAccount(
                email: emailCtrl.text,
                displayName: nameCtrl.text,
                accessToken: tokenCtrl.text,
              );
              if (mounted) {
                Navigator.pop(dialogCtx, user);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showSpreadsheetPreviewDialog(GoogleDriveBackupFile file) async {
    final content = await _googleDriveService.downloadBackupContent(file.id);
    if (content == null || !mounted) return;

    final parsedItems = BackupService.parseUniversal(content);
    bool showPasswords = false;

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setSheetState) => AlertDialog(
          backgroundColor: _isDarkMode ? const Color(0xFF0F172A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          title: Row(
            children: [
              const Icon(Icons.table_chart_rounded, color: Color(0xFF10B981), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'PassLock_Backups/ · ${parsedItems.length} tài khoản',
                      style: TextStyle(
                        fontSize: 11,
                        color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  showPasswords ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 20,
                  color: const Color(0xFF38BDF8),
                ),
                tooltip: showPasswords ? 'Ẩn mật khẩu' : 'Hiện mật khẩu',
                onPressed: () => setSheetState(() => showPasswords = !showPasswords),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 36,
                  dataRowMinHeight: 34,
                  dataRowMaxHeight: 44,
                  columnSpacing: 16,
                  columns: const [
                    DataColumn(label: Text('Dịch vụ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('Tài khoản', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('Mật khẩu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('Danh mục', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  ],
                  rows: parsedItems.map((it) {
                    return DataRow(
                      cells: [
                        DataCell(Text(it.service, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                        DataCell(Text(it.username, style: const TextStyle(fontSize: 12))),
                        DataCell(
                          Text(
                            showPasswords ? it.password : '••••••••',
                            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                          ),
                        ),
                        DataCell(Text(it.category, style: const TextStyle(fontSize: 11))),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.share_rounded, size: 16),
              label: const Text('Tải về / Lưu Drive'),
              onPressed: () async {
                if (file.localPath != null) {
                  await Share.shareXFiles(
                    [XFile(file.localPath!, mimeType: 'text/csv;charset=utf-8', name: file.name)],
                    subject: file.name,
                  );
                }
              },
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Đóng'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showGoogleDriveBackupsList() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final backups = await _googleDriveService.listBackups();
    if (mounted) Navigator.pop(context);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _isDarkMode ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _isDarkMode ? const Color(0xFF334155) : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Lịch Sử Sao Lưu Trên Google Drive',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Thư mục: PassLock_Backups/ (${backups.length} bản sao lưu)',
              style: TextStyle(
                fontSize: 12,
                color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 12),
            if (backups.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: Text('Chưa có bản sao lưu nào trong PassLock_Backups')),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: backups.length,
                  separatorBuilder: (_, __) => Divider(
                    color: _isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  ),
                  itemBuilder: (context, idx) {
                    final item = backups[idx];
                    final dateStr = GoogleDriveBackupService.formatDisplayDate(item.createdAt.toLocal());
                    final sizeKb = (item.sizeBytes / 1024).toStringAsFixed(1);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.table_chart_outlined, color: Color(0xFF38BDF8)),
                      title: Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      subtitle: Text(
                        '$dateStr · $sizeKb KB',
                        style: TextStyle(
                          fontSize: 11,
                          color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF10B981)),
                            tooltip: 'Xem trực tiếp bảng tính Excel',
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showSpreadsheetPreviewDialog(item);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.download_rounded, size: 18, color: Color(0xFF38BDF8)),
                            tooltip: 'Tải về hoặc lưu lên Google Drive',
                            onPressed: () async {
                              if (item.localPath != null) {
                                await Share.shareXFiles(
                                  [XFile(item.localPath!, mimeType: 'text/csv;charset=utf-8', name: item.name)],
                                  subject: item.name,
                                );
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.restore_rounded, size: 18, color: Colors.amber),
                            tooltip: 'Khôi phục bản sao lưu này',
                            onPressed: () async {
                              Navigator.pop(ctx);
                              final content = await _googleDriveService.downloadBackupContent(item.id);
                              if (content != null) {
                                final imported = BackupService.parseUniversal(content);
                                for (final cred in imported) {
                                  await widget.storageService.addCredential(cred);
                                }
                                await _loadData();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('✓ Đã khôi phục ${imported.length} tài khoản từ "${item.name}"'),
                                      backgroundColor: const Color(0xFF10B981),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openBackupDialog() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _isDarkMode ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _isDarkMode ? const Color(0xFF334155) : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Sao Lưu & Khôi Phục Dữ Liệu',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tự động đồng bộ Google Drive hoặc xuất/nhập file bảo mật trên thiết bị:',
                style: TextStyle(
                  fontSize: 12,
                  color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),

              // 0. Thẻ Google Drive Cloud Sync & Auto-Backup
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _googleDriveService.isSignedIn
                        ? const Color(0xFF0284C7).withOpacity(0.4)
                        : (_isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.cloud_sync_rounded, color: Color(0xFF38BDF8), size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Google Drive Auto-Backup (Excel)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                _googleDriveService.isSignedIn
                                    ? (_googleDriveService.currentUser?.email ?? 'Đã kết nối Google Drive')
                                    : 'Tự động lưu file Excel vào thư mục PassLock_Backups',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_googleDriveService.isSignedIn)
                          IconButton(
                            icon: const Icon(Icons.logout_rounded, size: 18, color: Colors.redAccent),
                            onPressed: () async {
                              await _googleDriveService.signOut();
                              setModalState(() {});
                              if (mounted) setState(() {});
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (!_googleDriveService.isSignedIn)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.login_rounded, size: 18),
                          label: const Text('Sign in with Google', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            final acc = await _showGoogleSignInDialog();
                            setModalState(() {});
                            if (mounted) setState(() {});
                            if (acc != null && mounted) {
                              await _googleDriveService.backupToDrive(_credentials, isAuto: true);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('✓ Đã kết nối Google Drive (${acc.email}) & tạo bản sao lưu đầu tiên!'),
                                  backgroundColor: const Color(0xFF10B981),
                                ),
                              );
                            }
                          },
                        ),
                      )
                    else ...[
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          'Tự động sao lưu khi Thêm / Sửa / Xóa',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        subtitle: Text(
                          'Lưu vào thư mục PassLock_Backups kèm ngày giờ',
                          style: TextStyle(
                            fontSize: 10,
                            color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        value: _googleDriveService.isAutoBackupEnabled,
                        activeColor: const Color(0xFF38BDF8),
                        onChanged: (val) async {
                          await _googleDriveService.setAutoBackupEnabled(val);
                          setModalState(() {});
                          if (mounted) setState(() {});
                        },
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                              label: const Text('Sao Lưu Ngay', style: TextStyle(fontSize: 12)),
                              onPressed: () async {
                                Navigator.pop(ctx);
                                final name = await _googleDriveService.backupToDrive(_credentials);
                                if (name != null && mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('✓ Đã lưu "$name" vào PassLock_Backups!'),
                                      backgroundColor: const Color(0xFF10B981),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0284C7),
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.table_chart_outlined, size: 16),
                              label: const Text('Xem & Tải File', style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _showGoogleDriveBackupsList();
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

            // 1. Nhập file bằng app duyệt file
            ListTile(
              leading: CircleAvatar(
                backgroundColor: _isDarkMode ? const Color(0xFF0284C7).withOpacity(0.2) : const Color(0xFFE0F2FE),
                child: Icon(
                  Icons.file_open_rounded,
                  color: _isDarkMode ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                ),
              ),
              title: Text(
                'Nhập file sao lưu từ thiết bị (.csv, .txt, .json)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              subtitle: Text(
                'Mở app duyệt file của máy (Tệp, Downloads, Google Drive, Thẻ nhớ SD...) để chọn file nạp lại',
                style: TextStyle(
                  fontSize: 12,
                  color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickFileFromDevice();
              },
            ),
            Divider(color: _isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),

            // 2. Xuất CSV / Excel
            ListTile(
              leading: CircleAvatar(
                backgroundColor: _isDarkMode ? const Color(0xFF16A34A).withOpacity(0.2) : const Color(0xFFDCFCE7),
                child: Icon(
                  Icons.table_chart_outlined,
                  color: _isDarkMode ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
                ),
              ),
              title: Text(
                'Xuất file Excel / CSV (.csv)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              subtitle: Text(
                'Mở xem và chỉnh sửa được bằng Excel, Google Sheets',
                style: TextStyle(
                  fontSize: 12,
                  color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                BackupService.exportAndShare(context: context, items: _credentials, format: 'csv');
              },
            ),

            // 3. Xuất TXT
            ListTile(
              leading: CircleAvatar(
                backgroundColor: _isDarkMode ? const Color(0xFF2563EB).withOpacity(0.2) : const Color(0xFFDBEAFE),
                child: Icon(
                  Icons.description_outlined,
                  color: _isDarkMode ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                ),
              ),
              title: Text(
                'Xuất file Văn bản (.txt)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              subtitle: Text(
                'Xem trên Notepad, Word, lưu trữ cá nhân hoặc gửi tin nhắn',
                style: TextStyle(
                  fontSize: 12,
                  color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                BackupService.exportAndShare(context: context, items: _credentials, format: 'txt');
              },
            ),

            // 4. Xuất JSON
            ListTile(
              leading: CircleAvatar(
                backgroundColor: _isDarkMode ? const Color(0xFF0891B2).withOpacity(0.2) : const Color(0xFFCFFAFE),
                child: Icon(
                  Icons.code_rounded,
                  color: _isDarkMode ? const Color(0xFF22D3EE) : const Color(0xFF0891B2),
                ),
              ),
              title: Text(
                'Xuất file JSON (.json)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              subtitle: Text(
                'Bản sao lưu chuẩn kỹ thuật đầy đủ cấu trúc và thời gian',
                style: TextStyle(
                  fontSize: 12,
                  color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                BackupService.exportAndShare(context: context, items: _credentials, format: 'json');
              },
            ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkMode ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: _isDarkMode ? const Color(0xFF090D16) : Colors.white,
        title: Row(
          children: [
            Icon(
              Icons.shield_outlined,
              color: _isDarkMode ? const Color(0xFF38BDF8) : const Color(0xFF0F172A),
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              'PassLock Vault',
              style: TextStyle(
                color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Text(
              '${_filteredCredentials.length} mục',
              style: TextStyle(
                fontSize: 12,
                color: _isDarkMode ? const Color(0xFF94A3B8) : Colors.grey,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          // Nút chuyển đổi giao diện Sáng / Tối
          IconButton(
            tooltip: _isDarkMode ? 'Chuyển sang Giao diện Sáng' : 'Chuyển sang Giao diện Tối',
            icon: Icon(
              _isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: _isDarkMode ? const Color(0xFFFACC15) : const Color(0xFF475569),
            ),
            onPressed: _toggleTheme,
          ),
          IconButton(
            tooltip: 'Đổi mã PIN 6 số',
            icon: const Icon(Icons.key_rounded, color: Color(0xFF0284C7)),
            onPressed: _openChangePasscodeDialog,
          ),
          IconButton(
            tooltip: 'Sao lưu & Cài đặt',
            icon: const Icon(Icons.folder_shared_outlined, color: Color(0xFF0284C7)),
            onPressed: _openBackupDialog,
          ),
          IconButton(
            tooltip: 'Khóa ngay',
            icon: Icon(
              Icons.lock_outline_rounded,
              color: _isDarkMode ? Colors.white70 : const Color(0xFF0F172A),
            ),
            onPressed: widget.onLock,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
            child: TextField(
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                  _applySearch();
                });
              },
              style: TextStyle(color: _isDarkMode ? Colors.white : const Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'Tìm kiếm dịch vụ, email...',
                hintStyle: TextStyle(color: _isDarkMode ? const Color(0xFF64748B) : Colors.grey),
                prefixIcon: Icon(Icons.search, size: 18, color: _isDarkMode ? const Color(0xFF94A3B8) : Colors.grey),
                filled: true,
                fillColor: _isDarkMode ? const Color(0xFF131B2E) : Colors.white,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _isDarkMode ? const Color(0xFF1E293B) : Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _isDarkMode ? const Color(0xFF1E293B) : Colors.grey.shade200),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCredentials.isEmpty
                    ? Center(
                        child: Text(
                          'Chưa có tài khoản nào',
                          style: TextStyle(color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        itemCount: _filteredCredentials.length,
                        itemBuilder: (context, index) {
                          final item = _filteredCredentials[index];
                          return _buildAccountCard(item);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddEditModal(),
        backgroundColor: _isDarkMode ? const Color(0xFF0284C7) : const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Thêm mới', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildAccountCard(CredentialItem item) {
    final isExpanded = _expandedItemId == item.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpanded
              ? const Color(0xFF0284C7)
              : (_isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          width: isExpanded ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDarkMode ? 0.25 : 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // DÒNG SIÊU GỌN (1-2 DÒNG): Bấm vào tên tài khoản hiển thị mật khẩu ngay
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() {
                _expandedItemId = isExpanded ? null : item.id;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: _isDarkMode
                        ? const Color(0xFF38BDF8).withOpacity(0.15)
                        : const Color(0xFF0F172A).withOpacity(0.07),
                    child: Text(
                      item.service.isNotEmpty ? item.service[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: _isDarkMode ? const Color(0xFF38BDF8) : const Color(0xFF0F172A),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Dòng 1: Tên dịch vụ + Tag; Dòng 2: Username
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.service,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: _isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.category,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.username,
                          style: TextStyle(
                            fontSize: 12,
                            color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            fontFamily: 'monospace',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Nút copy username
                  IconButton(
                    tooltip: 'Sao chép Username',
                    icon: Icon(
                      Icons.copy_rounded,
                      size: 16,
                      color: _isDarkMode ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                    onPressed: () => _copyToClipboard(item.username, 'Tài khoản'),
                    visualDensity: VisualDensity.compact,
                  ),

                  // Mũi tên chỉ thị
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: isExpanded
                        ? const Color(0xFF0284C7)
                        : (_isDarkMode ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // KHU VỰC HIỂN THỊ MẬT KHẨU TRỰC TIẾP KHI BẤM VÀO TÀI KHOẢN (LUÔN HIỆN RÕ DẠNG VĂN BẢN)
          if (isExpanded)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              decoration: BoxDecoration(
                color: _isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
              ),
              child: Column(
                children: [
                  Divider(
                    height: 12,
                    color: _isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  ),

                  // Khung Mật khẩu dạng rõ trực tiếp 100%
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isDarkMode ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.key_outlined, size: 16, color: Color(0xFF0284C7)),
                        const SizedBox(width: 8),
                        Text(
                          'Pass: ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            item.password,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
                              fontFamily: 'monospace',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // NÚT COPY PASS: CHỈ ĐỂ LẠI ICON, BỎ HẲN CHỮ COPY PASS
                        IconButton(
                          tooltip: 'Sao chép mật khẩu',
                          style: IconButton.styleFrom(
                            backgroundColor: _isDarkMode
                                ? const Color(0xFF0284C7).withOpacity(0.2)
                                : const Color(0xFF0F172A),
                            foregroundColor: _isDarkMode ? const Color(0xFF38BDF8) : Colors.white,
                            padding: const EdgeInsets.all(7),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.copy_rounded, size: 15),
                          onPressed: () => _copyToClipboard(item.password, 'Mật khẩu'),
                        ),
                      ],
                    ),
                  ),

                  if (item.notes != null && item.notes!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Ghi chú: ${item.notes}',
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 6),

                  // Nút Sửa & Xóa
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: _isDarkMode ? const Color(0xFF38BDF8) : const Color(0xFF0F172A),
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 15),
                        label: const Text('Sửa', style: TextStyle(fontSize: 12)),
                        onPressed: () => _openAddEditModal(item),
                      ),
                      const SizedBox(width: 6),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: const Color(0xFFEF4444),
                        ),
                        icon: const Icon(Icons.delete_outline, size: 15),
                        label: const Text('Xóa', style: TextStyle(fontSize: 12)),
                        onPressed: () => _confirmDelete(item),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// 6. MODAL THÊM & SỬA TÀI KHOẢN (CREDENTIAL DIALOG)
// ============================================================================
class CredentialDialog extends StatefulWidget {
  final CredentialItem? item;
  final bool isDarkMode;

  const CredentialDialog({super.key, this.item, this.isDarkMode = false});

  @override
  State<CredentialDialog> createState() => _CredentialDialogState();
}

class _CredentialDialogState extends State<CredentialDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _serviceController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _notesController;
  String _selectedCategory = 'Mạng xã hội';
  bool _obscurePassword = false;

  final List<String> _categories = [
    'Mạng xã hội',
    'Email',
    'Ngân hàng',
    'Công việc',
    'Khác',
  ];

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    _serviceController = TextEditingController(text: it?.service ?? '');
    _usernameController = TextEditingController(text: it?.username ?? '');
    _passwordController = TextEditingController(text: it?.password ?? '');
    _notesController = TextEditingController(text: it?.notes ?? '');
    if (it != null && _categories.contains(it.category)) {
      _selectedCategory = it.category;
    }
  }

  @override
  void dispose() {
    _serviceController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _generateStrongPassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#%^&*()_+=';
    final random = Random.secure();
    final newPass = List.generate(16, (i) => chars[random.nextInt(chars.length)]).join();
    setState(() {
      _passwordController.text = newPass;
      _obscurePassword = false;
    });
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final newItem = CredentialItem(
        id: widget.item?.id ?? const Uuid().v4(),
        service: _serviceController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        category: _selectedCategory,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        updatedAt: now,
      );
      Navigator.pop(context, newItem);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEdit ? 'Chỉnh sửa tài khoản' : 'Thêm tài khoản mới',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: widget.isDarkMode ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _serviceController,
                style: TextStyle(color: widget.isDarkMode ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  labelText: 'Dịch vụ / Tên website *',
                  labelStyle: TextStyle(color: widget.isDarkMode ? const Color(0xFF94A3B8) : null),
                  hintText: 'Ví dụ: Google, Facebook, Techcombank',
                  hintStyle: TextStyle(color: widget.isDarkMode ? const Color(0xFF64748B) : null),
                  filled: widget.isDarkMode,
                  fillColor: widget.isDarkMode ? const Color(0xFF1E293B) : null,
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: widget.isDarkMode ? const Color(0xFF334155) : Colors.grey.shade300),
                  ),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Nhập tên dịch vụ' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                dropdownColor: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                style: TextStyle(color: widget.isDarkMode ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  labelText: 'Danh mục',
                  labelStyle: TextStyle(color: widget.isDarkMode ? const Color(0xFF94A3B8) : null),
                  filled: widget.isDarkMode,
                  fillColor: widget.isDarkMode ? const Color(0xFF1E293B) : null,
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: widget.isDarkMode ? const Color(0xFF334155) : Colors.grey.shade300),
                  ),
                ),
                items: _categories
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(
                            c,
                            style: TextStyle(color: widget.isDarkMode ? Colors.white : const Color(0xFF0F172A)),
                          ),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _usernameController,
                style: TextStyle(color: widget.isDarkMode ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  labelText: 'Tài khoản / Email / SĐT *',
                  labelStyle: TextStyle(color: widget.isDarkMode ? const Color(0xFF94A3B8) : null),
                  filled: widget.isDarkMode,
                  fillColor: widget.isDarkMode ? const Color(0xFF1E293B) : null,
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: widget.isDarkMode ? const Color(0xFF334155) : Colors.grey.shade300),
                  ),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Nhập tài khoản' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: TextStyle(
                  color: widget.isDarkMode ? Colors.white : const Color(0xFF0F172A),
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  labelText: 'Mật khẩu *',
                  labelStyle: TextStyle(color: widget.isDarkMode ? const Color(0xFF94A3B8) : null),
                  filled: widget.isDarkMode,
                  fillColor: widget.isDarkMode ? const Color(0xFF1E293B) : null,
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: widget.isDarkMode ? const Color(0xFF334155) : Colors.grey.shade300),
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Tạo mật khẩu mạnh',
                        icon: const Icon(Icons.auto_fix_high, color: Color(0xFF38BDF8)),
                        onPressed: _generateStrongPassword,
                      ),
                      IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: widget.isDarkMode ? const Color(0xFF94A3B8) : null,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ],
                  ),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Nhập mật khẩu' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _notesController,
                style: TextStyle(color: widget.isDarkMode ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  labelText: 'Ghi chú (Tùy chọn)',
                  labelStyle: TextStyle(color: widget.isDarkMode ? const Color(0xFF94A3B8) : null),
                  filled: widget.isDarkMode,
                  fillColor: widget.isDarkMode ? const Color(0xFF1E293B) : null,
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: widget.isDarkMode ? const Color(0xFF334155) : Colors.grey.shade300),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.isDarkMode ? const Color(0xFF0284C7) : const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _submit,
                  child: Text(isEdit ? 'Lưu thay đổi' : 'Thêm mới'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 7. GỐC ỨNG DỤNG & VÒNG ĐỜI AUTO-LOCK KHI THOÁT RA NỀN (PASSLOCK APP & LIFECYCLE)
// ============================================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final storageService = SecureStorageService();
  await storageService.init();

  runApp(PassLockApp(storageService: storageService));
}

class PassLockApp extends StatefulWidget {
  final SecureStorageService storageService;

  const PassLockApp({super.key, required this.storageService});

  @override
  State<PassLockApp> createState() => _PassLockAppState();
}

class _PassLockAppState extends State<PassLockApp> with WidgetsBindingObserver {
  bool _isUnlocked = false;
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initTheme();
  }

  Future<void> _initTheme() async {
    final dark = await widget.storageService.getIsDarkMode();
    if (mounted) {
      setState(() => _isDarkMode = dark);
    }
  }

  void _onThemeChanged(bool isDark) {
    setState(() => _isDarkMode = isDark);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Tự động khóa lại màn hình khi ứng dụng bị ẩn hoặc chuyển ra nền
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_isUnlocked) {
        setState(() {
          _isUnlocked = false;
        });
      }
    }
  }

  void _onUnlockSuccess() {
    setState(() {
      _isUnlocked = true;
    });
  }

  void _onManualLock() {
    setState(() {
      _isUnlocked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PassLock',
      debugShowCheckedModeBanner: false,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F172A),
          brightness: Brightness.light,
          primary: const Color(0xFF0F172A),
          surface: const Color(0xFFF8FAFC),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 1,
          iconTheme: IconThemeData(color: Color(0xFF0F172A)),
          titleTextStyle: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF38BDF8),
          brightness: Brightness.dark,
          primary: const Color(0xFF38BDF8),
          surface: const Color(0xFF131B2E),
        ),
        scaffoldBackgroundColor: const Color(0xFF090D16),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF090D16),
          elevation: 0,
          scrolledUnderElevation: 1,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: _isUnlocked
          ? HomeScreen(
              storageService: widget.storageService,
              onLock: _onManualLock,
              isDarkMode: _isDarkMode,
              onThemeChanged: _onThemeChanged,
            )
          : PasscodeScreen(
              storageService: widget.storageService,
              onUnlock: _onUnlockSuccess,
            ),
    );
  }
}
