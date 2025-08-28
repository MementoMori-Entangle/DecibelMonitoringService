import 'package:flutter/material.dart';
import 'oss_licenses.dart';

class OssLicensesPage extends StatelessWidget {
  const OssLicensesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flutter(Dart) OSS Licenses')),
      body: ListView.builder(
        itemCount: allDependencies.length,
        itemBuilder: (context, index) {
          final pkg = allDependencies[index];
          return ExpansionTile(
            title: Text(pkg.name),
            subtitle: Text(pkg.version),
            children: [
              if (pkg.homepage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Text('Homepage: ${pkg.homepage}'),
                ),
              if (pkg.license != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: SelectableText(pkg.license!),
                ),
            ],
          );
        },
      ),
    );
  }
}
