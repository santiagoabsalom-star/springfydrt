import 'dart:io';

import 'package:flutter/material.dart';

class NotSupportedPlatformPage extends StatefulWidget {
  const NotSupportedPlatformPage({super.key});

  @override
  State<NotSupportedPlatformPage> createState() => _NotSupportedPlatformPageState();
}

class _NotSupportedPlatformPageState extends State<NotSupportedPlatformPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String get platformName {
    if (Platform.isAndroid) return "Android";
    if (Platform.isIOS) return "iOS";
    if (Platform.isWindows) return "Windows";
    if (Platform.isMacOS) return "macOS";
    if (Platform.isLinux) return "Linux";
    return Platform.operatingSystem;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.not_interested_rounded,
                  size: 80,
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 40),
              Text(
                "Plataforma no disponible",
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "La aplicación Springfy aún no está optimizada para ejecutarse en $platformName.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text("Entendido"),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),


            ],
          ),
        ),
      ),
    );
  }
}
