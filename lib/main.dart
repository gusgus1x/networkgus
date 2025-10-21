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
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
          final lightPastel = ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFFF9ECF),
              brightness: Brightness.light,
            ).copyWith(
              primary: const Color(0xFFFF9ECF),
              secondary: const Color(0xFFA8E6CF),
              background: const Color(0xFFF6E8EE),
              surfaceVariant: const Color(0xFFF6E8EE),
            ),
            scaffoldBackgroundColor: const Color(0xFFF6E8EE),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFFF6E8EE),
              foregroundColor: Colors.black,
              elevation: 0,
              centerTitle: false,
              iconTheme: IconThemeData(color: Color(0xFFA8E6CF)),
            ),
            cardColor: const Color(0xFFF6E8EE),
            inputDecorationTheme: const InputDecorationTheme(
              filled: true,
              fillColor: Color(0xFFF8EEF3),
            ),
            textTheme: const TextTheme(
              bodyMedium: TextStyle(color: Colors.black87),
              bodyLarge: TextStyle(color: Colors.black87),
              titleLarge: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            iconTheme: const IconThemeData(color: Color(0xFFA8E6CF)),
            bottomNavigationBarTheme: BottomNavigationBarThemeData(
              backgroundColor: Colors.white,
              selectedItemColor: const Color(0xFFFF9ECF),
              selectedIconTheme: const IconThemeData(color: Color(0xFFFF9ECF)),
              selectedLabelStyle: const TextStyle(color: Color(0xFFFF9ECF), fontWeight: FontWeight.w600),
              unselectedItemColor: Colors.grey.shade600,
              unselectedIconTheme: IconThemeData(color: Colors.grey.shade600),
              unselectedLabelStyle: TextStyle(color: Colors.grey.shade600),
              showUnselectedLabels: true,
              type: BottomNavigationBarType.fixed,
            ),
            dividerColor: Colors.black12,
          );

          final lightWhite = ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFFF9ECF),
              brightness: Brightness.light,
            ).copyWith(
              primary: const Color(0xFFFF9ECF),
              secondary: const Color(0xFFA8E6CF),
            ),
            scaffoldBackgroundColor: Colors.white,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
              centerTitle: false,
              iconTheme: IconThemeData(color: Colors.black87),
            ),
            cardColor: Colors.white,
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            textTheme: const TextTheme(
              bodyMedium: TextStyle(color: Colors.black87),
              bodyLarge: TextStyle(color: Colors.black87),
              titleLarge: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            iconTheme: const IconThemeData(color: Colors.black87),
            bottomNavigationBarTheme: BottomNavigationBarThemeData(
              backgroundColor: Colors.white,
              selectedItemColor: const Color(0xFFFF9ECF),
              selectedIconTheme: const IconThemeData(color: Color(0xFFFF9ECF)),
              selectedLabelStyle: const TextStyle(color: Color(0xFFFF9ECF), fontWeight: FontWeight.w600),
              unselectedItemColor: Colors.grey.shade600,
              unselectedIconTheme: IconThemeData(color: Colors.grey.shade600),
              unselectedLabelStyle: TextStyle(color: Colors.grey.shade600),
              showUnselectedLabels: true,
              type: BottomNavigationBarType.fixed,
            ),
            dividerColor: Colors.black12,
          );

          final effectiveLight = themeProvider.themeMode == ThemeMode.light ? lightWhite : lightPastel;

          return MaterialApp(
            title: 'SocialNetwork',
            themeMode: themeProvider.themeMode,
            theme: effectiveLight,
          // Dark theme keeps palette but on dark surfaces
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFFF9ECF),
              brightness: Brightness.dark,
            ).copyWith(
              primary: const Color(0xFFFF9ECF),
              secondary: const Color(0xFFA8E6CF),
            ),
            scaffoldBackgroundColor: const Color(0xFF121212),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1A1A1A),
              foregroundColor: Colors.white,
              elevation: 0,
              centerTitle: false,
              iconTheme: IconThemeData(color: Color(0xFFA8E6CF)),
            ),
            cardColor: const Color(0xFF1A1A1A),
            textTheme: const TextTheme(
              bodyMedium: TextStyle(color: Colors.white70),
              bodyLarge: TextStyle(color: Colors.white70),
              titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            iconTheme: const IconThemeData(color: Color(0xFFA8E6CF)),
            bottomNavigationBarTheme: const BottomNavigationBarThemeData(
              backgroundColor: Color(0xFF1A1A1A),
              selectedItemColor: Color(0xFFFF9ECF),
              selectedIconTheme: IconThemeData(color: Color(0xFFFF9ECF)),
              selectedLabelStyle: TextStyle(color: Color(0xFFFF9ECF), fontWeight: FontWeight.w600),
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
