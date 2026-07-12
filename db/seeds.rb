require "base64"
require "stringio"

[ Document, ServiceVisit ].each do |klass|
  klass.find_each do |record|
    record.file.purge if record.respond_to?(:file) && record.file.attached?
    record.photos.each(&:purge) if record.respond_to?(:photos) && record.photos.attached?
  end
end

Session.delete_all
AccountMembership.delete_all
BinderNote.delete_all
Reminder.delete_all
Document.delete_all
ServiceVisitBatteryCheck.delete_all
ServiceVisitInspectionCheck.delete_all
ServiceVisitEngineReading.delete_all
ServiceVisit.delete_all
AssetBattery.delete_all
AssetEngine.delete_all
Asset.delete_all
Contact.delete_all
Subscription.delete_all
Account.delete_all
User.delete_all

def create_account!(attributes)
  creator = AccountCreator.call(account_attributes: attributes)
  raise creator.account.errors.full_messages.to_sentence unless creator.success?

  creator.account
end

captain = User.create!(
  name: "Hayes Captain",
  email_address: "captain@hayesyacht.test",
  password: "password",
  password_confirmation: "password",
  role: "captain",
  active: true
)

admin = User.create!(
  name: "Hayes Admin",
  email_address: "admin@hayesyacht.test",
  password: "password",
  password_confirmation: "password",
  role: "admin",
  active: true
)

hayes = create_account!(name: "Hayes Yacht Company", account_type: "internal")

owners = [
  create_account!(name: "Elliott Family", account_type: "client", notes: "Owns multiple vessels and prefers concise photo reports."),
  create_account!(name: "Harbor North LLC", account_type: "client", notes: "Operations manager approves maintenance work by email."),
  create_account!(name: "Marisol Trust", account_type: "client", notes: "Seasonal sailing schedule with spring commissioning checks."),
  create_account!(name: "Carter and Vale", account_type: "client", active: false, notes: "Inactive account retained for historical records.")
]

owners.each_with_index do |account, index|
  Contact.create!(
    account: account,
    name: [ "Avery Elliott", "Noah Pierce", "Maya Solano", "Jules Carter" ][index],
    email: "owner#{index + 1}@example.test",
    phone: "555-010#{index}",
    role: "Owner"
  )
end

owner_users = [
  User.create!(
    name: "Avery Elliott",
    email_address: "avery@owner.test",
    password: "password",
    password_confirmation: "password",
    role: "owner",
    active: true
  ),
  User.create!(
    name: "Noah Pierce",
    email_address: "noah@owner.test",
    password: "password",
    password_confirmation: "password",
    role: "owner",
    active: true
  ),
  User.create!(
    name: "Maya Solano",
    email_address: "maya@owner.test",
    password: "password",
    password_confirmation: "password",
    role: "owner",
    active: true
  )
]

AccountMembership.create!(user: owner_users[0], account: owners[0], access_level: "read_only", active: true)
AccountMembership.create!(user: owner_users[1], account: owners[1], access_level: "read_only", active: true)
AccountMembership.create!(user: owner_users[2], account: owners[2], access_level: "read_only", active: true)

Contact.create!(account: hayes, name: "Hayes Dispatch", email: "ops@hayesyacht.test", phone: "555-0140", role: "Captain")

vessels = [
  Asset.create!(
    account: owners[0],
    asset_type: "vessel",
    name: "Blue Meridian",
    make: "Sabre",
    model: "48 Salon Express",
    year: 2019,
    length: 48,
    registration_number: "HY-4821",
    marina: "Bainbridge Marina",
    slip: "C-18",
    notes: "Owner prefers fuel above half tank and interior dehumidifiers running after each visit.",
    active: true
  ),
  Asset.create!(
    account: owners[0],
    asset_type: "vessel",
    name: "Harbor Light",
    make: "Back Cove",
    model: "37",
    year: 2017,
    length: 37,
    registration_number: "HY-3709",
    marina: "Bainbridge Marina",
    slip: "C-21",
    notes: "Same owner as Blue Meridian. Check cabin heaters during winter visits.",
    active: true
  ),
  Asset.create!(
    account: owners[1],
    asset_type: "vessel",
    name: "Tide Runner",
    make: "Boston Whaler",
    model: "345 Conquest",
    year: 2022,
    length: 35,
    registration_number: "HN-3450",
    marina: "Elliott Bay Marina",
    slip: "F-42",
    notes: "Weekly checks during crab season. Confirm shore power and livewell switches.",
    active: true
  ),
  Asset.create!(
    account: owners[2],
    asset_type: "vessel",
    name: "Marisol",
    make: "Beneteau",
    model: "Oceanis 46.1",
    year: 2021,
    length: 46,
    registration_number: "MS-4610",
    marina: "Shilshole Bay Marina",
    slip: "J-07",
    notes: "Canvas covers must be secured before departure. Owner likes photo reports.",
    active: true
  ),
  Asset.create!(
    account: owners[3],
    asset_type: "vessel",
    name: "North Star",
    make: "Ranger Tugs",
    model: "R-31",
    year: 2018,
    length: 31,
    registration_number: "CV-3108",
    marina: "Port Orchard Marina",
    slip: "B-12",
    notes: "Monitor battery voltage and freshwater level every visit.",
    active: false
  )
]

vessels.each do |vessel|
  vessel.ensure_default_engines!
end

[
  [ vessels[0], "House Battery 1", "Engine room", "AGM" ],
  [ vessels[0], "House Battery 2", "Engine room", "AGM" ],
  [ vessels[0], "Port Start Battery", "Port engine bay", "AGM" ],
  [ vessels[0], "Starboard Start Battery", "Starboard engine bay", "AGM" ],
  [ vessels[1], "House Battery", "Aft lazarette", "AGM" ],
  [ vessels[1], "Start Battery", "Engine compartment", "AGM" ],
  [ vessels[2], "House Bank", "Console compartment", "Lithium" ],
  [ vessels[2], "Port Start Battery", "Engine room", "AGM" ],
  [ vessels[2], "Starboard Start Battery", "Engine room", "AGM" ],
  [ vessels[3], "House Battery 1", "Salon settee", "AGM" ],
  [ vessels[3], "Bow Thruster Battery", "Forward berth", "AGM" ],
  [ vessels[4], "House Battery", "Engine room", "Flooded" ]
].each do |vessel, name, location, battery_type|
  AssetBattery.create!(asset: vessel, name: name, location: location, battery_type: battery_type)
end

png = Base64.decode64(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII="
)

vessels.each_with_index do |vessel, index|
  Reminder.create!(
    asset: vessel,
    title: [ "Replace zincs", "Winter heater check", "Insurance renewal", "Registration tabs", "Annual safety inspection" ][index],
    due_date: Date.current + (index + 2).days,
    reminder_type: Reminder::REMINDER_TYPES[index % Reminder::REMINDER_TYPES.length],
    status: "pending"
  )

  Reminder.create!(
    asset: vessel,
    title: "Clean strainers",
    due_date: Date.current - (index + 1).days,
    reminder_type: "maintenance",
    status: index.even? ? "completed" : "pending",
    completed_at: index.even? ? Time.current - index.days : nil
  )

  BinderNote.create!(
    account: vessel.account,
    asset: vessel,
    title: "Owner preference",
    body: "Send concise reports with photos and note anything that might affect weekend use.",
    note_type: "owner_preference",
    due_date: index == 1 ? Date.current + 5.days : nil
  )

  BinderNote.create!(
    account: vessel.account,
    asset: vessel,
    title: "Dock line wear",
    body: "Forward spring line shows chafe and should be replaced before the next heavy-weather cycle.",
    note_type: index == 0 ? "issue" : "maintenance",
    due_date: index == 0 ? Date.current + 2.days : nil
  )

  visit = ServiceVisit.create!(
    asset: vessel,
    performed_by_user: index.even? ? captain : admin,
    visit_date: Date.current - index.days,
    engine_hours: 110 + (index * 18.4),
    location: "#{vessel.marina}, Slip #{vessel.slip}",
    summary: "Routine vessel check completed. Shore power, bilge, dock lines, and visible systems inspected.",
    condition_notes: "Exterior clean, bilge dry, batteries charging, and no unusual odors observed.",
    follow_up_needed: index == 0,
    follow_up_notes: index == 0 ? "Replace forward spring line and re-check dockside chafe protection." : "No owner action required."
  )

  vessel.active_engines.each_with_index do |engine, engine_index|
    ServiceVisitEngineReading.create!(
      service_visit: visit,
      asset_engine: engine,
      hours: 110 + (index * 18.4) + (engine_index * 0.6)
    )
  end

  ServiceVisit::DEFAULT_INSPECTION_LABELS.each_with_index do |label, check_index|
    checklist_note = case label
    when "Hull"
      "Hull and topsides visually clean."
    when "Bilge"
      "Bilge dry with no unusual odor."
    when "Shore power"
      index == 0 ? "Cord is secure; watch strain relief at pedestal." : "Connected and charging."
    when "Dock lines"
      index == 0 ? "Forward spring line shows chafe." : "Lines secure."
    end

    ServiceVisitInspectionCheck.create!(
      service_visit: visit,
      label: label,
      checked: check_index != 2 || index != 0,
      notes: checklist_note,
      position: check_index + 1
    )
  end

  vessel.active_batteries.each do |battery|
    ServiceVisitBatteryCheck.create!(
      service_visit: visit,
      asset_battery: battery,
      checked: true,
      voltage: 12.62 + (index * 0.04),
      notes: battery.name.include?("House") ? "Charging normally under shore power." : nil
    )
  end

  visit.photos.attach(
    io: StringIO.new(png),
    filename: "#{vessel.name.parameterize}-visit.png",
    content_type: "image/png"
  )

  document = Document.create!(
    account: vessel.account,
    asset: vessel,
    title: "#{vessel.name} registration",
    document_type: "registration",
    notes: "Sample registration record for demo review."
  )
  document.file.attach(
    io: StringIO.new("Demo document for #{vessel.name}\n"),
    filename: "#{vessel.name.parameterize}-registration.txt",
    content_type: "text/plain"
  )

  if index < 3
    policy = Document.create!(
      account: vessel.account,
      asset: vessel,
      title: "#{vessel.name} insurance",
      document_type: "insurance",
      notes: "Sample insurance certificate for demo review."
    )
    policy.file.attach(
      io: StringIO.new("Insurance certificate for #{vessel.name}\n"),
      filename: "#{vessel.name.parameterize}-insurance.txt",
      content_type: "text/plain"
    )
  end
end

puts "Seeded #{User.count} users, #{AccountMembership.count} memberships, #{Asset.vessels.count} vessels, #{ServiceVisit.count} visits, #{Reminder.count} reminders."
