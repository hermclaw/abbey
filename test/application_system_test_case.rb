require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :playwright,
    using: :chromium,
    screen_size: [1400, 1400],
    options: {
      headless: ENV["HEADLESS"] != "false",
      slow_mo: 0,
      channel: "chromium"
    }

  Capybara.server = :puma, { Silent: true }
end
