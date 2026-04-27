require "application_system_test_case"

class FeedsTest < ApplicationSystemTestCase
  test "can view feeds index when logged in" do
    sign_in_as users(:one)
    visit feeds_path
    assert_text "Ruby Blog"
    assert_text "GitHub Blog"
  end
end
