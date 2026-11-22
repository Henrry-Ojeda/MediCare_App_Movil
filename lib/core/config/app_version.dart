const String kAppVersion = '1.1.0';
const int kAppBuildNumber = 2;
const String kVersionManifestUrl = 'https://medi-care-ebon.vercel.app/downloads/version.json';

bool isNewerAppVersion({
  required String remoteVersion,
  required int remoteBuildNumber,
  String currentVersion = kAppVersion,
  int currentBuildNumber = kAppBuildNumber,
}) {
  final remoteParts = _parseSemver(remoteVersion);
  final currentParts = _parseSemver(currentVersion);
  for (var i = 0; i < 3; i++) {
    if (remoteParts[i] > currentParts[i]) return true;
    if (remoteParts[i] < currentParts[i]) return false;
  }
  return remoteBuildNumber > currentBuildNumber;
}

List<int> _parseSemver(String raw) {
  final clean = raw.trim().replaceFirst(RegExp(r'^v', caseSensitive: false), '');
  final parts = clean.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  while (parts.length < 3) {
    parts.add(0);
  }
  return parts.take(3).toList();
}
