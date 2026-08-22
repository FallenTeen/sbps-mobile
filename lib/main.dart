import 'package:flutter/material.dart';

import 'core/app_config.dart';
import 'features/version/version_service.dart';

void main() {
  runApp(const SbpsApp());
}

class SbpsApp extends StatelessWidget {
  const SbpsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appFlavor,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const HomePage(),
      debugShowCheckedModeBanner: !AppConfig.isProduction,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final VersionService _versionService = VersionService();
  AppVersionInfo? _version;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final version = await _versionService.fetchAppVersion();
      if (!mounted) return;
      setState(() => _version = version);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SBPS Mobile')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Flavor: ${AppConfig.appFlavor}',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Env: ${AppConfig.appEnv}\nAPI: ${AppConfig.apiBaseUrl}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),
              if (_version != null) ...[
                Text('Min version: ${_version!.minVersion}'),
                Text('Latest version: ${_version!.latestVersion}'),
                Text('Force update: ${_version!.forceUpdate}'),
                if (_version!.changelog != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_version!.changelog!),
                  ),
              ] else
                Text(
                  _error ?? 'Mengambil konfigurasi versi...',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _error == null ? null : Colors.red),
                ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _version = null;
                    _error = null;
                  });
                  _loadVersion();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Cek ulang'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
