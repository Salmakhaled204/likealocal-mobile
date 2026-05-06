import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_screen.dart';
import 'map_screen.dart';
import 'add_place_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('LikeALocal')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProfileScreen()),
                );
              },
              child: Text('Go to Profile'),
            ),

            SizedBox(height: 16),

            ElevatedButton.icon(
              icon: Icon(Icons.map),
              label: Text('Explore Map'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MapScreen()),
                );
              },
            ),

            SizedBox(height: 16),

            ElevatedButton.icon(
              icon: Icon(Icons.add_location_alt),
              label: Text('Add a Place'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AddPlaceScreen()),
                );
              },
            ),

            SizedBox(height: 30),

            ElevatedButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
              },
              child: Text('Logout'),
            ),

          ],
        ),
      ),
    );
  }
}