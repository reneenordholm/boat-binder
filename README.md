# Boat Binder

Boat Binder is a mobile-first Rails SaaS MVP for vessel checks, maintenance visits, binder documents, reminders, notes, and owner-ready service reports.

## Stack

- Ruby on Rails 8.1
- PostgreSQL
- Tailwind CSS
- Rails authentication
- Active Storage
- Hotwire/Turbo

## Local Setup

```sh
/opt/homebrew/opt/ruby/bin/bundle install
/opt/homebrew/opt/ruby/bin/ruby bin/rails db:prepare
/opt/homebrew/opt/ruby/bin/ruby bin/rails server -p 3001
```

Open http://127.0.0.1:3001.

Demo login:

- Email: captain@hayesyacht.test
- Password: password

## Tests

```sh
/opt/homebrew/opt/ruby/bin/ruby bin/rails test:all
/opt/homebrew/opt/ruby/bin/ruby bin/rubocop
/opt/homebrew/opt/ruby/bin/ruby bin/bundler-audit
```

The test suite covers model validations, associations, and the primary captain workflow for recording a service visit and viewing the owner report. The `bin/bundler-audit` wrapper updates the local ruby-advisory-db before scanning so local gem vulnerability checks match CI more closely.

## Mobile Upload QA

After deploy, verify the native upload chooser on iPhone and Android:

- Document uploads offer supported file, photo-library, and camera options where available.
- Service visit photo uploads offer photo-library and camera options, but not PDF/document uploads.
- Desktop document uploads still accept PDFs and supported images.
- Desktop service visit uploads still accept supported image files.
- Unsupported uploads are rejected by server-side validation.

## Production Email

Boat Binder sends transactional email through SMTP in production. Phase 1 uses Mailgun SMTP for password reset emails only; account invitations, service visit notifications, reminders, and summaries are out of scope.

Configure these Heroku config vars before relying on password reset delivery:

- `SMTP_ADDRESS`
- `SMTP_PORT`
- `SMTP_DOMAIN`
- `SMTP_USERNAME`
- `SMTP_PASSWORD`
- `MAIL_FROM`
- `APP_HOST`

Do not commit SMTP credentials or add `.env`/dotenv support. Set values through Heroku config vars, for example:

```sh
heroku config:set SMTP_ADDRESS=smtp.mailgun.org SMTP_PORT=587 SMTP_DOMAIN=mg.example.com MAIL_FROM=no-reply@example.com APP_HOST=app.boat-binder.com
heroku config:set SMTP_USERNAME=postmaster@mg.example.com SMTP_PASSWORD=...
```

Password reset delivery failures are logged server-side and shown to users as a generic safe message to avoid account enumeration.

## Stripe Foundation

Boat Binder uses the official `stripe` Ruby gem for verified webhook receipt. Local `Subscription` records remain the app source of truth for access and UI behavior; normal app requests do not call Stripe to decide access.

Required Heroku config vars for Stripe-dependent operations:

- `STRIPE_SECRET_KEY`
- `STRIPE_PUBLISHABLE_KEY`
- `STRIPE_WEBHOOK_SECRET`
- `STRIPE_SELF_MANAGED_MONTHLY_PRICE_ID`
- `STRIPE_SELF_MANAGED_ANNUAL_PRICE_ID`

Do not commit Stripe keys or webhook secrets. Keep production values in Heroku config vars or Rails credentials. The app can boot without Stripe secrets for development/test workflows that do not invoke Stripe, but webhook verification fails safely until `STRIPE_WEBHOOK_SECRET` is configured.

### Subscription Plan Catalog

Boat Binder defines subscription billing options locally in `Billing::SubscriptionPlanCatalog`. The catalog is read-only application configuration; loading or reading it does not query Stripe and does not create Stripe Products, Prices, Customers, Checkout Sessions, or Subscriptions.

Initial application plan:

- Plan key: `self_managed`
- Monthly option key: `self_managed_monthly`, $14/month, 7-day trial metadata
- Annual option key: `self_managed_annual`, $154/year, 7-day trial metadata

The monthly and annual options are billing choices for the same stable `self_managed` application plan. Stripe Products and Prices are created manually in Stripe Dashboard. Configure the resulting test-mode Price IDs in development/staging with:

```sh
heroku config:set STRIPE_SELF_MANAGED_MONTHLY_PRICE_ID=price_test_monthly
heroku config:set STRIPE_SELF_MANAGED_ANNUAL_PRICE_ID=price_test_annual
```

Live-mode Price IDs must be configured separately before launch. Trial behavior is catalog metadata in this phase and will be applied later when Checkout is implemented. Subscription lifecycle synchronization, Checkout, billing portal, Stripe Customer creation, access enforcement, owner-user limits, crew invitations, account billing UI, and pricing-page UI remain deferred.

Webhook endpoint:

```text
POST https://app.boat-binder.com/webhooks/stripe
```

The endpoint verifies the raw request body with `Stripe::Webhook.construct_event`, stores event metadata in `billing_webhook_events`, and uses a unique `[provider, external_event_id]` index for idempotency. Full raw payloads, API keys, and signing secrets are not stored.

Current Phase 2 behavior intentionally records and ignores verified events. Subscription lifecycle synchronization, Checkout, billing portal, Stripe Customer creation, access enforcement, invoice sync, and billing UI are deferred.

### Local Stripe CLI Testing

1. Install and authenticate the Stripe CLI using Stripe's official instructions.
2. Start Rails locally, for example:

   ```sh
   /opt/homebrew/opt/ruby/bin/ruby bin/rails server -p 3000
   ```

3. Forward Stripe events to the local webhook endpoint:

   ```sh
   stripe listen --forward-to localhost:3000/webhooks/stripe
   ```

4. Copy the temporary CLI signing secret printed by `stripe listen` into `STRIPE_WEBHOOK_SECRET` for the Rails process you are testing. The CLI signing secret is different from the production Dashboard endpoint secret.
5. Trigger a harmless event:

   ```sh
   stripe trigger customer.subscription.updated
   ```

6. Confirm the request returns 2xx and a `BillingWebhookEvent` row is recorded with provider `stripe`, the external event ID, event type, livemode flag, and status `ignored`.

### Production Stripe Setup

In Stripe Dashboard, create an HTTPS webhook endpoint for:

```text
https://app.boat-binder.com/webhooks/stripe
```

Select the initial events this phase is ready to receive and ignore safely:

- `checkout.session.completed`
- `customer.subscription.created`
- `customer.subscription.updated`
- `customer.subscription.deleted`
- `invoice.paid`
- `invoice.payment_failed`
- `invoice.payment_succeeded`

Store the Dashboard endpoint signing secret in `STRIPE_WEBHOOK_SECRET`. Verify delivery from Stripe Dashboard after deployment before considering production webhook setup complete. Test-mode and live-mode deliveries are distinguished by the stored `livemode` flag.

Boat Binder recognizes both `invoice.paid` and `invoice.payment_succeeded` as deferred successful-invoice events in this phase. They are recorded and intentionally ignored until subscription lifecycle synchronization is implemented.
