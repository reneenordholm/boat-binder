class NotFoundMessage
  MESSAGES = [
    "Looks like you've sailed into uncharted waters.",
    "This page appears to be off the charts.",
    "We couldn't find this port of call.",
    "That route doesn't appear on our chart.",
    "The page you're looking for has drifted out of view.",
    "No vessel record was found at these coordinates."
  ].freeze

  def self.default
    MESSAGES.first
  end

  def self.pick(seed: nil, messages: MESSAGES)
    choices = messages.presence
    return default unless choices

    choices[seed.to_s.bytes.sum % choices.length]
  rescue StandardError
    default
  end
end
