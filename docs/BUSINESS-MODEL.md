# A business model that supports better mornings

Give people a useful free start, a clear reason to keep returning and an optional
paid upgrade. Grow through friends without turning the alarm into a sales screen.

**Status:** Revised model approved on 15 October 2026; pilot implementation is
complete with local checks passing; user value and production billing remain
unvalidated.
**Audience:** Product, design and engineering. Target US prices are the owner's
requested $2/month and $20/year. Production products have not been created.

## At a glance

Start with **a no-card full preview, useful Free access and optional Pro**.
People need evidence of value before they can reasonably decide to subscribe.
Do not add a points wallet, cash stakes or several paid tiers to the first release.

| Experience | Approved scope | Why it exists |
|---|---|---|
| Full preview | All current features for thirty elapsed days after the first successfully saved alarm; no card or signup | Experience enough real mornings to judge usefulness |
| Free after preview | Alarm scheduling, Gentle mode, Balanced's three push-ups, system sound for new alarms, Stop and recovery | Useful indefinitely, including for people who never subscribe |
| Pro monthly | Focused mode, extra sounds, thirty-day history and a custom weekly goal | A lower commitment paid option at about $2/month |
| Pro annual | The same Pro features | Support people who find lasting value at about $20/year |

The preview is not a subscription trial: it ends with no automatic charge or
renewal. The clock starts after a successful alarm save, not download or a failed
attempt. Existing confirmed alarms start a preview on refresh during migration.
Monthly and annual StoreKit products share one Pro entitlement, with no Apple
introductory offer in this model. Show live localized prices and renewal terms
only when the person voluntarily opens the purchase sheet.

Saved alarms, modes and sounds survive expiry. A saved Focused challenge runs a
clearly explained Balanced fallback during Free access; saved preferences return
when full access resumes. Progress is gated after expiry, while clearing retained
history remains free. See [subscription setup](SUBSCRIPTIONS.md) for exact scope.
Activity collections, paid cloud AI and rewarded referral attribution remain
planned. Only advertise features that work in the submitted build.

## One real journey

1. **First evening:** Save an alarm and begin the full preview. No card, purchase
   or friend invitation is required.
2. **First morning:** Complete the activity or choose another way to finish. Show
   a short confirmation, then let the person leave the app.
3. **After three completed mornings:** Offer nonblocking Pro discovery and show
   progress toward the chosen goal. Never place a paywall over a ringing alarm.
4. **When useful:** Share an illustrated morning card or invite one friend. Use
   the system share sheet; do not upload contacts or share camera footage.
5. **After a missed day:** Keep prior progress and offer an easy return. Do not
   add repetitions, penalties or pressure to buy.
6. **At thirty days:** Explain that the preview has ended and show the Free options.
   Offer monthly or annual Pro voluntarily; do not require payment to dismiss an
   alarm or retrieve the privacy controls.

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
can start the same no-card preview and use Free normally. Do not require an
invitation to create an alarm or start the preview.

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

Local progress is private, editable device data; it must not authorize referral
credit or a paid offer. Before adding valuable rewards, define server-verified
qualification, one inviter per new participant, no
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
| First iOS release | StoreKit 2 for local Pro; server verification is required before adding paid cloud access |
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
| Do people start? | First successfully saved alarm starts the preview cohort; report first completed morning separately |
| Do people return? | D7/D30 morning-use retention by preview-start cohort; also report completed scheduled days per week |
| Do challenges feel fair? | Completion by verification type, uncertainty/recovery rates and reported frustration |
| Is Pro useful? | Purchase conversion among preview cohorts with thirty full elapsed days of follow-up; separate purchases during/after preview, monthly/annual choice, renewal and refund rates |
| Do invitations bring lasting users? | Accepted invitations, qualified referrals and referred-user retention; compare with non-referred cohorts |
| Is paid AI sustainable? | Actual store proceeds after refunds minus allocated inference, hosting and other variable service costs per active paid user |

These are proposed metrics; no event pipeline or collection is claimed. Report
cohort size, observation window and missing records with every rate. D7 and D30
use the same declared morning-use event and only cohorts old enough to observe
that day. For conversion, divide unique purchasers by unique preview starters
with at least thirty elapsed days of follow-up, and state the purchase cutoff.
Do not compare a fresh cohort with a fully observed cohort.

App opens do not prove alarm
delivery or wakefulness. Longer screen time is not the objective: a short,
successful morning is a good outcome. Qwen self-hosting still has compute and
operating costs; do not advertise unlimited AI before measuring capacity.

Collect the minimum events needed, with an accurate privacy disclosure. Never
retain bedroom video to measure retention or referral success. Test one change
at a time where possible; these metrics alone do not establish causation.

## What we checked and what comes next

The original payment and offer-code research was recorded on 13 October 2026.
The owner approved the no-card preview revision on 15 October after challenging
the assumption that new users would subscribe before seeing value. No user
experiment or pricing study proves this model yet. Implementation checks and
App Store configuration must be recorded separately from this product decision.

1. Finish release gates and one complete free activity.
2. Validate preview expiry, Free fallback and both StoreKit plans locally, then
   configure production products and test sandbox/TestFlight purchases.
3. Use local progress and optional sharing to learn whether people return.
4. Evaluate retention and costs before building rewarded referrals or web payments.

## Read next

- [Release readiness and subscription engineering](RELEASE-READINESS.md)
- [Product direction and activity experiments](PRODUCT-BRIEF.md)
- [AI and challenge architecture](AI-AND-CHALLENGES-PLAN.md)
