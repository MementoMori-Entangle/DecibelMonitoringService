import 'package:flutter/material.dart';

import 'license_list_page.dart';
import 'oss_licenses_page.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('Android OSS Licenses'),
            subtitle: const Text('View open source licenses used in Android'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder:
                      (context) => const LicenseListPage(
                        title: 'Android OSS Licenses',
                        assetPath: 'assets/android_licenses.txt',
                      ),
                ),
              );
            },
          ),
          ListTile(
            title: const Text('Flutter(Dart) OSS Licenses'),
            subtitle: const Text(
              'View open source licenses used in Flutter(Dart)',
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const OssLicensesPage(),
                ),
              );
            },
          ),
          ListTile(
            title: const Text('Licenses'),
            subtitle: const Text('View open source licenses used in DMS'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder:
                      (context) => const LicenseListPage(
                        title: 'DMS OSS Licenses',
                        assetPath: 'assets/dms_licenses.txt',
                      ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
