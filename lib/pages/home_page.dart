import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          children: <Widget>[
            const Spacer(),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Image.asset(
                  'assets/logo.png', // Make sure you have this image in your assets folder
                  width: 150,
                  height: 150,
                ),
                const SizedBox(height: 20),
                const Text(
                  textAlign: TextAlign.center,
                  'Vigil1 Kids \n App',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                    height: 1.21,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
            const Spacer(), // Pushes the button to the bottom
            Padding(
              padding: const EdgeInsets.only(
                  bottom: 100), // Padding to create space from the bottom edge
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(
                      context, '/terms'); // Adjust the route name as needed
                },
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  backgroundColor: const Color.fromRGBO(21, 190, 181, 1),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(6)),
                  ),
                  minimumSize: const Size(350, 48), // Button width and height
                ),
                child: const Text(
                  'Setup',
                  style: TextStyle(fontSize: 18, color: Colors.black),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
