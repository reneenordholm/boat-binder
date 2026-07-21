# Configuration

Core local boot usually works without production credentials. The variables below enable optional production-like behavior.

## Application Host

- `APP_HOST` - host used in production email links, such as `app.boat-binder.com`.

## SMTP / Mailgun

- `SMTP_ADDRESS`
- `SMTP_PORT`
- `SMTP_DOMAIN`
- `SMTP_USERNAME`
- `SMTP_PASSWORD`
- `MAIL_FROM`

These are required before production transactional email can actually deliver.

## Stripe

- `STRIPE_SECRET_KEY` - secret API key for Stripe-dependent operations.
- `STRIPE_PUBLISHABLE_KEY` - publishable key reserved for future client-side billing flows.
- `STRIPE_WEBHOOK_SECRET` - signing secret for `/webhooks/stripe`.
- `STRIPE_SELF_MANAGED_MONTHLY_PRICE_ID` - Stripe Price ID for the Self Managed monthly option.
- `STRIPE_SELF_MANAGED_ANNUAL_PRICE_ID` - Stripe Price ID for the Self Managed annual option.

Stripe keys and webhook secrets should be set in Heroku config vars or Rails credentials. Do not commit real keys. The app can boot without Stripe secrets for development/test workflows that do not invoke Stripe; webhook verification fails safely until `STRIPE_WEBHOOK_SECRET` is configured.

## Build Week Demo

- `BUILD_WEEK_DEMO_EMAIL` - optional login email. Local default: `demo@boat-binder.com`.
- `BUILD_WEEK_DEMO_PASSWORD` - required in production. Development/test default: `boat-binder-build-week-demo`.

The demo runner never prints the password. Do not expose the production demo password in committed documentation.
