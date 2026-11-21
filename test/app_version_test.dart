import 'package:flutter_test/flutter_test.dart';
import 'package:medicare_doctor_app/core/config/app_version.dart';

void main() {
  test('detecta versiones semánticas y buildNumber más altos', () {
    expect(
      isNewerAppVersion(
        remoteVersion: '1.2.0',
        remoteBuildNumber: 2,
        currentVersion: '1.1.0',
        currentBuildNumber: 2,
      ),
      isTrue,
    );
    expect(
      isNewerAppVersion(
        remoteVersion: '1.1.0',
        remoteBuildNumber: 3,
        currentVersion: '1.1.0',
        currentBuildNumber: 2,
      ),
      isTrue,
    );
    expect(
      isNewerAppVersion(
        remoteVersion: '1.1.0',
        remoteBuildNumber: 2,
        currentVersion: '1.1.0',
        currentBuildNumber: 2,
      ),
      isFalse,
    );
  });
}
