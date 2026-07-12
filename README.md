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
```

The test suite covers model validations, associations, and the primary captain workflow for recording a service visit and viewing the owner report.

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
