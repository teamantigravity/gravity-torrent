import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:win32_registry/win32_registry.dart';

const String appName = 'Gravity Torrent';
const String appCapabilityPath = 'Software\\$appName\\Capabilities';

Future<void> registerAppInRegistry() async {
  try {
    await registerAppCmd();
    await registerApp();
    await registerCapabilities();
  } catch (e, st) {
    debugPrint('Windows registry registration failed: $e\n$st');
  }
}

Future<void> registerAppCmd() async {
  try {
    final appPath = Platform.resolvedExecutable;

    const protocolRegKey = 'Software\\Classes\\$appName';
    const protocolCmdRegKey = 'shell\\open\\command';

    final regKey = CURRENT_USER.create(protocolRegKey);
    final cmdKey = regKey.create(protocolCmdRegKey);
    try {
      cmdKey.setValue('', RegistryValue.string('"$appPath" "%1"'));
    } finally {
      cmdKey.close();
      regKey.close();
    }
  } catch (e, st) {
    debugPrint('registerAppCmd failed: $e\n$st');
  }
}

Future<void> registerApp() async {
  try {
    const appRegKey = 'Software\\RegisteredApplications';

    final regKey = CURRENT_USER.create(appRegKey);
    try {
      regKey.setValue(
        appName,
        const RegistryValue.string(appCapabilityPath),
      );
    } finally {
      regKey.close();
    }
  } catch (e, st) {
    debugPrint('registerApp failed: $e\n$st');
  }
}

Future<void> registerCapabilities() async {
  try {
    final regKey = CURRENT_USER.create('Software\\$appName\\Capabilities');
    try {
      regKey.setValue(
        'ApplicationDescription',
        const RegistryValue.string('BitTorrent software'),
      );

      final fileRegKey = regKey.create('FILEAssociations');
      try {
        fileRegKey.setValue(
          '.torrent',
          const RegistryValue.string(appName),
        );
      } finally {
        fileRegKey.close();
      }

      final mimeRegKey = regKey.create('MIMEAssociations');
      try {
        mimeRegKey.setValue(
          'application/x-bittorrent',
          const RegistryValue.string(appName),
        );
      } finally {
        mimeRegKey.close();
      }

      final urlRegKey = regKey.create('URLAssociations');
      try {
        urlRegKey.setValue(
          'magnet',
          const RegistryValue.string(appName),
        );
      } finally {
        urlRegKey.close();
      }

      await registerScheme('gravitytorrent');
    } finally {
      regKey.close();
    }
  } catch (e, st) {
    debugPrint('registerCapabilities failed: $e\n$st');
  }
}

Future<void> registerScheme(String scheme) async {
  try {
    final appPath = Platform.resolvedExecutable;

    final protocolRegKey = 'Software\\Classes\\$scheme';
    const protocolCmdRegKey = 'shell\\open\\command';

    final regKey = CURRENT_USER.create(protocolRegKey);
    try {
      final cmdKey = regKey.create(protocolCmdRegKey);
      try {
        regKey.setValue(
          'URL Protocol',
          const RegistryValue.string(''),
        );
        cmdKey.setValue('', RegistryValue.string('"$appPath" "%1"'));
      } finally {
        cmdKey.close();
      }
    } finally {
      regKey.close();
    }
  } catch (e, st) {
    debugPrint('registerScheme($scheme) failed: $e\n$st');
  }
}
