# Build Week Demo

Boat Binder includes a repeatable fictional owner dataset for Build Week judging.

## Demo Account

- Account/owner: Alex Johnson
- Login email: `BUILD_WEEK_DEMO_EMAIL`, defaulting locally to `demo@boat-binder.com`
- Password: `BUILD_WEEK_DEMO_PASSWORD`
- Role: owner
- Membership: active `editor`
- Account type: client
- Time zone: America/Los_Angeles
- Subscription: local legacy/active subscription
- Vessels: Sea Breeze and Reel Escape

The demo account is intentionally owner-scoped. It does not grant admin or captain access, does not create a Stripe Customer or Stripe Subscription, and does not call Stripe.

## Create Or Refresh

Local:

```sh
BUILD_WEEK_DEMO_EMAIL=demo@boat-binder.com BUILD_WEEK_DEMO_PASSWORD=change-me-locally bin/rails runner db/seeds/build_week_demo.rb
```

Heroku:

```sh
heroku config:set BUILD_WEEK_DEMO_EMAIL=demo@boat-binder.com BUILD_WEEK_DEMO_PASSWORD='use-a-secure-demo-password' --app boat-binder
heroku run bin/rails runner db/seeds/build_week_demo.rb --app boat-binder
```

Production requires `BUILD_WEEK_DEMO_PASSWORD`. Development and test have a documented demo-only default: `boat-binder-build-week-demo`.

The script never prints the password.

## Idempotency And Safety

The script is safe to run repeatedly.

- Finds or creates one marked demo account named Alex Johnson.
- Refuses to modify an unmarked real account with the same name.
- Finds or creates one owner user by `BUILD_WEEK_DEMO_EMAIL`.
- Refuses to reuse that email if the user belongs to another account or is not an owner.
- Refreshes only demo records under the marked demo account.
- Leaves unrelated accounts, vessels, users, documents, notes, reminders, and service visits untouched.
- Wraps the setup in a database transaction.

The shared demo account may be modified by judges. Restore the fictional dataset by rerunning:

```sh
bin/rails runner db/seeds/build_week_demo.rb
```

## Demo Content

The dataset includes fictional document metadata, service visits, reminders, binder notes, engine readings, inspection checks, battery checks, and follow-up items. It does not include real customer data, real vessel details, private email addresses, copyrighted manuals, or fabricated attachment paths.
