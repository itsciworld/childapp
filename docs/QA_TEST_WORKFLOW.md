# Vigil Child App — QA Test Workflow

**App:** Vigil (Child) · **Version:** 1.0.0+2 · **Platform:** Android (primary), iOS (limited)
**Audience:** QA / Tester · **Last updated:** 2026-07-19

> The Child app is installed on a child's device. It pairs to a parent account,
> requests a set of permissions, then quietly runs a background service that
> periodically uploads monitored data (SMS, calls, contacts, location, gallery,
> app usage, calendar events, and social-app messages) to the backend.
> Your job is to verify **setup**, **permissions**, and that **data actually syncs**.

---

## 1. Test Environment

| Item | Detail |
|------|--------|
| Test device(s) | Real Android phone(s) — **do not test the background service on an emulator** |
| Recommended Android | Android 12, 13, 14 (permission behaviour differs per version) |
| OEM coverage | Test at least one aggressive-battery OEM (Xiaomi/MIUI, Samsung, Oppo/Realme, Vivo) |
| Network | Wi-Fi + mobile data; also test offline → online recovery |
| Backend | Set via `.env` → `API_BASE_URL` (ask dev for the QA/staging URL) |
| Parent account | You need a paired **Parent app / dashboard** login to confirm data arrives |

> ⚠️ **Backend note:** the API runs on a tier that sleeps after ~15 min idle and
> can take up to ~60s to cold-start. The **first** request after idle may be slow —
> that is expected, not a bug. Re-check after the server wakes.

---

## 2. Test Data You Need Before Starting

- [ ] A **parent account** (email + password) that can issue a pairing code
- [ ] A valid **pairing code** for this test child
- [ ] Access to the **parent email inbox** (OTP is emailed)
- [ ] On the child device: a few **SMS**, **call log entries**, **contacts**, **photos**, and **calendar events**
- [ ] At least one **social app** installed and signed in for social-capture tests
      (WhatsApp, Telegram, Instagram, Messenger, Snapchat, Discord, Signal, Viber,
      X/Twitter, TikTok, LINE, Kik, Viber)

---

## 3. Setup / Onboarding Flow (happy path)

Screen order: **Splash → Terms → Login → Verify OTP → Pairing → Allow Permissions → Permissions → Child Home**

| # | Step | Expected result |
|---|------|-----------------|
| 3.1 | Launch app first time | Splash shows, then routes to Terms/Login |
| 3.2 | Accept Terms | Proceeds to Login |
| 3.3 | Enter **parent email + password**, tap Sign In | OTP is emailed to the parent address; app moves to Verify OTP screen |
| 3.4 | Enter the **OTP** from email | On success, moves to Pairing screen |
| 3.5 | Enter the **pairing code**, tap Verify | On success (child linked to parent), moves to Allow Permissions |
| 3.6 | Proceed through Allow Permissions intro | Moves to the Permissions screen |
| 3.7 | Grant each permission (see §4) | Each tile flips to granted |
| 3.8 | Submit / continue | Lands on **Child Home**; background service starts |

**Pass criteria:** child appears as **paired/online** in the parent dashboard, and Child Home shows monitoring tiles with live status.

---

## 4. Permissions Testing

The app requests these. Verify the **prompt appears**, **granting works**, and the **Home tile reflects state**.

| Permission | How granted | Notes to verify |
|-----------|-------------|-----------------|
| Location | OS prompt | Grant **Allow all the time** for background location; "While using" is not enough |
| Contacts | OS prompt | |
| SMS | OS prompt | Android only |
| Phone / Call log | OS prompt | Android only |
| Photos / Gallery | OS prompt | "Select photos…" (limited) must still count as **granted** and still upload selected photos |
| Notifications (post) | OS prompt | Needed for the persistent foreground-service notification |
| Nearby Wi-Fi devices | OS prompt | Android 13+ |
| Calendar | OS prompt | Full-access calendar |
| Usage access | **Settings page** (no callback) | Toggle on, return to app — state is re-checked on resume |
| Battery optimization exemption | OS prompt | **Critical** — must be "Don't optimize / Unrestricted" or the service gets killed |
| Notification access (special) | **Settings page** | Powers social-message capture **from notifications** |
| Accessibility service (special) | **Settings → Accessibility** | Powers **on-screen chat capture** from social apps |

**Permission tests to run:**
- [ ] Fresh grant of every permission → all tiles show granted
- [ ] **Deny** a permission → Home tile shows "Permission not provided" and offers a way to fix (opens app settings)
- [ ] **Revoke** a granted permission from system Settings, return to app → tile updates on resume
- [ ] Deny battery-optimization exemption → app should warn / re-prompt; note reliability impact
- [ ] Re-open app after some time on an aggressive-OEM device → exemption still holds (watchdog re-checks)

---

## 5. Data Sync Testing (the core)

Each data type is uploaded on its own timer by the background service. After granting
permissions, generate activity on the child device and confirm it appears in the parent
dashboard within the interval below (allow extra time for backend cold-start).

| Data type | Sync interval | How to test |
|-----------|---------------|-------------|
| Live status (online/battery) | ~1 min | Leave app running; confirm child shows online + battery % in dashboard |
| Location | ~1 min | Move device / mock a new location; confirm updated location + address |
| SMS | ~2 min | Send/receive an SMS on child device; confirm it syncs |
| Call logs | ~3 min | Make/receive a call; confirm log entry syncs |
| Social notifications | ~2 min | Receive a message in a target social app; confirm captured |
| Social accessibility (on-screen) | ~2 min | Open a chat in a target social app; confirm captured screen text |
| Notifications (general) | ~5 min | |
| Contacts | ~10 min | Add a contact; confirm it syncs |
| App usage | ~15 min | Use some apps; confirm usage stats sync |
| Gallery | ~15 min | Add a new photo; confirm it uploads |
| Calendar events | ~15 min | Add a calendar event; confirm it syncs |

> **Speed-up tip:** Bringing the app to the foreground triggers an immediate `syncNow`
> across all types — use this instead of waiting for each timer during testing.

**Sync tests:**
- [ ] Each type above appears in the parent dashboard
- [ ] Foregrounding the app forces an immediate sync
- [ ] Turn network **off**, generate data, turn network **on** → queued data syncs (no loss, no duplicates)
- [ ] Duplicate check: syncing twice does not create duplicate records

---

## 6. Social App Capture

Target apps (capture only works for these):
WhatsApp · WhatsApp Business · Telegram · Telegram Plus · Instagram · Messenger ·
Messenger Lite · Snapchat · Discord · Signal · Viber · X (Twitter) · TikTok · LINE · Kik

- [ ] With **Notification access** ON: a message received in a target app is captured (from notification)
- [ ] With **Accessibility** ON: opening a chat captures on-screen message text
- [ ] Non-target app (e.g. a random game) is **not** captured
- [ ] Sender/app name and message content are correct in the dashboard

---

## 7. Background Reliability / Persistence

This is the highest-risk area — Android aggressively kills background work.
Two independent mechanisms keep the service alive:

- **In-process watchdog** — checks every ~2 min, but only while the app process is alive.
- **WorkManager keep-alive (OS-level)** — a persisted JobScheduler job that fires roughly
  every 15 min and restarts the service **even after a full process kill or reboot**, with
  no need to reopen the app. **15 min is Android's minimum periodic cadence**, so after a
  hard kill, allow **up to ~15 min** for automatic recovery — that is expected, not a bug.

- [ ] Persistent foreground-service notification is visible while running
- [ ] Lock the device for 30–60 min → data still syncs
- [ ] Swipe the app from Recents → service keeps running / restarts (in-process watchdog)
- [ ] **Force Stop** the app (Settings → Apps → Force stop), then wait → service comes back
      on its own within ~15 min via WorkManager, **without opening the app**
- [ ] Reboot the device, do **not** open the app → service auto-restarts within ~15 min and resumes syncing
- [ ] Low battery / Battery Saver mode → note whether syncing continues
- [ ] Leave overnight → confirm continuous sync in the dashboard the next morning

> **How to verify WorkManager fired (dev/QA with adb):**
> `adb shell dumpsys jobscheduler | grep -i vigil` shows the scheduled job, and
> `adb logcat | grep -i "WorkManagerService\|ServiceWatchdog"` shows each keep-alive check.

---

## 8. Negative / Edge Cases

- [ ] Wrong parent email/password → clear error, no crash
- [ ] Wrong / expired OTP → clear error message
- [ ] Wrong / expired / already-used pairing code → clear error message
- [ ] No internet during login/pairing → graceful error, retry works
- [ ] Backend cold-start (first call slow) → app waits (~60s) rather than failing instantly
- [ ] Permission denied then later granted from settings → app recovers without reinstall
- [ ] Kill and relaunch app → stays logged in / paired (no re-onboarding)
- [ ] Rotate device / small screens → no layout overflow on onboarding screens

---

## 9. Bug Reporting Template

When filing a bug, please include:

```
Title:        [Screen/Feature] Short description
Severity:     Blocker / Critical / Major / Minor
Device:       e.g. Samsung A54, Android 14
App version:  1.0.0+2 (build number from Home/About)
Network:      Wi-Fi / Mobile / Offline
Steps to reproduce:
  1.
  2.
  3.
Expected:
Actual:
Frequency:    Always / Sometimes (x of y)
Attachments:  Screenshot / screen recording / logcat
```

**Logs (Android):** `adb logcat | grep -i "vigil\|BackgroundService\|BackgroundPermissions"`

---

## 10. Sign-off Checklist

- [ ] Onboarding flow completes end-to-end on all test devices
- [ ] All permissions grant, deny, and recover correctly
- [ ] Every data type syncs to the parent dashboard
- [ ] Social capture works for at least 3 target apps
- [ ] Background service survives lock, swipe-away, and reboot
- [ ] No crashes, no data loss, no duplicates
- [ ] All negative cases show clear errors (no silent failures)

**Tested by:** ______________  **Date:** ____________  **Build:** 1.0.0+2  **Result:** ☐ Pass ☐ Fail
