# Dorm API

## Owner

- Dorm collaboration teammate

## Facade

- `DormFacade.currentDorm`
- `DormFacade.currentUserId`
- `DormFacade.updateCurrentUserStatus({status, sleepModeActive, note})`
- `DormFacade.saveRules(settings)`
- `DormFacade.createInvite()`
- `DormFacade.acceptInvite(inviteCode)`

## Streams behind the facade

- `DormRepository.watchDorm()`
- `DormRepository.watchMembers()`
- `DormRepository.watchRules()`
- `DormRepository.watchEvents()`

## Cloud data

- `dorms/{dormId}`
- `dorms/{dormId}/members/{uid}`
- `dorms/{dormId}/rules/{ruleId}`
- `dorms/{dormId}/events/{eventId}`
- `dorms/{dormId}/invites/{inviteId}`

## Integration notes

- `acceptInvite()` now updates the user profile dorm id and creates the member record
- Current client flow reads invites directly; move this to callable functions later for stricter security
