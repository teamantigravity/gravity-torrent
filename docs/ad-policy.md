# Advertising placement and frequency

## Implemented policy

- No full-screen ads during the first app launch, including the first launch after this policy is installed.
- Later app launches allow **at most one interstitial presentation attempt**, only after at least **two successful, user-initiated torrent additions**. A launch means one process lifetime; background/foreground transitions do not reset the cap.
- The add dialog closes at that task boundary. An interstitial appears only if already loaded and the app is in the foreground. Failed, duplicate, cancelled, RSS, backup, and remote additions do not count.
- If inventory is missing, continue immediately. A later load callback never displays an ad; only another successful addition can create a new opportunity.
- No full-screen ads on launch/resume, tab changes, opening details or dialogs, starting/stopping playback, player back, pause/resume, or deletion. Scoped suppression also protects an active player (including teardown) and the purchase page if a deep link opens an add dialog over them.
- Ad-free purchases and the remote advertising kill switch remain authoritative. Full-screen load/show failures never block the user's action. Even a failed presentation attempt consumes that launch's cap, preventing repeat attempts.
- Existing footer banners remain separate from this interstitial policy. The app does not add a manual banner refresh timer.

This is a conservative initial product policy, not a claim of an experimentally optimal frequency. It uses completed tasks and a launch cap rather than elapsed wall-clock time. There are no retention or revenue experiments available to justify an optimal numeric cooldown. Any future change should evaluate retention, accidental clicks, complaints, and revenue together.

## Research and rationale

Primary sources reviewed on 25 October 2026:

1. [Google: disallowed interstitial implementations](https://support.google.com/admob/answer/6201362?hl=en) prohibits unexpected interstitials and showing one after every action, and specifies no more than one interstitial after every two user actions. We count two completed additions, rather than arbitrary taps, and add the stricter one-attempt-per-launch cap. Google does not prescribe that extra cap.
2. [Google: recommended interstitial implementations](https://support.google.com/admob/answer/6201350?hl=en) recommends natural breaks after a number of actions and preloading to avoid latency moving an ad into an unrelated task. Successful submission and closing the add dialog is the chosen task boundary. We do not wait for inventory or trigger from load callbacks.
3. [Google: Flutter interstitial integration](https://developers.google.com/admob/flutter/interstitial) describes natural transitions, one-use ad objects, full-screen callbacks, and disposal. The service reserves a presentation attempt before calling the SDK and disposes used/failed inventory.
4. [Google: Flutter app-open ads](https://developers.google.com/admob/flutter/app-open) recommends waiting until users have used the app a few times and showing ads while the app is loading, not after content is usable. Its **four-hour value is cached app-open-ad expiry**, not a recommended frequency interval. Gravity Torrent lacks an explicit ad-safe loading-screen placement, so this implementation removes app-open loading and resume presentation entirely.
5. [Google: AdMob frequency caps](https://support.google.com/admob/answer/6244508?hl=en) documents app-level and ad-unit-level caps. Those are separate server-side settings with propagation delays; the local policy takes effect immediately. No AdMob account settings were changed or claimed as configured.

## Verification

Policy tests cover first-use exclusion, two-task eligibility, a single atomic attempt, unavailable inventory, background completions, and fresh-launch task requirements. Mobile-service tests and the complete Flutter quality gate verify the platform implementation and caller changes. Native-device ad rendering and AdMob account configuration require device/account validation; unit tests do not establish those outcomes.
