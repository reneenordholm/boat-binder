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
