import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/privacy.dart';

/// Play Prominent Disclosure for precise + background location.
/// Must appear full-screen BEFORE any runtime location permission request.
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
        backgroundColor: const Color(0xFF0B0B0B),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.location_on, color: Colors.redAccent, size: 44),
                const SizedBox(height: 10),
                const Text(
                  'ლოკაციის მონაცემების გამოყენება',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Location data access & use',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _section(
                          titleKa: 'რას ვიღებთ / ვაგროვებთ',
                          titleEn: 'WHAT we access / collect',
                          bodyKa:
                              'თქვენს ზუსტ მდებარეობას (GPS / precise location), '
                              'მათ შორის ფონში — როცა აპი ჩაკეცილია, ეკრანი გამორთულია '
                              'ან აპი არ არის გახსნილი („ყოველთვის“ / Allow all the time).',
                          bodyEn:
                              'Your precise GPS location, including in the background '
                              'when the app is closed, minimized, or the screen is off '
                              '(“Allow all the time”).',
                        ),
                        _section(
                          titleKa: 'რატომ გვჭირდება',
                          titleEn: 'WHY we use location',
                          bodyKa:
                              'რომ ამოვიცნოთ, გაჩერდით თუ არა თბილისის ფასიანი '
                              'ზონალური პარკინგის ლოტთან (≈5–8 მ), გაჩვენოთ ლოტის ნომერი '
                              'და შეგახსენოთ ოფიციალურ აპში (ge.msda.parking / MSDA) '
                              'პარკირების ჩართვა ან გამორთვა. აპი დროს არ ითვლის — '
                              'საფასური წუთებშია.',
                          bodyEn:
                              'To detect when you stop near a paid Tbilisi zonal parking '
                              'lot (~5–8 m), show the lot number, and remind you to start '
                              'or stop parking in the official MSDA app (ge.msda.parking). '
                              'We do not run a billing countdown.',
                        ),
                        _section(
                          titleKa: 'როგორ ვიყენებთ',
                          titleEn: 'HOW location is used',
                          bodyKa:
                              'კოორდინატი მუშავდება მოწყობილობაზე (on-device), '
                              'foreground სერვისში მუდმივი შეტყობინებით '
                              '„პარკინგის მონიტორინგი ჩართულია“. GPS ტრეკს სერვერზე '
                              'არ ვტვირთავთ. სესია ინახება მხოლოდ ტელეფონზე.\n\n'
                              'ლოკაციას არ ვყიდით. რეკლამის პროფილირებისთვის ან '
                              'პერსონალიზებული რეკლამისთვის ლოკაციას არ ვიყენებთ.',
                          bodyEn:
                              'Location is processed on-device in a foreground service '
                              'with a persistent “parking monitoring on” notification. '
                              'We do not upload GPS tracks. Sessions stay on the phone.\n\n'
                              'We do not sell location data. We do not use location for '
                              'ads profiling or personalized advertising.',
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '„ვეთანხმები / გაგრძელება“ = თანხმობა ზუსტი ლოკაციის '
                          '(GPS) გამოყენებაზე ზემოთ აღწერილი მიზნით; შემდეგ სისტემა '
                          'გკითხავთ ნებართვას (მათ შორის „ყოველთვის“).\n'
                          '„უარყოფა“ = ლოკაციას არ მოვითხოვთ; პარკინგის მონიტორინგი '
                          'არ ჩაირთვება. SOS და სერვისები დარჩება.\n\n'
                          'ეს ეკრანი მხოლოდ ლოკაციაზეა — შეტყობინებები ცალკე '
                          'მოთხოვნაა.',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Agree / Continue = you consent to precise location use as '
                          'described; then the system permission appears (including '
                          '“Allow all the time”). Decline = no location request; '
                          'parking monitoring stays off. SOS and services remain. '
                          'This screen is location-only — notifications are separate.',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => launchUrl(
                    Uri.parse(PrivacyConfig.policyUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: const Text(
                    'პრივატულობის პოლიტიკა / Privacy policy',
                    style: TextStyle(color: Colors.lightBlueAccent),
                  ),
                ),
                const SizedBox(height: 4),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    'ვეთანხმები / გაგრძელება',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text(
                    'უარყოფა',
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _section({
    required String titleKa,
    required String titleEn,
    required String bodyKa,
    required String bodyEn,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF333333)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titleKa,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                titleEn,
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                bodyKa,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                bodyEn,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
