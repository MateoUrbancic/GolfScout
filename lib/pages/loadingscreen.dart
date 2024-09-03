
// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import 'package:golfscout_version2/pages/myhomepage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

//Ovaj stateful widget funkcionira kao početni zaslon aplikacije dok se lokacija korisnika ne nađe
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  _LoadingScreenState createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    //Inicijalizacijom ovog widgeta se poziva funkcija za dohvaćanje lokacije 
    _getUserLocation();
  }

  //Funkcija za dohvaćanje lokacije uređaja
  Future<void> _getUserLocation() async {
    //Dvije varijable koje će se koristiti za provjeru ukljućenosti lokacijske usluge i dopuštenja dijeljenja lokacije
    bool serviceEnabled;
    LocationPermission permission;

     // Ovdje se provjera jesu li lokacijske usluge omogućene na uređaju
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    
    //Ako nisu, šalje se obavijest na dnu ekrana
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lokacijske usluge su onemogućene. Molimo omogućite ih.')),
      );
      return;
    }

    //Ovdje se provjerava ako aplikacija ima pristup lokaciji
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
       // Ako su dozvole odbijene, zatraži ih
      permission = await Geolocator.requestPermission();
      // Ako su dozvole i dalje odbijene, prikaži poruku
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dozvole za lokaciju su odbijene.')),
        );
        return;
      }
    }

    //Ovdje se pokušava dohvatiti lokacija uređaja pomoću Geolocator paketa
    try {
      Position position = await Geolocator.getCurrentPosition();
       
      //Kada se uhvati lokacija onda se otvara widget za glavni zaslon 
      //aplikacije kojem se prosljeđuje lokacija
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => MyHomePage(
            title: 'Golf Scout',
            initialPosition: LatLng(position.latitude, position.longitude),
          ),
        ),
      );
    //Ako se ne uhvati lokacija zbog greške, onda se šalje poruka na dno ekrana
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Došlo je do greške pri dohvaćanju lokacije.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Izgradnja UI-a početne stranice aplikacije
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.golf_course, size: 100, color: Colors.green),
            SizedBox(height: 20),
            Text(
              'Golf Scout',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Učitavanje vaše lokacije...'),
          ],
        ),
      ),
    );
  }
}