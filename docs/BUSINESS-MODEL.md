# A business model that supports better mornings

Give people a useful free start, a clear reason to keep returning and an optional
paid upgrade. Grow through friends without turning the alarm into a sales screen.

**Status:** Proposed on 13 October 2026; not implemented or validated with users.
**Audience:** Product, design and engineering. Prices and offer configuration are
not approved or created by this plan.

## At a glance

Start with **freemium + one Pro subscription + an optional friend invitation**.
Habit progress supports repeated use; a trial lets people judge the paid value.
Do not add a points wallet, cash stakes or several paid tiers to the first release.

| Experience | Proposed scope | Why it exists |
|---|---|---|
| Free | Reliable alarms, Stop/recovery, a small sound selection, one complete basic challenge and simple weekly progress | Useful indefinitely, including for people who never subscribe |
| Pro trial | A proposed 7-day introductory trial for eligible users, started explicitly | Try the implemented Pro experience across several mornings |
| Pro monthly | A maintained activity collection, richer progress and bounded cloud AI where validated | A lower commitment paid option |
| Pro annual | The same Pro features with a lower effective monthly price, if selected | Support people who already find lasting value |

These are proposed benefits. The current pilot does not yet include this Free/Pro
split, progress tracking, activity collection, purchases or referrals. Only list
features on a paywall after they work.

Apple supports a one-week introductory free trial for monthly and annual
subscriptions. Eligibility is limited to one introductory offer per subscription
group. Show the localized renewal price, date and cancellation terms before the
person starts; a conventional subscription trial renews unless cancelled.
[Apple introductory offers](https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-introductory-offers-for-auto-renewable-subscriptions/)

Do not add a weekly paid subscription or a separate Lite purchase initially.
Free covers limited features; monthly Pro covers shorter paid commitment. At the
end of paid access, retain alarms and offer a free challenge fallback.

## One real journey

1. **First evening:** Set an alarm, choose one familiar activity and try it. No
   purchase or friend invitation is required.
2. **First morning:** Complete the activity or choose another way to finish. Show
   a short confirmation, then let the person leave the app.
3. **After a few mornings:** Show progress toward the person's chosen weekly goal.
   Offer Pro discovery after completion or in settings, never over a ringing alarm.
4. **When useful:** Share an illustrated morning card or invite one friend. Use
   the system share sheet; do not upload contacts or share camera footage.
5. **After a missed day:** Keep prior progress and offer an easy return. Do not
   add repetitions, penalties or pressure to buy.

## Encourage commitment without making it a condition of purchase

Let people choose a goal such as three or five scheduled mornings per week.
Measure progress against their chosen schedule, including shift work and rest
days. A stricter mode is an explicit effort choice, not a permanent label.

Use a short optional programme, such as 14 days, to make the next step concrete.
This is a product experiment, not a claim that habits form in 14 days. Keep task
duration and effort predictable; preview changes before the next alarm.

Record completion honestly: locally checked, AI verified, self-confirmed,
dismissed or unavailable. Self-confirmation remains a valid exit but must not be
reported as AI verification. An uncertain AI result should offer recovery, not
erase progress or accuse the person of cheating.

Start with weekly progress and a small milestone illustration. Do not build a
tradable currency, paid streak repair, cash penalties or public rankings. Paid
features remain available regardless of streak or sharing activity. Apple says
users must receive purchased subscription benefits without additional tasks.
[App Review Guidelines, section 3.1.2](https://developer.apple.com/app-store/review/guidelines/)

## Invite a friend

First ship a share card and an optional invitation code/link. The invited person
can use Free normally. Do not require an invitation to create an alarm or claim
an otherwise eligible introductory offer.

For a later rewarded pilot, try one simple rule: a new invited person completes
three qualifying morning activities on distinct scheduled days within seven days.
Both people receive a small celebration; test whether a StoreKit promotional
offer is useful before promising free Pro time or discounts. Record completion
type separately and never require camera use solely to qualify for a referral.

If a campaign gives subscription access, use an eligible Apple offer code and
verified redemption. Do not implement referral rewards by arbitrarily extending
an Apple subscription expiration in Firestore. Apple's offer-code configuration
can also provide a free offer that does not auto-renew; test eligibility, duration
and redemption in the sandbox before advertising it.
[Apple offer codes](https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-subscription-offer-codes/)

Before adding valuable rewards, define one inviter per new participant, no
self-referrals, a small campaign cap and idempotent qualification/redemption.
Use durable account ownership for rewards; reinstalling with another anonymous
Firebase UID must not repeatedly earn the same offer. Do not reward ratings,
reviews, contact uploads or unsolicited messages. A purchase remains valid even
if no referral ever qualifies.

Referral thresholds and rewards above are hypotheses, not measured optimal rules.
Keep the first version to sharing if durable identity or reward economics is not
ready.

## Payments: support local preferences with the right checkout

For the Vietnam iOS release, sell Pro through **StoreKit 2 in-app purchase**.
Apple currently lists MoMo, ZaloPay, VNPAY, ShopeePay and most credit/debit cards
as Apple Account payment methods in Vietnam. Users configure these with Apple;
HiMorning does not need a separate wallet SDK to accept that App Store purchase.
Availability and eligibility remain controlled by Apple and the payment provider.
[Apple payment methods, Vietnam](https://support.apple.com/vi-vn/111741)

Apple Pay merchant checkout is a different flow from StoreKit. Do not present
Apple Pay, a bank-transfer QR, MoMo or ZaloPay direct checkout as an alternative
way to unlock iOS Pro in Vietnam. Exceptions depend on storefront and programme;
an iOS link to a future web checkout needs a fresh policy review.
[App Review Guidelines, sections 3.1.1 and 3.1.3](https://developer.apple.com/app-store/review/guidelines/)

| Stage | Payment work |
|---|---|
| First iOS release | StoreKit 2; Firebase verifies Apple transactions for paid cloud access |
| Future Android release | Add a Google Play billing integration after checking its current regional rules |
| Future web sales | Evaluate a payment provider supporting the requested wallets, bank payments and Apple Pay; confirm recurring-payment support, refunds and reconciliation |
| Cross-platform access | Map verified purchases to one account entitlement; show the original billing channel and avoid charging an existing subscriber twice |

Keep billing verification separate from feature access using the existing client,
backend and shared-contract boundaries. Add another provider only when that sales
channel actually exists. No multi-provider gateway or unused payment abstraction
is needed now. One-off bank payments are not automatically recurring subscriptions.

## Measure whether the model helps

| Question | Proposed measurement |
|---|---|
| Do people start? | First saved alarm and first completed morning activity; report both steps |
| Do people return? | D7/D30 morning-use retention by signup cohort; also report completed scheduled days per week |
| Do challenges feel fair? | Completion by verification type, uncertainty/recovery rates and reported frustration |
| Is Pro useful? | Eligible trial starts, trial-to-paid conversion after the trial window, renewal and refund rates |
| Do invitations bring lasting users? | Accepted invitations, qualified referrals and referred-user retention; compare with non-referred cohorts |
| Is paid AI sustainable? | Actual store proceeds after refunds minus allocated inference, hosting and other variable service costs per active paid user |

Use explicit denominators and mature cohorts. App opens do not prove alarm
delivery or wakefulness. Longer screen time is not the objective: a short,
successful morning is a good outcome. Qwen self-hosting still has compute and
operating costs; do not advertise unlimited AI before measuring capacity.

Collect the minimum events needed, with an accurate privacy disclosure. Never
retain bedroom video to measure retention or referral success. Test one change
at a time where possible; these metrics alone do not establish causation.

## What we checked and what comes next

This plan was checked against the existing product and release plans and Apple's
payment, introductory-offer and offer-code documentation on 13 October 2026.
No user experiment, payment-provider contract, purchase test or pricing study was
performed. No runtime code, subscription product or checkout was changed.

1. Finish release gates and one complete free activity.
2. Select implemented Pro benefits; configure and test StoreKit purchases/trials.
3. Add small weekly progress and optional share cards.
4. Evaluate retention and costs before building rewarded referrals or web payments.

## Read next

- [Release readiness and subscription engineering](RELEASE-READINESS.md)
- [Product direction and activity experiments](PRODUCT-BRIEF.md)
- [AI and challenge architecture](AI-AND-CHALLENGES-PLAN.md)
