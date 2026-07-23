import 'dart:io';

import 'package:win32_registry/win32_registry.dart';

const String appName = 'Gravity Torrent';
const String appCapabilityPath = 'Software\\$appName\\Capabilities';

Future<void> registerAppInRegistry() async {
  await registerAppCmd();
  await registerApp();
  await registerCapabilities();
}

Future<void> registerAppCmd() async {
  final appPath = Platform.resolvedExecutable;

  const protocolRegKey = 'Software\\Classes\\$appName';
  const protocolCmdRegKey = 'shell\\open\\command';
  final protocolCmdRegValue = RegistryValue.string('"$appPath" "%1"');

  final regKey = CURRENT_USER.create(protocolRegKey);
  regKey.create(protocolCmdRegKey).setValue('', protocolCmdRegValue);
}

Future<void> registerApp() async {
  const appRegKey = 'Software\\RegisteredApplications';
  const appCapability = RegistryValue.string(appCapabilityPath);

  final regKey = CURRENT_USER.create(appRegKey);
  regKey.setValue(appName, appCapability);
}

Future<void> registerCapabilities() async {
  final regKey = CURRENT_USER.create(
    'Software\\$appName\\Capabilities',
  );
  regKey.setValue(
    'ApplicationDescription',
    const RegistryValue.string('BitTorrent software'),
  );

  final fileRegKey = CURRENT_USER.create(
    'Software\\$appName\\Capabilities\\FILEAssociations',
  );
  fileRegKey.setValue(
    '.torrent',
    const RegistryValue.string(appName),
  );

  final mimeRegKey = CURRENT_USER.create(
    'Software\\$appName\\Capabilities\\MIMEAssociations',
  );
  mimeRegKey.setValue(
    'application/x-bittorrent',
    const RegistryValue.string(appName),
  );

  final urlRegKey = CURRENT_USER.create(
    'Software\\$appName\\Capabilities\\URLAssociations',
  );

  urlRegKey.setValue(
    'magnet',
    const RegistryValue.string(appName),
  );

  await registerScheme('gravitytorrent');
}

Future<void> registerScheme(String scheme) async {
  final appPath = Platform.resolvedExecutable;

  final protocolRegKey = 'Software\\Classes\\$scheme';
  const protocolRegValue = RegistryValue.string('');
  const protocolCmdRegKey = 'shell\\open\\command';
  final protocolCmdRegValue = RegistryValue.string('"$appPath" "%1"');

  final regKey = CURRENT_USER.create(protocolRegKey);
  regKey.setValue('URL Protocol', protocolRegValue);
  regKey.create(protocolCmdRegKey).setValue('', protocolCmdRegValue);
}
