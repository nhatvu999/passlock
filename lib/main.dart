import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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
// 4B. TRÌNH CHỌN FILE HỆ THỐNG GỐC ANDROID (NATIVE SAF FILE PICKER)
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
      throw 'Dự án Android chưa liên kết MainActivity.kt. Đang chuyển sang Kho Tệp Sao Lưu trên máy...';
    } on PlatformException catch (pe) {
      throw 'Không thể gọi trình duyệt file: ${pe.message ?? pe.code}';
    } catch (e) {
      throw 'Không thể mở bộ chọn file: $e';
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

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
    _loadData();
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
      _loadData();
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
      _loadData();
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

  Future<void> _importFromFile(File file) async {
    try {
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Không tìm thấy file: ${file.path}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      String content;
      try {
        content = await file.readAsString(encoding: utf8);
      } catch (_) {
        final bytes = await file.readAsBytes();
        content = utf8.decode(bytes, allowMalformed: true);
      }
      final imported = BackupService.parseUniversal(content);
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
                    child: Text('Đã nạp thành công ${imported.length} tài khoản từ file!'),
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
              content: Text('Không tìm thấy tài khoản hợp lệ trong file!'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi đọc file: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _pickFileFromDevice() async {
    try {
      final picked = await NativeFilePicker.pickFile();
      if (picked != null) {
        final content = picked['content'] ?? '';
        final fileName = picked['name'] ?? 'tệp sao lưu';
        if (content.trim().isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('File đã chọn không có nội dung!'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }

        final imported = BackupService.parseUniversal(content);
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
                content: Text('Không tìm thấy tài khoản hợp lệ trong file đã chọn!'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
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
                const Icon(Icons.folder_open_rounded, color: Color(0xFF0284C7), size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bộ Chọn File Hệ Thống',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              'Trình chọn file hệ thống chưa phản hồi. Bạn có thể duyệt trực tiếp Thư Mục Sao Lưu trên máy hoặc Dán nội dung sao lưu từ Clipboard!',
              style: TextStyle(
                fontSize: 13,
                color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF475569),
              ),
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
                icon: const Icon(Icons.folder_shared, size: 16),
                label: const Text('Duyệt Thư Mục Máy'),
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  _openFolderExplorer();
                },
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _openFolderExplorer() async {
    final List<Map<String, dynamic>> rootDirs = [];
    final List<File> discoveredBackups = [];
    Directory? initialDir;

    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${appDocDir.path}/PassLock_Backups');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      rootDirs.add({
        'title': '⭐ Sao Lưu PassLock',
        'dir': backupDir,
        'badge': 'An Toàn 100%',
      });
      rootDirs.add({
        'title': '📂 Tài Liệu App',
        'dir': appDocDir,
        'badge': 'Nội Bộ',
      });
      initialDir = backupDir;

      // Quét tìm tất cả các file sao lưu có sẵn trong bộ nhớ an toàn của app
      for (final d in [backupDir, appDocDir]) {
        if (d.existsSync()) {
          for (final f in d.listSync()) {
            if (f is File) {
              final lower = f.path.toLowerCase();
              if (lower.endsWith('.csv') || lower.endsWith('.txt') || lower.endsWith('.json')) {
                discoveredBackups.add(f);
              }
            }
          }
        }
      }
    } catch (_) {}

    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        for (final f in tempDir.listSync()) {
          if (f is File && f.path.contains('passlock_backup')) {
            if (!discoveredBackups.any((b) => b.path == f.path)) {
              discoveredBackups.add(f);
            }
          }
        }
      }
    } catch (_) {}

    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        rootDirs.add({
          'title': '💾 Bộ Nhớ Ngoài',
          'dir': extDir,
          'badge': 'SD',
        });
        if (extDir.existsSync()) {
          for (final f in extDir.listSync()) {
            if (f is File) {
              final lower = f.path.toLowerCase();
              if (lower.endsWith('.csv') || lower.endsWith('.txt') || lower.endsWith('.json')) {
                if (!discoveredBackups.any((b) => b.path == f.path)) {
                  discoveredBackups.add(f);
                }
              }
            }
          }
        }
      }
    } catch (_) {}

    final dlDir = Directory('/storage/emulated/0/Download');
    rootDirs.add({
      'title': '📥 Tải Về (Download)',
      'dir': dlDir,
      'badge': 'Máy',
    });

    Directory currentDir = initialDir ?? dlDir;

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _isDarkMode ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setExplorerState) {
          List<FileSystemEntity> entities = [];
          String? readError;
          try {
            if (currentDir.existsSync()) {
              entities = currentDir.listSync();
              entities.sort((a, b) {
                final aIsDir = a is Directory;
                final bIsDir = b is Directory;
                if (aIsDir && !bIsDir) return -1;
                if (!aIsDir && bIsDir) return 1;
                return a.path.toLowerCase().compareTo(b.path.toLowerCase());
              });
            } else {
              readError = 'Thư mục không tồn tại';
            }
          } catch (e) {
            readError = 'Android Scoped Storage giới hạn đọc trực tiếp thư mục này.';
          }

          final parentDir = currentDir.parent;
          final canGoUp = currentDir.path != '/' && currentDir.path != parentDir.path;

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.folder_shared_outlined, color: Color(0xFF0284C7), size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Duyệt Cây Thư Mục Thiết Bị',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                      color: _isDarkMode ? const Color(0xFF94A3B8) : Colors.grey,
                    ),
                  ],
                ),

                // Thanh phím tắt tiện ích: Bộ chọn file máy + Dán Clipboard
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                            side: BorderSide(color: const Color(0xFF0284C7).withOpacity(0.5)),
                          ),
                          icon: const Icon(Icons.file_open, size: 14, color: Color(0xFF38BDF8)),
                          label: const Text('App Duyệt File Máy', style: TextStyle(fontSize: 11, color: Color(0xFF38BDF8))),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _pickFileFromDevice();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                            side: BorderSide(color: Colors.purple.withOpacity(0.5)),
                          ),
                          icon: const Icon(Icons.paste, size: 14, color: Colors.purpleAccent),
                          label: const Text('Dán Clipboard', style: TextStyle(fontSize: 11, color: Colors.purpleAccent)),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showImportDialog();
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Danh sách tệp sao lưu đã phát hiện sẵn trên máy (nếu có)
                if (discoveredBackups.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF38BDF8)),
                            const SizedBox(width: 6),
                            Text(
                              'Tệp sao lưu sẵn có trên máy (${discoveredBackups.length}):',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: discoveredBackups.map((bf) {
                              final bName = bf.path.split('/').last;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ActionChip(
                                  avatar: const Icon(Icons.file_present, size: 14, color: Colors.white),
                                  backgroundColor: const Color(0xFF0284C7),
                                  label: Text(
                                    bName.length > 25 ? '${bName.substring(0, 22)}...' : bName,
                                    style: const TextStyle(fontSize: 11, color: Colors.white),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _importFromFile(bf);
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Lựa chọn nhanh các thư mục chính (Quick Folder Tabs)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: rootDirs.map((r) {
                      final rDir = r['dir'] as Directory;
                      final isSelected = currentDir.path.startsWith(rDir.path);
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(r['title'] as String, style: const TextStyle(fontSize: 11)),
                          selected: isSelected,
                          onSelected: (_) {
                            setExplorerState(() {
                              currentDir = rDir;
                            });
                          },
                          selectedColor: const Color(0xFF0284C7).withOpacity(0.3),
                          backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? const Color(0xFF38BDF8)
                                : (_isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),

                // Đường dẫn thư mục hiện tại & nút Lên thư mục cha
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      if (canGoUp)
                        InkWell(
                          onTap: () {
                            setExplorerState(() {
                              currentDir = parentDir;
                            });
                          },
                          child: const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: Icon(Icons.arrow_upward, size: 16, color: Color(0xFF0284C7)),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          currentDir.path,
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: _isDarkMode ? const Color(0xFF38BDF8) : const Color(0xFF0369A1),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                if (readError != null)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.lock_clock_outlined, size: 40, color: Colors.amber),
                            const SizedBox(height: 10),
                            Text(
                              readError!,
                              style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Hệ điều hành Android bảo mật thư mục này. Bạn có thể mở Trình Duyệt File của máy để chọn tự do:',
                              style: TextStyle(
                                fontSize: 11,
                                color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0284C7),
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.file_open, size: 16),
                              label: const Text('Mở Trình Chọn File Hệ Thống (SAF)'),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _pickFileFromDevice();
                              },
                            ),
                            if (rootDirs.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              TextButton.icon(
                                icon: const Icon(Icons.star_rounded, size: 16, color: Color(0xFF38BDF8)),
                                label: const Text('Về Thư Mục Sao Lưu PassLock'),
                                onPressed: () {
                                  setExplorerState(() {
                                    currentDir = rootDirs.first['dir'] as Directory;
                                  });
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: entities.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.folder_open, size: 44, color: _isDarkMode ? const Color(0xFF334155) : Colors.grey.shade400),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Thư mục hiện tại chưa có file',
                                    style: TextStyle(
                                      color: _isDarkMode ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Bạn có thể dùng Bộ Chọn File Hệ Thống để tìm file trong Download, Drive hoặc Thẻ nhớ.',
                                    style: TextStyle(
                                      color: _isDarkMode ? const Color(0xFF64748B) : Colors.grey,
                                      fontSize: 11,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0284C7),
                                      foregroundColor: Colors.white,
                                    ),
                                    icon: const Icon(Icons.file_open, size: 16),
                                    label: const Text('Mở Bộ Chọn Tệp Máy'),
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      _pickFileFromDevice();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: entities.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: _isDarkMode ? const Color(0xFF1E293B) : Colors.grey.shade200,
                            ),
                            itemBuilder: (context, index) {
                              final item = entities[index];
                              final isDir = item is Directory;
                              final name = item.path.split('/').last;
                              final lower = name.toLowerCase();
                              final isSupportedFile = !isDir &&
                                  (lower.endsWith('.csv') ||
                                      lower.endsWith('.txt') ||
                                      lower.endsWith('.json') ||
                                      lower.endsWith('.tsv') ||
                                      lower.endsWith('.bak') ||
                                      lower.endsWith('.dat'));

                              String fileSizeStr = '';
                              if (!isDir && item is File) {
                                try {
                                  final bytes = item.lengthSync();
                                  fileSizeStr = bytes > 1024
                                      ? '${(bytes / 1024).toStringAsFixed(1)} KB'
                                      : '${bytes} B';
                                } catch (_) {}
                              }

                              return ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                                leading: Icon(
                                  isDir
                                      ? Icons.folder
                                      : isSupportedFile
                                          ? (lower.endsWith('.csv')
                                              ? Icons.table_chart_outlined
                                              : lower.endsWith('.json')
                                                  ? Icons.code_rounded
                                                  : Icons.description_outlined)
                                          : Icons.insert_drive_file_outlined,
                                  color: isDir
                                      ? const Color(0xFFF59E0B)
                                      : isSupportedFile
                                          ? (lower.endsWith('.csv')
                                              ? Colors.green
                                              : lower.endsWith('.json')
                                                  ? Colors.cyan
                                                  : Colors.blue)
                                          : Colors.grey,
                                  size: 22,
                                ),
                                title: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSupportedFile || isDir ? FontWeight.w600 : FontWeight.normal,
                                    color: isSupportedFile
                                        ? (_isDarkMode ? Colors.white : const Color(0xFF0F172A))
                                        : (isDir
                                            ? (_isDarkMode ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B))
                                            : (_isDarkMode ? const Color(0xFF64748B) : Colors.grey)),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: fileSizeStr.isNotEmpty
                                    ? Text(
                                        fileSizeStr,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: _isDarkMode ? const Color(0xFF64748B) : Colors.grey,
                                        ),
                                      )
                                    : null,
                                trailing: !isDir
                                    ? ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isSupportedFile ? const Color(0xFF0284C7) : const Color(0xFF475569),
                                          foregroundColor: Colors.white,
                                          minimumSize: const Size(54, 28),
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                        ),
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          _importFromFile(File(item.path));
                                        },
                                        child: Text(isSupportedFile ? 'Nạp' : 'Chọn', style: const TextStyle(fontSize: 11)),
                                      )
                                    : const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                                onTap: () {
                                  if (isDir) {
                                    setExplorerState(() {
                                      currentDir = item;
                                    });
                                  } else {
                                    Navigator.pop(ctx);
                                    _importFromFile(File(item.path));
                                  }
                                },
                              );
                            },
                          ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openFileImportDialog() async {
    final List<File> foundFiles = [];
    final List<Directory> scanDirs = [];

    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${appDocDir.path}/PassLock_Backups');
      if (await backupDir.exists()) {
        scanDirs.add(backupDir);
      }
      scanDirs.add(appDocDir);
    } catch (_) {}

    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null && await extDir.exists()) {
        scanDirs.add(extDir);
      }
    } catch (_) {}

    scanDirs.addAll([
      Directory('/storage/emulated/0/Download'),
      Directory('/sdcard/Download'),
      Directory('/storage/emulated/0/Documents'),
    ]);

    for (final dir in scanDirs) {
      if (await dir.exists()) {
        try {
          final list = dir.listSync();
          for (final item in list) {
            if (item is File) {
              final pathLower = item.path.toLowerCase();
              if (pathLower.endsWith('.csv') || pathLower.endsWith('.txt') || pathLower.endsWith('.json')) {
                // Tránh trùng lặp
                if (!foundFiles.any((f) => f.path == item.path)) {
                  foundFiles.add(item);
                }
              }
            }
          }
        } catch (_) {}
      }
    }

    foundFiles.sort((a, b) {
      try {
        return b.lastModifiedSync().compareTo(a.lastModifiedSync());
      } catch (_) {
        return 0;
      }
    });

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _isDarkMode ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          top: 20,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
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
                'Nhập Dữ Liệu Từ File',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Duyệt và chọn file sao lưu (.csv, .txt, .json) có sẵn trên máy để nạp dữ liệu:',
                style: TextStyle(
                  fontSize: 12,
                  color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),

              // ============================================================
              // NÚT 1 (HERO ACTION): DUYỆT FILE HỆ THỐNG GỐC ANDROID (SAF)
              // ============================================================
              InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFileFromDevice();
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _isDarkMode
                        ? const Color(0xFF0284C7).withOpacity(0.18)
                        : const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isDarkMode ? const Color(0xFF0284C7) : const Color(0xFF38BDF8),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.file_open_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Duyệt file trên thiết bị',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: _isDarkMode ? Colors.white : const Color(0xFF0369A1),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0284C7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Khuyên Dùng',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Mở bộ chọn file máy (Tải về, Thẻ nhớ SD, Google Drive) để chọn .csv, .txt, .json',
                              style: TextStyle(
                                fontSize: 11,
                                color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF0C4A6E),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF0284C7)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ============================================================
              // NÚT 2: TRÌNH DUYỆT THƯ MỤC NỘI BỘ (IN-APP FOLDER EXPLORER)
              // ============================================================
              InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  _openFolderExplorer();
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _isDarkMode ? const Color(0xFF334155) : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.folder_shared_outlined,
                          color: _isDarkMode ? const Color(0xFFF59E0B) : const Color(0xFFD97706),
                          size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Duyệt cây thư mục trên máy (File Explorer)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _isDarkMode ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          color: _isDarkMode ? const Color(0xFF64748B) : Colors.grey.shade400,
                          size: 18),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ============================================================
              // DANH SÁCH FILE SAO LƯU QUÉT TỰ ĐỘNG
              // ============================================================
              if (foundFiles.isNotEmpty) ...[
                Row(
                  children: [
                    Text(
                      'File sao lưu tìm thấy trong mục Download (${foundFiles.length}):',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _isDarkMode ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  decoration: BoxDecoration(
                    color: _isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _isDarkMode ? const Color(0xFF334155) : Colors.grey.shade200),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: foundFiles.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: _isDarkMode ? const Color(0xFF334155) : Colors.grey.shade200,
                    ),
                    itemBuilder: (context, idx) {
                      final file = foundFiles[idx];
                      final name = file.path.split('/').last;
                      final isCsv = name.toLowerCase().endsWith('.csv');
                      final isJson = name.toLowerCase().endsWith('.json');
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          isCsv
                              ? Icons.table_chart_outlined
                              : isJson
                                  ? Icons.code_rounded
                                  : Icons.description_outlined,
                          color: isCsv
                              ? Colors.green
                              : isJson
                                  ? Colors.cyan
                                  : Colors.blue,
                          size: 20,
                        ),
                        title: Text(
                          name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          file.path,
                          style: TextStyle(
                            fontSize: 10,
                            color: _isDarkMode ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: const Size(50, 28),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _importFromFile(file);
                          },
                          child: const Text('Nạp', style: TextStyle(fontSize: 11)),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
              ],

              Divider(color: _isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),

              // ============================================================
              // DÁN VĂN BẢN SAO LƯU (CLIPBOARD)
              // ============================================================
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: _isDarkMode ? const Color(0xFF9333EA).withOpacity(0.2) : const Color(0xFFF3E8FF),
                  child: Icon(Icons.paste_rounded, color: _isDarkMode ? const Color(0xFFC084FC) : const Color(0xFF9333EA), size: 20),
                ),
                title: Text(
                  'Dán văn bản sao lưu (Clipboard)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                subtitle: Text(
                  'Dán trực tiếp nội dung file .csv, .txt hoặc .json đã sao chép',
                  style: TextStyle(
                    fontSize: 11,
                    color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showImportDialog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openBackupDialog() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: _isDarkMode ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
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
              'Sao Lưu & Xuất/Nhập Dữ Liệu',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Xuất file cất giữ an toàn hoặc nhập file đã sao lưu để khôi phục tài khoản:',
              style: TextStyle(
                fontSize: 12,
                color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 16),

            // 1. Nhập từ file trên máy
            ListTile(
              leading: CircleAvatar(
                backgroundColor: _isDarkMode ? const Color(0xFF0284C7).withOpacity(0.2) : const Color(0xFFE0F2FE),
                child: Icon(
                  Icons.file_open_rounded,
                  color: _isDarkMode ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                ),
              ),
              title: Text(
                'Duyệt & Nhập file từ thiết bị (.csv, .txt, .json)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              subtitle: Text(
                'Duyệt chọn file sao lưu trong máy hoặc Google Drive để nạp lại tài khoản',
                style: TextStyle(
                  fontSize: 12,
                  color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _openFileImportDialog();
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
            Divider(color: _isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),

            // 5. Dán dữ liệu từ văn bản / bộ nhớ tạm
            ListTile(
              leading: CircleAvatar(
                backgroundColor: _isDarkMode ? const Color(0xFF9333EA).withOpacity(0.2) : const Color(0xFFF3E8FF),
                child: Icon(
                  Icons.content_paste_rounded,
                  color: _isDarkMode ? const Color(0xFFC084FC) : const Color(0xFF9333EA),
                ),
              ),
              title: Text(
                'Dán nội dung khôi phục (Clipboard / Dán tay)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              subtitle: Text(
                'Dán nội dung từ file .csv, .txt hoặc .json đã copy trước đó',
                style: TextStyle(
                  fontSize: 12,
                  color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showImportDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showImportDialog() async {
    final textController = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: _isDarkMode ? const Color(0xFF0F172A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Khôi phục dữ liệu',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chọn file từ máy hoặc dán nội dung file sao lưu để phục hồi:',
                  style: TextStyle(
                    fontSize: 12,
                    color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          foregroundColor: _isDarkMode ? const Color(0xFF38BDF8) : const Color(0xFF0F172A),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        ),
                        icon: const Icon(Icons.file_open_rounded, size: 16),
                        label: const Text('Mở file máy', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openFileImportDialog();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          foregroundColor: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        ),
                        icon: const Icon(Icons.paste_rounded, size: 16),
                        label: const Text('Dán Clipboard', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          final data = await Clipboard.getData(Clipboard.kTextPlain);
                          if (data != null && data.text != null) {
                            setModalState(() {
                              textController.text = data.text!;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: textController,
                  maxLines: 5,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Dán nội dung file sao lưu vào đây...',
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: _isDarkMode ? const Color(0xFF64748B) : Colors.grey,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: _isDarkMode ? const Color(0xFF334155) : Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: _isDarkMode ? const Color(0xFF334155) : Colors.grey.shade200),
                    ),
                    filled: true,
                    fillColor: _isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Hủy',
                style: TextStyle(color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isDarkMode ? const Color(0xFF0284C7) : const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final content = textController.text.trim();
                if (content.isEmpty) return;
                Navigator.pop(ctx);
                final imported = BackupService.parseUniversal(content);
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
                            Text('Đã phục hồi thành công ${imported.length} tài khoản!'),
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
                        content: Text('Không tìm thấy dữ liệu hợp lệ để phục hồi!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              child: const Text('Khôi phục ngay'),
            ),
          ],
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
