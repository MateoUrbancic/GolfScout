import 'package:flutter/material.dart';
import 'package:golfscout_version2/pages/loadingscreen.dart';

void main() {
  runApp(const MyApp());
}

//Stateless widget koji postavlja temu aplikacije, naslov i početnu stranicu
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Golf Scout',
      debugShowCheckedModeBanner: false,

      //Tema aplikacije
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromRGBO(115, 187, 115, 0),
        ),
      ),


      //Postavlja početni zaslon aplikacije
      home: const LoadingScreen(),
    );
  }
}
