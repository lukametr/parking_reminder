import 'package:flutter/material.dart';

import '../utils/phone_launcher.dart';

class ServiceButtons extends StatelessWidget {
  final bool showButtons;
  final bool showSOSButtons;
  final Function(bool) onShowButtonsChanged;
  final Function(bool) onShowSOSButtonsChanged;

  const ServiceButtons({
    super.key,
    required this.showButtons,
    required this.showSOSButtons,
    required this.onShowButtonsChanged,
    required this.onShowSOSButtonsChanged,
  });

  static const Color _green = Color(0xFF2E7D32);
  static const Color _greenDark = Color(0xFF1B5E20);

  static const List<Map<String, dynamic>> _serviceButtons = [
    {'icon': Icons.restaurant, 'title': 'კვება'},
    {'icon': Icons.shopping_cart, 'title': 'მაღაზია'},
    {'icon': Icons.local_shipping, 'title': 'ევაკუატორი'},
    {'icon': Icons.tire_repair, 'title': 'ვულკანიზაცია'},
    {'icon': Icons.local_pharmacy, 'title': 'აფთიაქი'},
    {'icon': Icons.local_gas_station, 'title': 'ბენზინგასამართი'},
  ];

  static const List<Map<String, dynamic>> _sosButtons = [
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
      fit: StackFit.expand,
      children: [
        if (!showButtons && !showSOSButtons)
          Positioned(
            left: 16,
            right: 16,
            bottom: 8,
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _sosFab(context),
                  _servicesButton(context),
                ],
              ),
            ),
          ),
        if (showSOSButtons) _sosOverlay(context),
        if (showButtons) _servicesOverlay(context),
      ],
    );
  }

  Widget _sosFab(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onShowSOSButtonsChanged(true),
        borderRadius: BorderRadius.circular(30),
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                spreadRadius: 1,
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onShowButtonsChanged(true),
        borderRadius: BorderRadius.circular(25),
        child: Container(
          height: 50,
          constraints: const BoxConstraints(minWidth: 140, maxWidth: 220),
          padding: const EdgeInsets.symmetric(horizontal: 14),
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
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.apps, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'სერვისები',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sosOverlay(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.72),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'სასწრაფოდ დაკავშირება',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 24,
              runSpacing: 24,
              children: _sosButtons.map((Map<String, dynamic> button) {
                return Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_green, _greenDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
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
                        await dialNumber(button['phone'] as String);
                      },
                      borderRadius: BorderRadius.circular(16),
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
            const SizedBox(height: 32),
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
      child: Material(
        color: Colors.black.withValues(alpha: 0.72),
        child: Column(
          children: [
            const SizedBox(height: 12),
            const Text(
              'აირჩიეთ სერვისი',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _serviceButtons.length,
                itemBuilder: (BuildContext context, int index) {
                  final Map<String, dynamic> service = _serviceButtons[index];
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
                              size: 36,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              service['title'] as String,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            TextButton(
              onPressed: () => onShowButtonsChanged(false),
              child: const Text(
                'დახურვა',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
