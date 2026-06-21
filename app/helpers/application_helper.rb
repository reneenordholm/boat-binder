module ApplicationHelper
  def short_date(value)
    value&.strftime("%b %-d, %Y") || "Not recorded"
  end

  def field_error_messages(record)
    return if record.errors.empty?

    tag.div class: "rounded-md border border-red-200 bg-red-50 p-4 text-sm text-red-700" do
      safe_join(record.errors.full_messages.map { |message| tag.p(message) })
    end
  end

  def status_chip(text, tone: :neutral)
    colors = {
      neutral: "bg-[#F7F5F2] text-[#0B1F35] ring-1 ring-[#E7DED2]",
      urgent: "bg-red-50 text-red-700 ring-1 ring-red-100",
      success: "bg-emerald-50 text-emerald-700 ring-1 ring-emerald-100",
      warning: "bg-amber-50 text-amber-800 ring-1 ring-amber-100",
      info: "bg-[#E8F3F5] text-[#1E5A7A] ring-1 ring-[#C9DEE2]"
    }

    tag.span text, class: "inline-flex items-center rounded-full px-2.5 py-1 text-xs font-bold #{colors.fetch(tone)}"
  end

  def user_display_name(user)
    user.name.presence || user.email_address
  end

  def user_first_name(user)
    user.name.to_s.split.first.presence || user.email_address.to_s.split("@").first.presence || "there"
  end

  def role_label(user)
    user.role.to_s.humanize
  end

  def dashboard_title
    return "Dashboard" unless Current.user

    "#{role_label(Current.user)} Dashboard"
  end

  def app_card_class(extra = "")
    "rounded-md border border-[#E7DED2] bg-white shadow-sm shadow-[#0B1F35]/5 #{extra}".squish
  end

  def primary_button_class(extra = "")
    "inline-flex min-h-11 items-center justify-center rounded-md bg-[#1E5A7A] px-4 py-2 text-sm font-black text-white shadow-sm transition hover:bg-[#174760] #{extra}".squish
  end

  def secondary_button_class(extra = "")
    "inline-flex min-h-11 items-center justify-center rounded-md border border-[#D7E4E7] bg-white px-4 py-2 text-sm font-black text-[#0B1F35] transition hover:border-[#7DAAB3] hover:bg-[#F7F5F2] #{extra}".squish
  end

  def subtle_link_class(extra = "")
    "rounded-md px-3 py-2 text-sm font-black text-[#1E5A7A] transition hover:bg-[#E8F3F5] #{extra}".squish
  end

  def app_nav_items
    items = [
      [ "Dashboard", root_path, "D" ],
      [ "Vessels", vessels_path, "V" ]
    ]
    items << [ "Owners", owners_path, "O" ] if internal_user?
    items << [ "Documents", documents_path, "F" ]
    items << [ "Service Visits", service_visits_path, "S" ]
    items << [ "Users", admin_users_path, "U" ] if admin_user?
    items
  end
end
