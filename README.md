# Boat Binder

**The digital home for boat ownership.**

Boat Binder is a mobile-first Rails SaaS MVP for vessel ownership records, maintenance history, reminders, documents, owner notes, and client-ready service reports. It is built for boat owners who need one reliable place for vessel details and for captains or service teams who need a clean operational view of what has happened, what needs attention, and what should be shared with an owner.

Current capabilities include:

- Owner, captain, and admin roles with scoped account access.
- Vessel records backed internally by the generic `Asset` model.
- Primary vessel photos, owner/account details, contacts, and account time zones.
- Binder documents with upload validation.
- Binder notes, reminders, and vessel status signals.
- Service visits with engine readings, inspection checks, battery checks, follow-up items, report previews, and summary emails.
- Mailgun SMTP-backed transactional email for password resets, account invitations, and service visit summaries.
- Stripe webhook receipt foundation and local subscription-domain records.

This repository is still an MVP. Stripe Checkout, billing portal, subscription enforcement, public signup, AI-powered document search, and maintenance-insight features are roadmap items rather than implemented customer-facing features.

## Build Week

- Tagline: **The digital home for boat ownership.**
- Live demo: [https://app.boat-binder.com](https://app.boat-binder.com)
- Repository: [https://github.com/reneenordholm/boat-binder](https://github.com/reneenordholm/boat-binder)
- Demo data: fictional owner dataset for Build Week judging.
- Demo access: owner-level access only.

Create or refresh the Build Week demo account with:

```sh
bin/rails runner db/seeds/build_week_demo.rb
```

On Heroku:

```sh
heroku run bin/rails runner db/seeds/build_week_demo.rb --app boat-binder
```

The script is idempotent and scoped to one marked demo account. It refreshes fictional demo content for Alex Johnson without deleting or modifying unrelated accounts. Do not put the production demo password in this README; set it with `BUILD_WEEK_DEMO_PASSWORD` before running the script in production.

## Stack

- Ruby and Ruby on Rails 8.1
- PostgreSQL
- Hotwire/Turbo and Stimulus
- Tailwind CSS
- Active Storage
- Action Mailer with Mailgun SMTP
- Stripe Ruby SDK for verified webhook receipt
- Heroku deployment
- GitHub Actions CI
- Minitest and system tests
- RuboCop
- Bundler Audit
- Brakeman
- GitHub Advanced Security / CodeQL review

## Local Setup

Prerequisites:

- Ruby matching `.ruby-version`
- Bundler
- PostgreSQL
- libvips for Active Storage image variants
- Node-free Rails asset workflow via importmap and Tailwind CSS Rails

Clone and install:

```sh
git clone https://github.com/reneenordholm/boat-binder.git
cd boat-binder
bundle install
bin/rails db:prepare
```

Start the app:

```sh
bin/dev
```

`bin/dev` runs Rails and Tailwind watchers through `Procfile.dev`. The app defaults to port 3000 unless `PORT` is set. You can also start Rails directly:

```sh
bin/rails server
```

Run tests and checks:

```sh
bin/rails test
bin/rails test:system
bin/rubocop
bin/brakeman --no-pager
bin/bundler-audit
bin/importmap audit
```

The `bin/bundler-audit` wrapper updates the local ruby-advisory-db before scanning so local vulnerability checks match CI more closely.

## Environment Variables

Core local boot usually works without production credentials. The variables below enable optional production-like behavior.

Application host:

- `APP_HOST` - host used in production email links, such as `app.boat-binder.com`.

SMTP / Mailgun:

- `SMTP_ADDRESS`
- `SMTP_PORT`
- `SMTP_DOMAIN`
- `SMTP_USERNAME`
- `SMTP_PASSWORD`
- `MAIL_FROM`

These are required before production transactional email can actually deliver.

Stripe:

- `STRIPE_SECRET_KEY` - secret API key for Stripe-dependent operations.
- `STRIPE_PUBLISHABLE_KEY` - publishable key reserved for future client-side billing flows.
- `STRIPE_WEBHOOK_SECRET` - signing secret for `/webhooks/stripe`.
- `STRIPE_SELF_MANAGED_MONTHLY_PRICE_ID` - Stripe Price ID for the Self Managed monthly option.
- `STRIPE_SELF_MANAGED_ANNUAL_PRICE_ID` - Stripe Price ID for the Self Managed annual option.

Stripe keys and webhook secrets should be set in Heroku config vars or Rails credentials. Do not commit real keys. The app can boot without Stripe secrets for development/test workflows that do not invoke Stripe; webhook verification fails safely until `STRIPE_WEBHOOK_SECRET` is configured.

Build Week demo:

- `BUILD_WEEK_DEMO_EMAIL` - optional login email. Local default: `demo@boat-binder.com`.
- `BUILD_WEEK_DEMO_PASSWORD` - required in production. Development/test default: `boat-binder-build-week-demo`.

The demo runner never prints the password.

## Demo Account Data

Create or refresh the demo owner account locally:

```sh
BUILD_WEEK_DEMO_EMAIL=demo@boat-binder.com BUILD_WEEK_DEMO_PASSWORD=change-me-locally bin/rails runner db/seeds/build_week_demo.rb
```

Create or refresh it on Heroku:

```sh
heroku config:set BUILD_WEEK_DEMO_EMAIL=demo@boat-binder.com BUILD_WEEK_DEMO_PASSWORD='use-a-secure-demo-password' --app boat-binder
heroku run bin/rails runner db/seeds/build_week_demo.rb --app boat-binder
```

The script creates one fictional owner account:

- Owner/account: Alex Johnson
- Role: owner
- Account type: client
- Time zone: America/Los_Angeles
- Subscription: local legacy/active subscription, with no Stripe Customer or Stripe Subscription
- Vessels: Sea Breeze and Reel Escape

It also creates fictional document metadata, service visits, reminders, binder notes, engine readings, inspection checks, battery checks, and follow-up items. It uses stable identifiers, marks the account as Build Week demo data, refuses to modify an unmarked real account with the same name, and refreshes only records belonging to the marked demo account.

## Production Email

Boat Binder sends transactional email through SMTP in production. Mailgun SMTP is configured through Heroku config vars. Current transactional email includes password resets, account invitations, and service visit summaries.

Do not commit SMTP credentials or add `.env`/dotenv support. Set values through Heroku config vars, for example:

```sh
heroku config:set SMTP_ADDRESS=smtp.mailgun.org SMTP_PORT=587 SMTP_DOMAIN=mg.example.com MAIL_FROM=no-reply@example.com APP_HOST=app.boat-binder.com --app boat-binder
heroku config:set SMTP_USERNAME=postmaster@mg.example.com SMTP_PASSWORD=... --app boat-binder
```

Password reset delivery failures are logged server-side and shown to users as a generic safe message to avoid account enumeration.

## Stripe Foundation

Boat Binder uses the official `stripe` Ruby gem for verified webhook receipt. Local `Subscription` records remain the app source of truth for access and UI behavior; normal app requests do not call Stripe to decide access.

Webhook endpoint:

```text
POST https://app.boat-binder.com/webhooks/stripe
```

The endpoint verifies the raw request body with `Stripe::Webhook.construct_event`, stores event metadata in `billing_webhook_events`, and uses a unique `[provider, external_event_id]` index for idempotency. Full raw payloads, API keys, and signing secrets are not stored.

Current Stripe behavior intentionally records and ignores verified subscription and invoice events. Subscription lifecycle synchronization, Checkout, billing portal, Stripe Customer creation, access enforcement, invoice sync, and billing UI are deferred.

### Local Stripe CLI Testing

1. Install and authenticate the Stripe CLI using Stripe's official instructions.
2. Start Rails locally:

   ```sh
   bin/rails server
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

## Mobile Upload QA

After deploy, verify the native upload chooser on iPhone and Android:

- Document uploads offer supported file, photo-library, and camera options where available.
- Service visit photo uploads offer photo-library and camera options, but not PDF/document uploads.
- Desktop document uploads still accept PDFs and supported images.
- Desktop service visit uploads still accept supported image files.
- Unsupported uploads are rejected by server-side validation.

## Built with OpenAI

Boat Binder was built with human product direction and review, with OpenAI tools used as collaborators throughout the process.

Codex was used as an engineering collaborator for work such as:

- Implementing scoped GitHub issues.
- Generating and updating tests.
- Refactoring Rails models, controllers, views, and services.
- Investigating CI failures.
- Addressing security review findings.
- Hardening Stripe webhook processing.
- Improving documentation.
- Preparing pull requests.

GPT-5.6 was used as a product and engineering thought partner for work such as:

- Product discovery and roadmap planning.
- Architecture discussions.
- Threat modeling and security review.
- Interpreting logs and CI failures.
- Designing manual QA plans.
- Reviewing pull requests and Copilot findings.
- Drafting implementation prompts and documentation.
- Shaping the Build Week demo and submission.

Human judgment remained responsible for product direction, architecture decisions, review and validation, manual testing, deployment, and final approval. Boat Binder does not currently include GPT-5.6-powered customer-facing features; AI-powered document search and maintenance insights are roadmap ideas.
