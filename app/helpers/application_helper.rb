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
      neutral: "bg-slate-100 text-slate-700",
      urgent: "bg-red-100 text-red-700",
      success: "bg-emerald-100 text-emerald-700",
      warning: "bg-amber-100 text-amber-800"
    }

    tag.span text, class: "inline-flex items-center rounded-full px-2.5 py-1 text-xs font-semibold #{colors.fetch(tone)}"
  end
end
