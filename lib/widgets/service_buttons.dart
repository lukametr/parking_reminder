import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ServiceButtons extends StatelessWidget {
  final bool showButtons;
  final bool showSOSButtons;
  final Function(bool) onShowButtonsChanged;
  final Function(bool) onShowSOSButtonsChanged;

  const ServiceButtons({
    Key? key,
    required this.showButtons,
    required this.showSOSButtons,
    required this.onShowButtonsChanged,
    required this.onShowSOSButtonsChanged,
  }) : super(key: key);

  // Brand colors for non-SOS actions
  static const Color _green = Color(0xFF2E7D32); // Green 800
  static const Color _greenDark = Color(0xFF1B5E20); // Green 900

  final List<Map<String, dynamic>> _serviceButtons = const [
    {'icon': Icons.restaurant, 'title': 'კვება'},
    {'icon': Icons.shopping_cart, 'title': 'მაღაზია'},
    {'icon': Icons.local_shipping, 'title': 'ევაკუატორი'},
    {'icon': Icons.tire_repair, 'title': 'ვულკანიზაცია'},
    {'icon': Icons.local_pharmacy, 'title': 'აფთიაქი'},
    {'icon': Icons.local_gas_station, 'title': 'ბენზინგასამართი'},
  ];

  final List<Map<String, dynamic>> _sosButtons = const [
    {'title': '112', 'icon': Icons.local_police, 'phone': '112'},
    {
      'title': 'დაზღვევა',
      'icon': Icons.health_and_safety,
      'phone': '0322422222',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (!showButtons && !showSOSButtons)
          Positioned(bottom: 20, left: 20, child: _sosFab(context)),
        if (!showButtons && !showSOSButtons)
          Positioned(bottom: 20, right: 20, child: _servicesButton(context)),
        if (showSOSButtons) _sosOverlay(context),
        if (showButtons) _servicesOverlay(context),
      ],
    );
  }

  // Only this button remains red
  Widget _sosFab(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onShowSOSButtonsChanged(true),
          borderRadius: BorderRadius.circular(30),
          child: const Center(
            child: Text(
              'SOS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _servicesButton(BuildContext context) {
    return Container(
      height: 50,
      constraints: const BoxConstraints(minWidth: 150, maxWidth: 240),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_green, _greenDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onShowButtonsChanged(true),
          borderRadius: BorderRadius.circular(25),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.apps, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'სერვისები',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sosOverlay(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.7),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'სასწრაფოდ დაკავშირება',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 20,
              runSpacing: 20,
              children: _sosButtons.map((button) {
                return Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_green, _greenDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        spreadRadius: 1,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        final Uri url = Uri(
                          scheme: 'tel',
                          path: button['phone'],
                        );
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                        }
                      },
                      borderRadius: BorderRadius.circular(15),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            button['icon'] as IconData,
                            size: 40,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            button['title'] as String,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 40),
            TextButton(
              onPressed: () => onShowSOSButtonsChanged(false),
              child: const Text(
                'დახურვა',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _servicesOverlay(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.7),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'აირჩიეთ სერვისი',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                ),
                itemCount: _serviceButtons.length,
                itemBuilder: (context, index) {
                  final service = _serviceButtons[index];
                  return Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_green, _greenDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          spreadRadius: 1,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('დაემატება უახლოეს მომავალში'),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(15),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              service['icon'] as IconData,
                              size: 40,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              service['title'] as String,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => onShowButtonsChanged(false),
              child: const Text(
                'დახურვა',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
