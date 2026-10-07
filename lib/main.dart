import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/secure_storage_service.dart';
import 'screens/passcode_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Thiết lập hướng màn hình dọc chuẩn điện thoại
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Khởi tạo dịch vụ lưu trữ an toàn & kiểm tra passcode mặc định
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

/// Sử dụng WidgetsBindingObserver để lắng nghe vòng đời ứng dụng (App Lifecycle)
/// Tự động khóa lại màn hình khi người dùng chuyển ra ngoài nền (paused / inactive)
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
    // Khi ứng dụng bị ẩn, đưa vào nền hoặc khóa màn hình điện thoại
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_isUnlocked) {
        setState(() {
          _isUnlocked = false; // TỰ ĐỘNG KHÓA LẠI
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
