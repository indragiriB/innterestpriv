import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:introduction_screen/introduction_screen.dart';

class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  Future<void> _completeIntro(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('intro_seen', true);
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return IntroductionScreen(
      globalBackgroundColor: Colors.black, // Dark background
      pages: [
        PageViewModel(
          titleWidget: _buildTitle("Welcome to innterest"),
          bodyWidget: _buildBody(
            "Discover amazing posts and connect with others.",
            'assets/images/ya1.png',
          ),
        ),
        PageViewModel(
          titleWidget: _buildTitle("Share Your Great Ideas"),
          bodyWidget: _buildBody(
            "Upload your content and share your creativity.",
            'assets/images/ya2.png',
          ),
        ),
        PageViewModel(
          titleWidget: _buildTitle("Engage with Others"),
          bodyWidget: _buildBody(
            "Like, comment, and save your favorite posts.",
            'assets/images/ya.png',
          ),
        ),
        PageViewModel(
          titleWidget: _buildTitle("Ready to Start?"),
          bodyWidget: Column(
            children: [
              _buildBody(
                "Join the community and explore now!",
                'assets/images/ya4.png',
              ),
              const SizedBox(height: 50),
              _buildFullWidthButton(context),
            ],
          ),
        ),
      ],
      showNextButton: true,
      next: const Icon(Icons.arrow_forward, color: Colors.white),
      done: const Text(
        "",
        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
      ),
      onDone: () => _completeIntro(context),
      dotsDecorator: const DotsDecorator(
        activeColor: Color.fromARGB(255, 255, 255, 255),
        size: Size(10.0, 10.0),
        activeSize: Size(22.0, 10.0),
        activeShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(25.0)),
        ),
      ),
      skip: TextButton(
        onPressed: () => _completeIntro(context),
        child: const Text(
          "Skip",
          style: TextStyle(color: Color.fromARGB(179, 255, 255, 255)),
        ),
      ),
      showSkipButton: true,
      showDoneButton: false, // Hides the Done button
    );
  }

  Widget _buildTitle(String text) {
    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 60.0, left: 20.0),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 50.0,
            fontWeight: FontWeight.bold,
            fontFamily: 'Lobster', // Font family set to Lobster
            color: Colors.white,
          ),
          textAlign: TextAlign.left,
        ),
      ),
    );
  }

  Widget _buildBody(String bodyText, String imagePath) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 50),
        Center(
          child: Image.asset(
            imagePath,
            height: 400.0,
          ),
        ),
        const SizedBox(height: 50),
        Text(
          bodyText,
          style: const TextStyle(
            fontSize: 16.0,
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFullWidthButton(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ElevatedButton(
        onPressed: () => _completeIntro(context),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          backgroundColor: const Color.fromARGB(255, 255, 255, 255),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
        child: const Text(
          "Get Started",
          style: TextStyle(
            fontSize: 18.0,
            fontWeight: FontWeight.bold,
            color: Color.fromARGB(255, 0, 0, 0),
          ),
        ),
      ),
    );
  }
}
