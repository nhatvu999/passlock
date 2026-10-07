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
    buffer.writeln('"Dịch vụ","Danh mục","Tài khoản/Email","Mật khẩu","Ghi chú"');
    for (final it in items) {
      final s = it.service.replaceAll('"', '""');
      final c = it.category.replaceAll('"', '""');
      final u = it.username.replaceAll('"', '""');
      final p = it.password.replaceAll('"', '""');
      final n = (it.notes ?? '').replaceAll('"', '""');
      buffer.writeln('"$s","$c","$u","$p","$n"');
    }
    return buffer.toString();
  }

  static String exportToTXT(List<CredentialItem> items) {
    final buffer = StringBuffer();
    buffer.writeln('==================================================');
    buffer.writeln('       BẢN SAO LƯU MẬT KHẨU PASSLOCK VAULT        ');
    buffer.writeln('       Ngày xuất: ${DateTime.now().toLocal()}     ');
    buffer.writeln('       Tổng số tài khoản: ${items.length}        ');
    buffer.writeln('==================================================\n');

    for (int i = 0; i < items.length; i++) {
      final it = items[i];
      buffer.writeln('[${i + 1}] ${it.service.toUpperCase()} (${it.category})');
      buffer.writeln('Tài khoản / Email : ${it.username}');
      buffer.writeln('Mật khẩu          : ${it.password}');
      if (it.notes != null && it.notes!.isNotEmpty) {
        buffer.writeln('Ghi chú           : ${it.notes}');
      }
      buffer.writeln('--------------------------------------------------');
    }
    return buffer.toString();
  }

  static Future<void> exportAndShare({
    required BuildContext context,
    required List<CredentialItem> items,
    required String format,
  }) async {
    final content = format == 'csv' ? exportToCSV(items) : exportToTXT(items);
    final dir = await getTemporaryDirectory();
    final fileName = 'passlock_backup_${DateTime.now().millisecondsSinceEpoch}.$format';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(content, encoding: utf8);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Bản sao lưu mật khẩu PassLock (${items.length} tài khoản)',
      subject: 'Sao lưu PassLock Vault',
    );
  }

  static Future<List<CredentialItem>?> pickAndImportFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt', 'json'],
    );
    if (result == null || result.files.single.path == null) return null;

    final file = File(result.files.single.path!);
    final content = await file.readAsString(encoding: utf8);
    return parseUniversal(content);
  }

  static List<CredentialItem> parseUniversal(String content) {
    final trimmed = content.trim();
    final List<CredentialItem> imported = [];

    // 1. Parse JSON
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        final parsed = json.decode(trimmed);
        final list = parsed is List ? parsed : (parsed['items'] as List? ?? []);
        for (final item in list) {
          if (item is Map<String, dynamic> &&
              item['service'] != null &&
              item['username'] != null &&
              item['password'] != null) {
            imported.add(CredentialItem.fromMap(item));
          }
        }
        if (imported.isNotEmpty) return imported;
      } catch (_) {}
    }

    // 2. Parse CSV
    final lines = trimmed.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
    if (lines.length > 1 && lines[0].contains(',')) {
      final startIndex = lines[0].toLowerCase().contains('dịch vụ') || lines[0].toLowerCase().contains('service') ? 1 : 0;
      for (int i = startIndex; i < lines.length; i++) {
        final line = lines[i];
        final values = <String>[];
        var inQuotes = false;
        var current = '';
        for (int c = 0; c < line.length; c++) {
          final char = line[c];
          if (char == '"') {
            inQuotes = !inQuotes;
          } else if (char == ',' && !inQuotes) {
            values.add(_cleanCsvCell(current));
            current = '';
          } else {
            current += char;
          }
        }
        values.add(_cleanCsvCell(current));

        if (values.length >= 4) {
          imported.add(CredentialItem(
            id: 'imp_${DateTime.now().millisecondsSinceEpoch}_$i',
            service: values[0],
            category: values.length > 1 ? values[1] : 'Khác',
            username: values.length > 2 ? values[2] : '',
            password: values.length > 3 ? values[3] : '',
            notes: values.length > 4 ? values[4] : null,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ));
        }
      }
    }
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
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              _message,
              style: TextStyle(
                color: _isError ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 36),

            // 6 chấm tròn biểu thị 6 chữ số PIN
            AnimatedBuilder(
              animation: _shakeController,
              builder: (context, child) {
                final offset = sin(_shakeController.value * pi * 4) * 8;
                return Transform.translate(
                  offset: Offset(offset, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (index) {
                      final isFilled = index < _enteredCode.length;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 9),
                        width: 14,
                        height: 14,
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
// 5. MÀN HÌNH CHÍNH SIÊU GỌN & MỞ PASS TRỰC TIẾP (HOME SCREEN)
// ============================================================================
class HomeScreen extends StatefulWidget {
  final SecureStorageService storageService;
  final VoidCallback onLock;

  const HomeScreen({
    super.key,
    required this.storageService,
    required this.onLock,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<CredentialItem> _credentials = [];
  List<CredentialItem> _filteredCredentials = [];
  bool _isLoading = true;
  String _searchQuery = '';
  
  final Set<String> _maskedPasswordIds = {};
  String? _expandedItemId;

  @override
  void initState() {
    super.initState();
    _loadData();
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

  void _togglePasswordVisibility(String id) {
    setState(() {
      if (_maskedPasswordIds.contains(id)) {
        _maskedPasswordIds.remove(id);
      } else {
        _maskedPasswordIds.add(id);
      }
    });
  }

  Future<void> _openAddEditModal([CredentialItem? existing]) async {
    final result = await showModalBottomSheet<CredentialItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CredentialDialog(item: existing),
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
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa "${item.service}" không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
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

  Future<void> _openBackupDialog() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
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
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sao Lưu & Xuất / Nhập Dữ Liệu',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Xuất file để cất giữ an toàn hoặc nhập lại khi cài lại app trên điện thoại mới:',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFDCFCE7),
                child: Icon(Icons.table_chart_outlined, color: Color(0xFF16A34A)),
              ),
              title: const Text('Xuất file Excel / CSV (.csv)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Mở xem và chỉnh sửa được bằng Excel, Google Sheets', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                BackupService.exportAndShare(context: context, items: _credentials, format: 'csv');
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFDBEAFE),
                child: Icon(Icons.description_outlined, color: Color(0xFF2563EB)),
              ),
              title: const Text('Xuất file Văn bản (.txt)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Xem trên Notepad, Word, lưu trữ cá nhân hoặc gửi tin nhắn', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                BackupService.exportAndShare(context: context, items: _credentials, format: 'txt');
              },
            ),
            const Divider(),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFF3E8FF),
                child: Icon(Icons.file_download_outlined, color: Color(0xFF9333EA)),
              ),
              title: const Text('Nhập file khôi phục (Import)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Chọn file .csv, .txt hoặc .json đã lưu để phục hồi lại tài khoản', style: TextStyle(fontSize: 12)),
              onTap: () async {
                Navigator.pop(ctx);
                final imported = await BackupService.pickAndImportFile();
                if (imported != null && imported.isNotEmpty) {
                  for (final item in imported) {
                    await widget.storageService.addCredential(item);
                  }
                  _loadData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Đã phục hồi thành công ${imported.length} tài khoản!')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.shield_outlined, color: Color(0xFF0F172A), size: 22),
            const SizedBox(width: 8),
            const Text('PassLock Vault'),
            const Spacer(),
            Text(
              '${_filteredCredentials.length} mục',
              style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sao lưu & Xuất/Nhập file',
            icon: const Icon(Icons.folder_shared_outlined, color: Color(0xFF0284C7)),
            onPressed: _openBackupDialog,
          ),
          IconButton(
            tooltip: 'Khóa ngay',
            icon: const Icon(Icons.lock_outline_rounded),
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
              decoration: InputDecoration(
                hintText: 'Tìm kiếm dịch vụ, email...',
                prefixIcon: const Icon(Icons.search, size: 18),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCredentials.isEmpty
                    ? const Center(child: Text('Chưa có tài khoản nào'))
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
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Thêm mới', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildAccountCard(CredentialItem item) {
    final isExpanded = _expandedItemId == item.id;
    final isMasked = _maskedPasswordIds.contains(item.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpanded ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
          width: isExpanded ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
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
                    backgroundColor: const Color(0xFF0F172A).withOpacity(0.07),
                    child: Text(
                      item.service.isNotEmpty ? item.service[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
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
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.category,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.username,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
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
                    icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF94A3B8)),
                    onPressed: () => _copyToClipboard(item.username, 'Tài khoản'),
                    visualDensity: VisualDensity.compact,
                  ),

                  // Mũi tên chỉ thị
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: isExpanded ? const Color(0xFF0284C7) : const Color(0xFF94A3B8),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // KHU VỰC HIỂN THỊ MẬT KHẨU TRỰC TIẾP KHI BẤM VÀO TÀI KHOẢN
          if (isExpanded)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(11)),
              ),
              child: Column(
                children: [
                  const Divider(height: 12, color: Color(0xFFE2E8F0)),

                  // Khung Mật khẩu dạng rõ trực tiếp
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.key_outlined, size: 16, color: Color(0xFF0284C7)),
                        const SizedBox(width: 8),
                        const Text(
                          'Pass: ',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                        ),
                        Expanded(
                          child: Text(
                            isMasked ? '••••••••••••' : item.password,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: isMasked ? 2 : 0,
                              color: const Color(0xFF0F172A),
                              fontFamily: 'monospace',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Nút Copy Pass nổi bật 1 chạm
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            visualDensity: VisualDensity.compact,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.copy_rounded, size: 13, color: Color(0xFF38BDF8)),
                          label: const Text('Copy Pass', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: () => _copyToClipboard(item.password, 'Mật khẩu'),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: isMasked ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                          icon: Icon(
                            isMasked ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 17,
                            color: const Color(0xFF94A3B8),
                          ),
                          onPressed: () => _togglePasswordVisibility(item.id),
                          visualDensity: VisualDensity.compact,
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
                        style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
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
                          foregroundColor: const Color(0xFF0F172A),
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

  const CredentialDialog({super.key, this.item});

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
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _serviceController,
                decoration: const InputDecoration(
                  labelText: 'Dịch vụ / Tên website *',
                  hintText: 'Ví dụ: Google, Facebook, Techcombank',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Nhập tên dịch vụ' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Danh mục',
                  border: OutlineInputBorder(),
                ),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Tài khoản / Email / SĐT *',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Nhập tài khoản' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu *',
                  border: const OutlineInputBorder(),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Tạo mật khẩu mạnh',
                        icon: const Icon(Icons.auto_fix_high, color: Colors.blue),
                        onPressed: _generateStrongPassword,
                      ),
                      IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
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
                decoration: const InputDecoration(
                  labelText: 'Ghi chú (Tùy chọn)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
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
      theme: ThemeData(
        useMaterial3: true,
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
      home: _isUnlocked
          ? HomeScreen(
              storageService: widget.storageService,
              onLock: _onManualLock,
            )
          : PasscodeScreen(
              storageService: widget.storageService,
              onUnlock: _onUnlockSuccess,
            ),
    );
  }
}
