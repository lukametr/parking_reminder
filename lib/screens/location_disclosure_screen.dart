import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/privacy.dart';

/// Play prominent disclosure for precise + background location.
/// Must appear before any runtime location permission request.
class LocationDisclosureScreen extends StatelessWidget {
  const LocationDisclosureScreen({super.key});

  static Future<bool> present(BuildContext context) async {
    final bool? accepted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) => const LocationDisclosureScreen(),
      ),
    );
    return accepted == true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF111111),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.location_on, color: Colors.redAccent, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'ლოკაციის გამოყენება',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: const Text(
                      'Parking Reminder + (პარკინგის შეხსენება) იყენებს თქვენს '
                      'ზუსტ მდებარეობას (GPS), მათ შორის მაშინ, როცა აპი '
                      'ჩაკეცილია ან ეკრანი გამორთულია („ყოველთვის / Allow all the time“).\n\n'
                      'რატომ: რომ გავიგოთ, გაჩერდით თუ არა თბილისის ფასიან '
                      'ზონალურ პარკინგის ლოტზე, გაჩვენოთ ლოტის ნომერი და '
                      'შეგახსენოთ ოფიციალურ აპში (ge.msda.parking) პარკირების '
                      'ჩართვა ან გამორთვა. აპი დროს არ ითვლის — საფასური წუთებშია.\n\n'
                      'როგორ: კოორდინატი მუშავდება ტელეფონზე, foreground '
                      'სერვისში (მუდმივი შეტყობინება „მონიტორინგი ჩართულია“). '
                      'GPS ტრეკს სერვერზე არ ვტვირთავთ. სესია ინახება ლოკალურად. '
                      'მონაცემებს არ ვყიდით და რეკლამის პროფილისთვის ლოკაციას არ ვიყენებთ.\n\n'
                      '„გაგრძელება“-ზე სისტემა გკითხავთ ლოკაციის ნებართვას. '
                      '„უარყოფა“ — პარკინგის მონიტორინგი არ ჩაირთვება; SOS და '
                      'სერვისები დარჩება.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => launchUrl(
                    Uri.parse(PrivacyConfig.policyUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: const Text('პრივატულობის პოლიტიკა'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('გაგრძელება'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text(
                    'უარყოფა',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
