import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';

class LicenseListPage extends StatelessWidget {
  final String title;
  final String assetPath;
  const LicenseListPage({
    super.key,
    required this.title,
    required this.assetPath,
  });

  Future<List<Map<String, String>>> _loadLicenses() async {
    try {
      final content = await rootBundle.loadString(assetPath);
      final lines = content.split('\n');
      if (lines.length <= 1) return [];
      return lines
          .skip(1)
          .where((line) => line.trim().isNotEmpty)
          .map((line) {
            final parts = line.split(',');
            if (parts.length < 3) {
              return <String, String>{};
            }
            return {
              'library': parts[0],
              'version': parts[1],
              'license': parts[2],
              'file': parts.length > 3 ? parts[3] : '',
            };
          })
          .where((m) => m.isNotEmpty)
          .toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<List<Map<String, String>>>(
        future: _loadLicenses(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final licenses = snapshot.data ?? [];
          if (licenses.isEmpty) {
            return const Center(child: Text('No license data found.'));
          }
          return ListView.builder(
            itemCount: licenses.length,
            itemBuilder: (context, idx) {
              final lic = licenses[idx];
              return ListTile(
                title: Text(lic['library'] ?? ''),
                subtitle: Text('v${lic['version']} - ${lic['license']}'),
                onTap: () async {
                  final licenseName = (lic['license'] ?? '').trim();
                  final fileName = (lic['file'] ?? '').trim();
                  String licenseText = '';
                  String filePath = '';
                  if (fileName.isNotEmpty) {
                    filePath = 'assets/licenses/$fileName.txt';
                  } else {
                    filePath = 'assets/licenses/$licenseName.txt';
                  }
                  try {
                    licenseText = await rootBundle.loadString(filePath);
                  } catch (e) {
                    licenseText = 'License text not found.';
                  }
                  if (!context.mounted) return;
                  showDialog(
                    context: context,
                    builder:
                        (ctx) => AlertDialog(
                          title: Text(lic['library'] ?? ''),
                          content: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Version: ${lic['version'] ?? ''}'),
                                const SizedBox(height: 8),
                                Text('License: $licenseName'),
                                const Divider(),
                                Text(licenseText),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
