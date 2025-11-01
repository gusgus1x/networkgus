import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/posts_provider.dart';
import 'providers/user_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/group_provider.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Log the active Firebase project for quick verification in console
  // Example output: Using Firebase project: deksombun-9eba1
  // This helps confirm the app points to the intended project after reconfiguration.
  // ignore: avoid_print
  print('Using Firebase project: ' + DefaultFirebaseOptions.currentPlatform.projectId);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PostsProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => GroupProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          // Light theme option 1: white surfaces with orange accents (for ThemeMode.light)
          final whiteLight = ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFFF8A00),
              brightness: Brightness.light,
            ).copyWith(
              primary: const Color(0xFFFF8A00),
              secondary: const Color(0xFFFFA726),
            ),
            // Use pure white for light surfaces
            scaffoldBackgroundColor: Colors.white,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
              centerTitle: false,
              iconTheme: IconThemeData(color: Colors.black87),
            ),
            // Cards and sheets also white in light mode
            cardColor: Colors.white,
            inputDecorationTheme: const InputDecorationTheme(
              filled: true,
              fillColor: Colors.white, // inputs white in Light
            ),
            textTheme: const TextTheme(
              bodyMedium: TextStyle(color: Colors.black87),
              bodyLarge: TextStyle(color: Colors.black87),
              titleLarge: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            iconTheme: const IconThemeData(color: Colors.black87),
            bottomNavigationBarTheme: BottomNavigationBarThemeData(
              // Match white surfaces
              backgroundColor: Colors.white,
              selectedItemColor: const Color(0xFFFF8A00),
              selectedIconTheme: const IconThemeData(color: Color(0xFFFF8A00)),
              selectedLabelStyle: const TextStyle(color: Color(0xFFFF8A00), fontWeight: FontWeight.w600),
              unselectedItemColor: Colors.black54,
              unselectedIconTheme: const IconThemeData(color: Colors.black54),
              unselectedLabelStyle: const TextStyle(color: Colors.black54),
              showUnselectedLabels: true,
              type: BottomNavigationBarType.fixed,
              elevation: 0,
            ),
            // Light divider for white surfaces
            dividerColor: Colors.black12,
          );

          // Light theme option 2: soft orange-tinted light surfaces (for ThemeMode.system)
          final orangeLight = ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFFF8A00),
              brightness: Brightness.light,
            ).copyWith(
              primary: const Color(0xFFFF8A00),
              secondary: const Color(0xFFFFA726),
            ),
            scaffoldBackgroundColor: const Color(0xFFFFF3E0), // Orange 50
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFFFFF3E0),
              foregroundColor: Colors.black,
              elevation: 0,
              centerTitle: false,
              iconTheme: IconThemeData(color: Colors.black87),
            ),
            cardColor: const Color(0xFFFFF8E1),
            // Inputs use soft-cream to match orangeLight surfaces
            inputDecorationTheme: const InputDecorationTheme(
              filled: true,
              fillColor: Color(0xFFFFF8E1),
            ),
            textTheme: const TextTheme(
              bodyMedium: TextStyle(color: Colors.black87),
              bodyLarge: TextStyle(color: Colors.black87),
              titleLarge: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            iconTheme: const IconThemeData(color: Colors.black87),
            bottomNavigationBarTheme: const BottomNavigationBarThemeData(
              backgroundColor: Color(0xFFFFF8E1),
              selectedItemColor: Color(0xFFFF8A00),
              selectedIconTheme: IconThemeData(color: Color(0xFFFF8A00)),
              selectedLabelStyle: TextStyle(color: Color(0xFFFF8A00), fontWeight: FontWeight.w600),
              unselectedItemColor: Colors.black54,
              unselectedIconTheme: IconThemeData(color: Colors.black54),
              unselectedLabelStyle: TextStyle(color: Colors.black54),
              showUnselectedLabels: true,
              type: BottomNavigationBarType.fixed,
              elevation: 0,
            ),
            dividerColor: Colors.black26,
          );

          // If user forces Light -> use whiteLight, otherwise (System) use orangeLight
          final effectiveLight =
              themeProvider.themeMode == ThemeMode.light ? whiteLight : orangeLight;

          return MaterialApp(
            title: 'DekSomBun',
            themeMode: themeProvider.themeMode,
            theme: effectiveLight,
          // Dark theme keeps palette but on dark surfaces
          // Dark theme (near-black surfaces with orange accent)
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFFF8A00),
              brightness: Brightness.dark,
            ).copyWith(
              primary: const Color(0xFFFF8A00),
              secondary: const Color(0xFFFFA726),
            ),
            scaffoldBackgroundColor: const Color(0xFF121212),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1A1A1A),
              foregroundColor: Colors.white,
              elevation: 0,
              centerTitle: false,
              iconTheme: IconThemeData(color: Colors.white70),
            ),
            cardColor: const Color(0xFF1A1A1A),
            // Inputs use dark surfaces in Dark
            inputDecorationTheme: const InputDecorationTheme(
              filled: true,
              fillColor: Color(0xFF1A1A1A),
            ),
            textTheme: const TextTheme(
              bodyMedium: TextStyle(color: Colors.white70),
              bodyLarge: TextStyle(color: Colors.white70),
              titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            iconTheme: const IconThemeData(color: Colors.white70),
            bottomNavigationBarTheme: const BottomNavigationBarThemeData(
              backgroundColor: Color(0xFF1A1A1A),
              selectedItemColor: Color(0xFFFF8A00),
              selectedIconTheme: IconThemeData(color: Color(0xFFFF8A00)),
              selectedLabelStyle: TextStyle(color: Color(0xFFFF8A00), fontWeight: FontWeight.w600),
              unselectedItemColor: Colors.white54,
              unselectedIconTheme: IconThemeData(color: Colors.white54),
              unselectedLabelStyle: TextStyle(color: Colors.white54),
              showUnselectedLabels: true,
              type: BottomNavigationBarType.fixed,
            ),
            dividerColor: Colors.white10,
          ),
            debugShowCheckedModeBanner: false,
            home: const AppWrapper(),
            routes: {
              '/login': (context) => const LoginScreen(),
              '/register': (context) => const RegisterScreen(),
              '/forgot': (context) => const ForgotPasswordScreen(),
              '/home': (context) => const HomeScreen(),
            },
          );
        },
      ),
    );
  }
}

class AppWrapper extends StatefulWidget {
  const AppWrapper({super.key});

  @override
  State<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> {
  bool _didInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;
      context.read<AuthProvider>().initializeAuth();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading...'),
                ],
              ),
            ),
          );
        }

        if (authProvider.isLoggedIn) {
          return const HomeScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
