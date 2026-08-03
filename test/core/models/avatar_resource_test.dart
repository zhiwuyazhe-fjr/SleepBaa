import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_dorm_app/core/models/avatar_resource.dart';

void main() {
  group('AvatarResource.mergeRemote', () {
    test('adopts a refreshed URL for the same storage resource', () {
      const AvatarResource current = AvatarResource(
        url: 'https://cdn.example.com/avatar.png?sig=first',
        storagePath: 'avatars/user.png',
      );

      final AvatarResource merged = current.mergeRemote(
        const AvatarResource(
          url: 'https://cdn.example.com/avatar.png?sig=second',
          storagePath: 'avatars/user.png',
        ),
      );

      expect(merged.url, contains('sig=second'));
      expect(merged.storagePath, 'avatars/user.png');
    });

    test(
      'keeps the previous URL only when signing the same resource fails',
      () {
        const AvatarResource current = AvatarResource(
          url: 'https://cdn.example.com/avatar.png?sig=first',
          storagePath: 'avatars/user.png',
        );

        final AvatarResource merged = current.mergeRemote(
          const AvatarResource(storagePath: 'avatars/user.png'),
        );

        expect(merged.url, contains('sig=first'));
      },
    );

    test('does not reuse a URL when the storage resource changes', () {
      const AvatarResource current = AvatarResource(
        url: 'https://cdn.example.com/avatar-old.png?sig=first',
        storagePath: 'avatars/old.png',
      );

      final AvatarResource merged = current.mergeRemote(
        const AvatarResource(storagePath: 'avatars/new.png'),
      );

      expect(merged.url, isNull);
      expect(merged.storagePath, 'avatars/new.png');
    });
  });
}
