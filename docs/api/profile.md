# Profile API

## Owner

- Infrastructure / shared contract

## Facade

- `ProfileFacade.currentUser`
- `ProfileFacade.currentSettings`
- `ProfileFacade.saveProfile({displayName, tagline, role, settings})`
- `ProfileFacade.saveNightMood(mood)`
- `ProfileFacade.updateAvatar({avatarPath, avatarBytes})`

## Cloud data

- `users/{uid}`
- `user_settings/{uid}`
- `users/{uid}/notification_tokens/{tokenId}`
- Storage: `avatars/{uid}/profile.jpg`

## Local-only state

- Image picker temporary path
- Unsaved form edits

## Integration notes

- Persist only `avatarUrl`; keep raw bytes local for immediate preview
- Team members should call the facade only, never write profile documents from pages
