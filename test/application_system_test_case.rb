require "test_helper"
require "database_cleaner/active_record"

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

  self.use_transactional_tests = true
  fixtures :all

  # Clean session data between tests; fixture data stays in the transaction.
  teardown do
    Session.delete_all
  end
end
