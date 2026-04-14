import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:poshahar_register/providers/poshahar_provider.dart';
import 'package:poshahar_register/screens/poshahar_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PoshaharApp());
}

class PoshaharApp extends StatelessWidget {
  const PoshaharApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => PoshaharProvider(),
      child: MaterialApp(
        title: 'पोषाहार रजिस्टर',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          fontFamily: 'NotoSansDevanagari',
          visualDensity: VisualDensity.adaptivePlatformDensity,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.blue[700],
            foregroundColor: Colors.white,
            elevation: 2,
            centerTitle: true,
          ),
          cardTheme: const CardThemeData(
            elevation: 3,
            margin: EdgeInsets.symmetric(vertical: 4, horizontal: 0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            labelStyle: TextStyle(fontSize: 14),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ),
        home: const PoshaharScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}