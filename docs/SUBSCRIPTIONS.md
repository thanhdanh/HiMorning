# Preview, Free and Pro

A successfully saved first alarm starts a no-card preview. StoreKit purchases are
optional and separate from basic alarm delivery and recovery.

**Status:** StoreKit was included in internal TestFlight builds. The revised Pro screen and challenge trials are in development.
On 10 November 2026, App Store Connect showed no subscription groups and
the Paid Apps Agreement was **New**. Sandbox billing verification is pending.
**Audience:** iOS developers and release reviewers.

## At a glance

| Access | Current behavior |
|---|---|
| Before first save | Explore and create a draft; preview time has not started |
| Preview | 30 elapsed days from the first confirmed alarm save; no purchase or automatic charge |
| Preview / Pro | All catalog levels, bundled sounds, 30-day progress view and custom weekly goal; an optional energetic mission path and 30-day challenge reflection |
| Free after expiry | Alarm scheduling and recovery; Gentle and Balanced choices, Reach up in the Challenging category, and system sound for new choices; three starter purposes, seven-morning journeys and recent completed-day summary |
| Monthly Pro | `com.himorning.pro.monthly`, local target price US $2/month |
| Annual Pro | `com.himorning.pro.annual`, local target price US $20/year, same subscription group |

The live Apple purchase sheet owns actual localized price and renewal terms.
The local StoreKit fixture is not a production price or a live product. There is
no introductory offer in the checked-in fixture. Cloud AI quotas, referral rewards
and server-side billing are not Pro benefits implemented here.

## How access works

`PreviewPeriod` starts after a successful save, or for an existing confirmed alarm
on refresh. Failed saves and unresolved schedule errors do not start it. Keychain
stores start/latest-observed time to limit simple clock rollback; this is not a
cross-device entitlement or a guarantee against reinstall/device changes.

`SubscriptionStore` reads verified StoreKit entitlements, subscription status and
transaction updates. The two products grant the same local Pro access. The source
handles signed expiry, revocation, supersession and grace periods. The
[subscription plan](plans/ios-subscription.md) records the current local evidence.

Expiration does not cancel alarms, rewrite their saved settings or remove
remaining backup rings. Locked Challenging tasks use Reach up on Free unless an
earned trial applies to the ringing occurrence. Legacy Gentle and Balanced
push-ups are capped at five repetitions on Free. Existing native sound registrations are
preserved; choosing a new restricted sound still requires full access.
The [catalog guide](MODE-CHALLENGES.md) distinguishes display labels from storage IDs.

Local outcomes retain the effective mode/challenge at completion. Rehearsal is
excluded. A completed challenge scores 100, self-confirmation scores zero, and
missing records are unscored. History retains up to 31 local calendar days so a
31-day month's first day is available; the paid progress view covers 30 days and
shows a weekly goal. There is no history-deletion UI.

## Ongoing routine value

The [morning journeys](FIRST-MORNING-PLAN.md) connect existing challenges into a
purposeful sequence. Free includes clear-start, gentle-movement and reading-aloud
starter purposes, seven earned mornings, small milestones and an explicit next
round. Missed days do not erase earned steps. Practice and self-confirmation do
not advance the journey, and one local day can earn only one step.

Preview/Pro includes an explicitly selected energetic movement path and a
30-day reflection showing actual completed days and the challenge kinds the user
returns to. It describes completion records, not sleep quality or verified waking
time. This is a hypothesis for recurring value, not evidence of conversion or
willingness to pay.

After expiry, an existing energetic purpose suggests gentle missions while
preserving earned steps and stored intent. Saved alarm schedules and recovery
choices remain unchanged. Mission suggestions are applied through an alarm draft
that the user reviews and saves; a repeated alarm does not silently rotate its
saved challenge. Journey progress is stored separately from the journal so its
31-day retention does not erase an unfinished path after a longer break.

## Configure and test

The Pro screen shows StoreKit’s localized full monthly and yearly prices,
the renewal terms, and a single Subscribe to Pro button. Apple confirms the
selected plan. Retry and restore are available when the catalog fails.
Restore asks the App Store to sync and reports whether active Pro access was
found. Active subscribers can open Apple's management sheet.

Use the checked-in [`HiMorning.storekit`](../apps/ios/StoreKit/HiMorning.storekit)
configuration for local tests. Pick a simulator UDID from `make doctor`.

```sh
make ios-uitest IOS_SIM=YOUR_SIMULATOR_UDID ONLY=HiMorningTests/SubscriptionTests
make ios-uitest IOS_SIM=YOUR_SIMULATOR_UDID ONLY=HiMorningUITests/SubscriptionUITests
```

StoreKitTest creates local transactions without charging a card. The Make target
keeps ad-hoc signing for Keychain-backed preview tests. The workflow pins iOS 26.2.

### One alarm challenge trial

On iOS Free, the info sheet for a locked challenge offers an optional rewarded
ad when configured. AdMob's earned callback saves a local credit. The user
applies that credit and saves the editor to schedule the challenge on that
alarm’s next occurrence. Its regular challenge resumes afterward. Draft
cancellation leaves the credit available. Rehearsal never uses a credit.

Debug builds use Google's demo ad unit. An internal-only TestFlight archive
can use the same Google demo app and rewarded-unit identifiers with the
`TESTFLIGHT_DEMO_ADS` Swift compilation condition. Keep that override out of
App Store archives.

For production, add HiMorning under **Apps** in AdMob, and create a **Rewarded**
ad unit with one challenge trial as its reward. Set `ADMOB_APPLICATION_ID` and
`ADMOB_REWARDED_AD_UNIT_ID` to the matching iOS identifiers in Release. Configure
privacy messages under **Privacy & messaging**. After publishing to the App
Store, link the listing in AdMob, put Google's `app-ads.txt` entry at the root
of the developer website in the listing’s Marketing URL, and verify the app
and its readiness status in AdMob. See the [AdMob rewarded guide](https://developers.google.com/admob/ios/rewarded)
and its [privacy setup](https://developers.google.com/admob/ios/privacy).

## App Store Connect and TestFlight

1. In **Business → Agreements**, the Account Holder updates their legal
   entity information, signs the Paid Apps Agreement and completes the
   banking and tax information. Verify the agreement is active. [Apple setup](https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/overview-for-configuring-in-app-purchases/)
2. Under **Monetization → Subscriptions**, verify or create one `HiMorning Pro`
   group. Configure `com.himorning.pro.monthly` for one month and
   `com.himorning.pro.annual` for one year at the same service level. Set the
   approved storefront prices, availability, English/Vietnamese metadata and
   review screenshot. [Apple subscription setup](https://developer.apple.com/app-store/subscriptions/)
3. Use internal TestFlight build 1.0 (2) to verify the configured products.
   Archive and upload a new build when the app code changes. On an iPhone
   using TestFlight, verify both plans, localized price and terms,
   restore after reinstall, management, renewal, cancellation, pending approval,
   refund, grace if enabled, and expiry back to preview or Free. Verify basic
   alarm delivery and recovery after losing paid access. [Apple sandbox testing](https://developer.apple.com/help/app-store-connect/test-in-app-purchases/overview-of-testing-in-sandbox)
4. Add the first subscription group and both products to the same App Review
   submission as the app version. [Apple submission steps](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase)

## What we checked

[Validation](VALIDATION.md) documents the October test failure. The
[subscription plan](plans/ios-subscription.md) records the follow-up checks.
Earlier [monthly](tdd/monthly-pro.tdd.md) and [preview](tdd/no-card-preview.tdd.md)
reports remain historical checkpoints. Simulator fixtures do not prove live billing,
actual renewal delivery or migration across App Store accounts/devices.

## Read next

[Release readiness](RELEASE-READINESS.md) · [Running](RUNNING.md) ·
[Local access rules](../apps/ios/HiMorningCore/Sources/HiMorningCore/Morning.swift)
