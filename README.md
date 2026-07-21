# Boat Binder

**The digital home for boat ownership.**

Boat Binder is a mobile-first Rails SaaS MVP for vessel ownership records, maintenance history, reminders, documents, owner notes, and client-ready service reports. It is built for boat owners who need one reliable place for vessel details and for captains or service teams who need a clean operational view of what has happened, what needs attention, and what should be shared with an owner.

## Current Capabilities

- Owner, captain, and admin roles with scoped account access.
- Vessel records backed internally by the generic `Asset` model.
- Primary vessel photos, owner/account details, contacts, and account time zones.
- Binder documents with upload validation.
- Binder notes, reminders, and vessel status signals.
- Service visits with engine readings, inspection checks, battery checks, follow-up items, report previews, and summary emails.
- Mailgun SMTP-backed transactional email for password resets, account invitations, and service visit summaries.
- Stripe webhook receipt foundation and local subscription-domain records.

Boat Binder is still an MVP. Stripe Checkout, billing portal, subscription enforcement, public signup, AI-powered document search, and maintenance-insight features are roadmap items rather than implemented customer-facing features.

## Build Week

- Tagline: **The digital home for boat ownership.**
- Live demo: [https://app.boat-binder.com](https://app.boat-binder.com)
- Repository: [https://github.com/reneenordholm/boat-binder](https://github.com/reneenordholm/boat-binder)
- Demo data: fictional owner dataset for Build Week judging.
- Demo access: owner role, active `editor` membership, scoped to the fictional demo account.

Create or refresh the Build Week demo account:

```sh
bin/rails runner db/seeds/build_week_demo.rb
```

The shared demo account may be modified by judges and restored by rerunning the command. Do not commit or document the production demo password. See [Build Week Demo](docs/build-week-demo.md) for Heroku setup and safety details.

## Tech Stack

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
- RuboCop, Bundler Audit, Brakeman
- GitHub Advanced Security / CodeQL review

## Quick Local Setup

Prerequisites: Ruby matching `.ruby-version`, Bundler, PostgreSQL, and libvips.

```sh
git clone https://github.com/reneenordholm/boat-binder.git
cd boat-binder
bundle install
bin/rails db:prepare
bin/dev
```

`bin/dev` runs Rails and Tailwind watchers through `Procfile.dev`. The app defaults to port 3000 unless `PORT` is set. You can also run `bin/rails server`.

## Tests And Security Checks

```sh
bin/rails test
bin/rails test:system
bin/rubocop
bin/brakeman --no-pager
bin/bundler-audit
bin/importmap audit
```

The `bin/bundler-audit` wrapper updates the local ruby-advisory-db before scanning so local vulnerability checks match CI more closely.

## Built With OpenAI

Boat Binder was built with human product direction and review, with OpenAI tools used as collaborators throughout the process.

Codex was used as an engineering collaborator for implementing scoped GitHub issues, generating and updating tests, refactoring Rails code, investigating CI failures, addressing security review findings, hardening Stripe webhook processing, improving documentation, and preparing pull requests.

GPT-5.6 was used as a product and engineering thought partner for product discovery, roadmap planning, architecture discussions, threat modeling, security review, interpreting logs and CI failures, designing manual QA plans, reviewing pull requests and Copilot findings, drafting implementation prompts and documentation, and shaping the Build Week demo and submission.

Human judgment remained responsible for product direction, architecture decisions, review and validation, manual testing, deployment, and final approval. Boat Binder does not currently include GPT-5.6-powered customer-facing features; AI-powered document search and maintenance insights are roadmap ideas.

## Detailed Documentation

- [Build Week Demo](docs/build-week-demo.md)
- [Configuration](docs/configuration.md)
- [Production Email](docs/email.md)
- [Stripe Foundation](docs/stripe.md)
- [Mobile Upload QA](docs/mobile-upload-qa.md)
