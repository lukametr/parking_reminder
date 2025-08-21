import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/service_buttons.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with WidgetsBindingObserver {
  bool _showButtons = false;
  bool _showSOSButtons = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ფონი: ლოკალური asset-იდან, უსაფრთხო ფოლბექით
          Positioned.fill(
            child: Image.asset(
              'parking_reminder/assets/background_image.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Container(color: Colors.black),
            ),
          ),
          // გამჭვირვალე შავი ფენა ტექსტისთვის
          Container(
            color: Colors.black.withValues(alpha: 0.3),
            width: double.infinity,
            height: double.infinity,
          ),
          // ტექსტი Column-ში
          Positioned(
            top: 80,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'ზონალური პარკირების',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Text(
                    'კონტროლის სისტემა',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'აპლიკაცია შეგიძლიათ ჩაკეცოთ;\n ავტომატურად ჩაირთვება\n ზონალურ პარკირებაზე.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: const [
                      Text(
                        '!',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'ყოველთვის გადაამოწმეთ\nლოტის ნომერი',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        softWrap: true,
                      ),
                      Text(
                        '!',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // ჩაკეცვის და გამორთვის ღილაკები
          Positioned(
            top: 40,
            right: 20,
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _minimizeApp,
                      borderRadius: BorderRadius.circular(20),
                      child: const Center(
                        child: Icon(
                          Icons.minimize,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _terminateApp,
                      borderRadius: BorderRadius.circular(20),
                      child: const Center(
                        child: Icon(Icons.close, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // სერვისების ღილაკები
          ServiceButtons(
            showButtons: _showButtons,
            showSOSButtons: _showSOSButtons,
            onShowButtonsChanged: (value) {
              setState(() {
                _showButtons = value;
              });
            },
            onShowSOSButtonsChanged: (value) {
              setState(() {
                _showSOSButtons = value;
              });
            },
          ),
        ],
      ),
    );
  }

  void _minimizeApp() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).maybePop();
    } else {
      SystemNavigator.pop();
    }
  }

  void _terminateApp() {
    SystemNavigator.pop();
  }

  // Remote Config ამ ეტაპზე არ ვიყენებთ
}
