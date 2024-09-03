// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_carousel_slider/carousel_slider.dart';
import 'dart:math';

//Ovo je glavni widget za prikaz glavne stranice aplikacije
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, required this.initialPosition});

  final String title;
  final LatLng initialPosition;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> { 
  GoogleMapController? mapController;
  late LatLng _currentPosition;
  bool _loading = false;
  List<Map<String, dynamic>> _golfCourses = [];

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.initialPosition;
  }

  Future<void> _searchNearbyGolfCourses({bool useVisibleRegion = false}) async {
    setState(() {
      _loading = true;
    });

    const String apiKey = 'AIzaSyAVeuhtdQrbE_Cs95J0sx6syhC0s7hCVWg';
    String url;

    if (useVisibleRegion && mapController != null) {
      LatLngBounds bounds = await mapController!.getVisibleRegion();
      LatLng center = LatLng(
        (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
        (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
      );
      double radius = calculateRadius(bounds);
      url = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json?'
          'location=${center.latitude},${center.longitude}'
          '&radius=$radius'
          '&keyword=golf'
          '&type=golf_course'
          '&key=$apiKey';
    } 
    
    else {
      url = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json?'
          'location=${_currentPosition.latitude},${_currentPosition.longitude}'
          '&radius=50000'
          '&keyword=golf'
          '&type=golf_course'
          '&key=$apiKey';
    }

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) 
    {
      final data = json.decode(response.body);
      final results = data['results'] as List<dynamic>;
      final filteredResults = results.where((course) 
      {
        final name = course['name'].toString().toLowerCase();
        final rating = course['rating'] ?? 0;
        return !name.contains('disc') && rating > 0 && rating < 5;
      }).toList();

      setState(() {
        _golfCourses = filteredResults.map((course) {
          Map<String, dynamic> typedCourse = Map<String, dynamic>.from(course);
          return {
            ...typedCourse,
            'city': (typedCourse['vicinity'] as String?)?.split(',').last.trim() ?? 'Nepoznato',
            'rating': typedCourse['rating']?.toString() ?? 'N/A',
            'holes': 'N/A',
          };
        }).toList();
        _loading = false;
      });

      if (_golfCourses.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nažalost, nisu pronađeni golf tereni u ovom području.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pronađeno ${_golfCourses.length} golf terena.')),
        );
      }
    } 
    
    else {
      setState(() {
        _loading = false;
      });
      throw Exception('Neuspjelo učitavanje golf terena');
    }
  }

  double calculateRadius(LatLngBounds bounds) {
    const earth = 6371.0;
    
    final dLat = _toRadians(bounds.northeast.latitude - bounds.southwest.latitude);
    final dLon = _toRadians(bounds.northeast.longitude - bounds.southwest.longitude);
    
    final lat1 = _toRadians(bounds.southwest.latitude);
    final lat2 = _toRadians(bounds.northeast.latitude);
    
    final a = sin(dLat/2) * sin(dLat/2) +
              sin(dLon/2) * sin(dLon/2) * cos(lat1) * cos(lat2);
    final c = 2 * atan2(sqrt(a), sqrt(1-a));
    final diameter = earth * c;
    
    return diameter * 1000 / 2;
  }

  double _toRadians(double degree) {
    return degree * (pi / 180);
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    controller.animateCamera(CameraUpdate.newLatLng(_currentPosition));
  }

  Widget _buildCarousel(List<String> photoUrls) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: CarouselSlider.builder(
          unlimitedMode: true,
          slideBuilder: (index) {
            return Image.network(
              photoUrls[index],
              fit: BoxFit.cover,
            );
          },
          slideTransform: CubeTransform(),
          slideIndicator: CircularSlideIndicator(
            padding: EdgeInsets.only(bottom: 10),
            indicatorRadius: 4,
          ),
          itemCount: photoUrls.length,
          initialPage: 0,
          enableAutoSlider: true,
        ),
      ),
    );
  }

  Future<void> _showGolfCourseDetails(Map<String, dynamic> course) async {
    setState(() {
      _loading = true;
    });

    //API pretraga informacija o zasebnom terenu
    const String apiKey = 'AIzaSyAVeuhtdQrbE_Cs95J0sx6syhC0s7hCVWg';
    final String placeId = course['place_id'];
    final String url = 'https://maps.googleapis.com/maps/api/place/details/json?'
        'place_id=$placeId'
        '&fields=name,rating,formatted_phone_number,formatted_address,opening_hours,website,photos'
        '&key=$apiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final details = data['result'];
        
        //Spremanje URLova fotografija u zasebnu listu
        List<String> photoUrls = [];
        if (details['photos'] != null) {
          for (var i = 0; i < 5 && i < details['photos'].length; i++) {
            String photoReference = details['photos'][i]['photo_reference'];
            String photoUrl = 'https://maps.googleapis.com/maps/api/place/photo?'
                'maxwidth=400'
                '&photo_reference=$photoReference'
                '&key=$apiKey';
            photoUrls.add(photoUrl);
          }
        }

        setState(() {
          _loading = false;
        });

        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(details['name']),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[

                    //Karusel za fotografije terena
                    if (photoUrls.isNotEmpty)
                      _buildCarousel(photoUrls),

                    SizedBox(height: 16),

                    //Gumbi/Ikone za navigaciju, stranicu i broj telefona
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [

                        //Navigacija
                        IconButton(
                          icon: Icon(Icons.directions),
                          onPressed: () async {
                            final Uri url = Uri.parse(
                              'https://www.google.com/maps/dir/?api=1&destination=${details['formatted_address']}&travelmode=driving'
                            );
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url);
                            } 
                          },
                        ),

                        //Stranica
                        IconButton(
                          icon: Icon(Icons.public),
                          onPressed: details['website'] != null
                            ? () async {
                                final Uri url = Uri.parse(details['website']);
                                if (await canLaunchUrl(url)) {
                                  await launchUrl(url);
                                } 
                              }
                            : null,
                        ),

                        //Broj
                        IconButton(
                          icon: Icon(Icons.phone),
                          onPressed: details['formatted_phone_number'] != null
                            ? () async {
                                final Uri url = Uri(
                                  scheme: 'tel',
                                  path: details['formatted_phone_number'],
                                );
                                if (await canLaunchUrl(url)) {
                                  await launchUrl(url);
                                }
                              }
                            : null,
                        ),
                      ],
                    ),

                    //Dodatne informacije
                    SizedBox(height: 16),

                    Text('Adresa:', style: TextStyle( fontWeight: FontWeight.bold)),
                    Text(details['formatted_address'] ?? 'Nije dostupno'),

                    SizedBox(height: 16),

                    Text('Telefon:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(details['formatted_phone_number'] ?? 'Nije dostupno'),

                    SizedBox(height: 16),

                    Text('Radno vrijeme:', style: TextStyle(fontWeight: FontWeight.bold)),
                    if (details['opening_hours'] != null && details['opening_hours']['weekday_text'] != null)
                      ...details['opening_hours']['weekday_text'].map((day) => Text(day))
                    else
                      Text('Nije dostupno'),

                    SizedBox(height: 16),

                    Text('Ocjena: ${details['rating']?.toString() ?? 'Nije dostupno'}', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),

              //Gumb zatvori
              actions: <Widget>[
                TextButton(
                  child: Text('Zatvori'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],

            );
          },
        );
      } 

    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('O aplikaciji'),
          content: const Text('Golf Scout je aplikacija za pronalaženje golf terena u vašoj blizini.'),
          actions: [
            TextButton(
              child: const Text('Zatvori'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
  return Scaffold(

    
    // AppBar sa naslovom aplikacije i ikonom za objašnjenje
    appBar: AppBar(
      backgroundColor: Color.fromARGB(255, 115, 187, 115),
      title: const Text(
        'GOLF SCOUT',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 24,
        ),
      ),

      //Ikona za više informacija
      actions: [
        IconButton(
          icon: const Icon(Icons.info_outline, color: Colors.white),
          onPressed: _showAboutDialog,
        ),
      ],
    ),

    // Glavni sadržaj aplikacije
    body: Padding(
      padding: const EdgeInsets.all(15.0),
      child: Column(
        children: [

          //Google Maps Karta
          Container(
            height: MediaQuery.of(context).size.height * 0.4,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.5),
                  spreadRadius: 2,
                  blurRadius: 7,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            
            //Prikazuje mapu s markerima za golf terene.
            child: GoogleMap(

              // Postavljanje kontrolera za mapu
              onMapCreated: _onMapCreated,
              
              // Početna pozicija kamere na mapi
              initialCameraPosition: CameraPosition(
                target: _currentPosition,
                zoom: 10.0,
              ),
              
              // Omogućavanje prikaza trenutne lokacije korisnika i gumb za lokaciju
              myLocationEnabled: true,
              myLocationButtonEnabled: true,

              // Postavljanje markera za golf terene na mapi
              markers: _golfCourses
                  .map((course) => Marker(
                        markerId: MarkerId(course['place_id']),
                        position: LatLng(
                          course['geometry']['location']['lat'],
                          course['geometry']['location']['lng'],
                        ),
                                            
                        //Informacijski prozor koji se prikazuje na dodir markera
                        infoWindow: InfoWindow(
                          title: course['name'],
                          snippet: course['vicinity'],
                        ),

                        //Pretvaranje liste markera u set za efikasnost
                      )).toSet(),

            ),
          ),

          SizedBox(height: 16),

          //Gumbovi za pretraživanje
          Row(
            children: [

              // Gumb za pretraživanje terena u blizini
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _searchNearbyGolfCourses(useVisibleRegion: false),
                  icon: Icon(Icons.search_rounded, size: 18),
                  label: Text('Tereni u blizini'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    elevation: 3,
                  ),
                ),
              ),
              
              SizedBox(width: 8),
              
              // Gumb za pretraživanje terena na vidljivoj karti
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _searchNearbyGolfCourses(useVisibleRegion: true),
                  icon: Icon(Icons.search, size: 18),
                  label: Text('Na vidljivoj karti'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    elevation: 3,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          //Lista sa prikazanim golf terenima
          Expanded(
            child: _loading ? Center(child: CircularProgressIndicator())
                
                //Gradi listu golf terena.
                : ListView.builder(
                    // Broj elemenata u listi
                    itemCount: _golfCourses.length,

                    // Builder za pojedinačne elemente liste
                    itemBuilder: (context, index) {
                      final course = _golfCourses[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: 
                        
                        Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          
                          child: SizedBox(
                            height: 70,
                            child: ListTile(
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                              
                              //Broj u pojedinoj kartici ispred naslova terena
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color.fromARGB(255, 115, 187, 115),
                                  borderRadius: BorderRadius.circular(8),
                                ),

                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),

                              // Naziv golf terena
                              title: Text(
                                course['name'],
                                style: TextStyle(fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),

                              // Dodatne informacije o golf terenu
                              subtitle: Text(
                                '${course['city']}, Ocjena: ${course['rating']}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),

                              // Ikona strelice na kraju reda
                              trailing: Icon(Icons.arrow_forward_ios, size: 16),

                              // Akcija pri tapkanju na element liste
                              onTap: () {
                                // Prikaz detalja o odabranom golf terenu
                                _showGolfCourseDetails(course);                 
                                // Animacija kamere na mapi do odabranog terena
                                mapController?.animateCamera(
                                  CameraUpdate.newLatLng(
                                    LatLng(
                                      course['geometry']['location']['lat'],
                                      course['geometry']['location']['lng'],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
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
}