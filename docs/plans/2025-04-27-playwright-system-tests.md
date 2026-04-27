# Playwright System Tests Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** Replace Selenium-based system tests with Playwright for comprehensive end-to-end browser testing of the Abbey blog application.

**Architecture:** Replace `selenium-webdriver` with `capybara-playwright-driver`. Playwright communicates with Chromium via its native protocol, offering faster, more reliable tests with auto-waiting, network interception, and multi-browser support. Tests live in `test/system/` following Rails conventions. Integration tests cover API/feed endpoints that don't need a browser.

**Tech Stack:** Ruby on Rails 8.1, Minitest, Capybara, Playwright (via capybara-playwright-driver gem)

---

## Phase 1: Setup & Infrastructure

### Task 1: Add capybara-playwright-driver gem to Gemfile

**Objective:** Replace selenium-webdriver with the Playwright Capybara adapter.

**Files:**
- Modify: `Gemfile` (test group, line 63-68)

Remove `selenium-webdriver` and add `capybara-playwright-driver`:

```ruby
group :test do
  # Use system testing
  gem "capybara"
  gem "capybara-playwright-driver"
  gem "webmock"
end
```

**Run:** `bundle install`
**Expected:** Gemfile.lock updated with capybara-playwright-driver.

**Commit:**
```bash
git add Gemfile Gemfile.lock
git commit -m "chore: replace selenium-webdriver with capybara-playwright-driver"
```

### Task 2: Configure Playwright as the system test driver

**Objective:** Update `ApplicationSystemTestCase` to use Playwright instead of Selenium.

**Files:**
- Modify: `test/application_system_test_case.rb`

Replace entire contents:

```ruby
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
```

**Run:** `bundle exec playwright install chromium`
**Expected:** Chromium browser downloaded for Playwright.

**Run:** `rails test:system`
**Expected:** Runs with 0 tests, 0 failures.

**Commit:**
```bash
git add test/application_system_test_case.rb
git commit -m "test: configure Playwright as system test driver"
```

### Task 3: Update GitHub Actions CI workflow for Playwright

**Objective:** Update the CI workflow to install Playwright browsers.

**Files:**
- Modify: `.github/workflows/ci.yml`

Replace the entire `test` job:

```yaml
  test:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v6

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: .ruby-version
          bundler-cache: true

      - name: Install Playwright browser
        run: npx playwright install --with-deps chromium

      - name: Run tests
        env:
          RAILS_ENV: test
        run: bin/rails test:all

      - name: Upload screenshots on failure
        uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: screenshots
          path: ${{ github.workspace }}/tmp/screenshots
          if-no-files-found: ignore
```

**Changes from current:**
- Remove `sudo apt-get install google-chrome-stable` line
- Add `npx playwright install --with-deps chromium` step
- Change `bin/rails test` to `bin/rails test:all`

**Commit:**
```bash
git add .github/workflows/ci.yml
git commit -m "ci: update CI workflow for Playwright system tests"
```

---

## Phase 2: Test Helpers & Fixtures

### Task 4: Improve test fixtures for system testing

**Objective:** Create realistic fixtures that system tests can exercise.

**Files:**
- Modify: `test/fixtures/posts.yml`
- Modify: `test/fixtures/links.yml`
- Modify: `test/fixtures/pages.yml`
- Modify: `test/fixtures/feed_posts.yml`
- Modify: `test/fixtures/feeds.yml`

Replace `test/fixtures/posts.yml`:
```yaml
hello_world:
  draft: false
  title: Hello World
  markdown_body: |
    This is my first post. Welcome to the blog!
  markdown_excerpt: Welcome to the blog.
  slug: hello-world
  created_at: <%= 10.days.ago %>
  updated_at: <%= 10.days.ago %>

about_rails:
  draft: false
  title: About Rails
  markdown_body: |
    Ruby on Rails is a web application framework.
  markdown_excerpt: Ruby on Rails is a great framework.
  slug: about-rails
  created_at: <%= 5.days.ago %>
  updated_at: <%= 5.days.ago %>

draft_post:
  draft: true
  title: Draft Post
  markdown_body: This is a draft that should not appear publicly.
  markdown_excerpt: Draft excerpt.
  slug: draft-post
  created_at: <%= 1.day.ago %>
  updated_at: <%= 1.day.ago %>
```

Replace `test/fixtures/links.yml`:
```yaml
ruby_blog:
  url: https://rubylang.org
  title: Ruby Blog
  description: Official Ruby blog.

awesome_list:
  url: https://github.com/awesome
  title: Awesome Lists
  description: A curated list of awesome lists.
```

Replace `test/fixtures/pages.yml`:
```yaml
about:
  title: About
  slug: about
  markdown_body: This is the about page.

projects:
  title: Projects
  slug: projects
  markdown_body: Here are my projects.

presentations:
  title: Presentations
  slug: presentations
  markdown_body: Conference talks and presentations.
```

Replace `test/fixtures/feeds.yml`:
```yaml
ruby_blog_feed:
  name: Ruby Blog
  url: https://rubylang.org/en/news/index.xml

github_feed:
  name: GitHub Blog
  url: https://github.blog/feed/
```

Replace `test/fixtures/feed_posts.yml`:
```yaml
ruby_news:
  guid: ruby-news-1
  title: Ruby 3.4 Released
  summary: Ruby 3.4 comes with new features.
  url: https://rubylang.org/news/ruby-3-4
  published_at: <%= 2.days.ago %>
  promoted: false

github_news:
  guid: github-news-1
  title: GitHub Copilot Updates
  summary: New Copilot features announced.
  url: https://github.blog/copilot-updates
  published_at: <%= 1.day.ago %>
  promoted: false
```

**Run:** `rails test`
**Expected:** All existing tests pass (the LinksControllerTest uses `stub_request` to HTTP requests, so fixture URL changes won't affect them).

**Commit:**
```bash
git add test/fixtures/*.yml
git commit -m "test: add realistic fixtures for system testing"
```

### Task 5: Add system test sign-in helper

**Objective:** Create a reusable helper for signing in during system tests.

**Files:**
- Modify: `test/test_helper.rb`

Add after the `ActiveSupport::TestCase` block:

```ruby
module SignInHelper
  def sign_in_as(user)
    session = user.sessions.create!(user_agent: "Test", ip_address: "127.0.0.1")
    page.driver.browser.context.add_cookies([{
      name: "session_id",
      value: session.id.to_s,
      domain: Capybara.app_host || "127.0.0.1",
      path: "/",
      httpOnly: true
    }])
  end
end

class ActionDispatch::SystemTestCase
  include SignInHelper
end
```

This creates a session record and sets the `session_id` cookie directly — much faster than filling the login form.

**Commit:**
```bash
git add test/test_helper.rb
git commit -m "test: add system test sign-in helper"
```

---

## Phase 3: Blog System Tests

### Task 6: Blog public viewing tests (unauthenticated)

**Objective:** Test blog homepage and post viewing as an anonymous visitor.

**Files:**
- Create: `test/system/blog_public_test.rb`

```ruby
require "application_system_test_case"

class BlogPublicTest < ApplicationSystemTestCase
  test "homepage shows published posts" do
    visit root_path

    assert_selector "h2", text: "About Rails"
    assert_selector "h2", text: "Hello World"
    assert_no_selector "h2", text: "Draft Post"
  end

  test "can click through to a post detail page" do
    visit root_path

    click_link "About Rails"

    assert_selector "h1", text: "About Rails"
    assert_text "Ruby on Rails is a web application framework"
    assert_link "Back to posts"
  end

  test "homepage includes RSS feed link" do
    visit root_path
    assert_selector "link[type='application/atom+xml']", visible: false
  end

  test "published post shows date" do
    post = posts(:hello_world)
    visit dated_post_path(
      year: post.year,
      month: post.month,
      day: post.day,
      id: post
    )

    assert_text post.created_at.strftime("%Y-%m-%d")
  end
end
```

**Run:** `rails test test/system/blog_public_test.rb -v`
**Expected:** 4 passed.

**Commit:**
```bash
git add test/system/blog_public_test.rb
git commit -m "test: add blog public viewing system tests"
```

### Task 7: Blog admin CRUD tests (authenticated)

**Objective:** Test blog post creation, editing, and deletion as an authenticated admin.

**Files:**
- Create: `test/system/blog_admin_test.rb`

```ruby
require "application_system_test_case"

class BlogAdminTest < ApplicationSystemTestCase
  test "can create a new post" do
    sign_in_as users(:one)
    visit new_post_path

    fill_in "Title", with: "My Test Post"
    fill_in "Post tags", with: "test, rails"
    fill_in "Markdown excerpt", with: "This is the excerpt."
    fill_in "Markdown body", with: "This is the full post content."
    click_button "Create Post"

    assert_selector "h1", text: "My Test Post"
    assert_text "This is the full post content"
  end

  test "can edit an existing post" do
    sign_in_as users(:one)
    visit edit_post_path(posts(:hello_world))

    fill_in "Title", with: "Updated Hello World"
    click_button "Update Post"

    assert_selector "h1", text: "Updated Hello World"
  end

  test "can delete a post" do
    sign_in_as users(:one)
    visit edit_post_path(posts(:hello_world))

    accept_confirm do
      click_button "Delete"
    end

    assert_selector "h2", text: "About Rails"
    assert_no_selector "h2", text: "Hello World"
  end

  test "cannot create post with missing title" do
    sign_in_as users(:one)
    visit new_post_path

    fill_in "Title", with: ""
    fill_in "Markdown excerpt", with: "Excerpt"
    fill_in "Markdown body", with: "Body content"
    click_button "Create Post"

    assert_text "can't be blank"
  end

  test "draft checkbox is visible on post form" do
    sign_in_as users(:one)
    visit new_post_path

    assert_field "Draft", type: "checkbox"
  end
end
```

**Run:** `rails test test/system/blog_admin_test.rb -v`
**Expected:** 5 passed.

**Commit:**
```bash
git add test/system/blog_admin_test.rb
git commit -m "test: add blog admin CRUD system tests"
```

### Task 8: Navigation and layout tests

**Objective:** Test site navigation, header, footer, and admin bar visibility.

**Files:**
- Create: `test/system/blog_navigation_test.rb`

```ruby
require "application_system_test_case"

class BlogNavigationTest < ApplicationSystemTestCase
  test "site header displays blog title" do
    visit root_path
    assert_selector "header h1", text: "Abbey"
  end

  test "main navigation has expected links" do
    visit root_path

    assert_link "Home"
    assert_link "Links"
    assert_link "Papers"
    assert_link "About"
  end

  test "admin bar is hidden when logged out" do
    visit root_path
    assert_no_selector "div.fixed.top-0", visible: true
  end

  test "admin bar is visible when logged in" do
    sign_in_as users(:one)
    visit root_path

    assert_text "New Post"
    assert_text "New Page"
    assert_text "New Link"
  end

  test "footer is present on all pages" do
    visit root_path
    assert_selector "footer"

    page = pages(:about)
    visit page_path(page)
    assert_selector "footer"
  end

  test "can navigate to links page" do
    visit root_path
    click_link "Links"
    assert_current_path links_path
    assert_text "Links"
  end

  test "can navigate to papers page" do
    visit root_path
    click_link "Papers"
    assert_current_path papers_path
    assert_text "Papers"
  end
end
```

**Run:** `rails test test/system/blog_navigation_test.rb -v`
**Expected:** 7 passed.

**Commit:**
```bash
git add test/system/blog_navigation_test.rb
git commit -m "test: add navigation and layout system tests"
```

---

## Phase 4: Authentication System Tests

### Task 9: Authentication flow tests

**Objective:** Test login form, successful login, failed login, and logout.

**Files:**
- Create: `test/system/auth_test.rb`

```ruby
require "application_system_test_case"

class AuthTest < ApplicationSystemTestCase
  test "login page is displayed" do
    visit new_session_path

    assert_selector "h1", text: "Sign in"
    assert_field "email_address"
    assert_field "password"
    assert_button "Sign in"
  end

  test "successful login shows admin navigation" do
    visit new_session_path

    fill_in "email_address", with: users(:one).email_address
    fill_in "password", with: "password"
    click_button "Sign in"

    assert_text "New Post"
    assert_text "New Page"
  end

  test "failed login shows error message" do
    visit new_session_path

    fill_in "email_address", with: "nobody@example.com"
    fill_in "password", with: "wrongpassword"
    click_button "Sign in"

    assert_text "Try another email address or password"
  end

  test "can sign out after logging in" do
    sign_in_as users(:one)
    visit root_path

    click_button "Sign out"

    assert_current_path new_session_path
    assert_no_text "New Post"
  end

  test "unauthenticated user redirected to login when accessing admin pages" do
    visit new_post_path
    assert_current_path new_session_path
  end

  test "edit link visible on posts when logged in" do
    sign_in_as users(:one)
    visit root_path

    assert_link "Edit"
  end

  test "edit link hidden on posts when logged out" do
    visit root_path
    assert_no_link "Edit"
  end
end
```

**Run:** `rails test test/system/auth_test.rb -v`
**Expected:** 7 passed.

**Commit:**
```bash
git add test/system/auth_test.rb
git commit -m "test: add authentication system tests"
```

---

## Phase 5: Pages System Tests

### Task 10: Pages CRUD tests

**Objective:** Test static page creation, editing, and viewing.

**Files:**
- Create: `test/system/pages_test.rb`

```ruby
require "application_system_test_case"

class PagesTest < ApplicationSystemTestCase
  test "can view a public page" do
    visit page_path("about")
    assert_selector "h1", text: "About"
  end

  test "can create a new page" do
    sign_in_as users(:one)
    visit new_page_path

    fill_in "Title", with: "Contact"
    fill_in "Slug", with: "contact"
    fill_in "Markdown body", with: "Contact us here."
    click_button "Create Page"

    assert_selector "h1", text: "Contact"
    assert_text "Contact us here"
  end

  test "can edit an existing page" do
    sign_in_as users(:one)
    visit edit_page_path("about")

    fill_in "Markdown body", with: "Updated about page content."
    click_button "Update Page"

    assert_text "Updated about page content"
  end

  test "can delete a page" do
    sign_in_as users(:one)
    visit edit_page_path("about")

    accept_alert do
      click_button "Delete"
    end

    assert_current_path posts_path
  end
end
```

**Run:** `rails test test/system/pages_test.rb -v`
**Expected:** 4 passed.

**Commit:**
```bash
git add test/system/pages_test.rb
git commit -m "test: add pages system tests"
```

---

## Phase 6: Links System Tests

### Task 11: Links CRUD tests

**Objective:** Test link creation, editing, and deletion.

**Files:**
- Create: `test/system/links_test.rb`

```ruby
require "application_system_test_case"

class LinksTest < ApplicationSystemTestCase
  test "can view links index publicly" do
    visit links_path
    assert_text "Links"
  end

  test "can create a new link" do
    sign_in_as users(:one)
    visit new_link_path

    fill_in "Url", with: "https://example.com"
    fill_in "Title", with: "Example Site"
    click_button "Create Link"

    assert_text "Example Site"
  end

  test "can delete a link" do
    sign_in_as users(:one)
    visit edit_link_path(links(:ruby_blog))

    accept_confirm do
      click_button "Delete"
    end

    assert_current_path links_path
  end
end
```

**Note:** Link creation calls MetaInspector which makes external HTTP requests. Since system tests run against the real app server, these will fail in CI unless the URLs are stubbed or external network is available. Use URLs that respond reliably (e.g., example.com) or consider `WebMock` integration.

For the create test, `stub_request` only works in Minitest integration/controller tests, not system tests (separate process). Three options:
1. Use a real URL that responds (e.g., `https://example.com`)
2. Use `WebMock.allow_net_connect!` selectively in `config/environments/test.rb` for system tests
3. Mock the MetaInspector call in a before_save callback override

**Recommended:** Add to `test/test_helper.rb`:
```ruby
# Allow external HTTP requests for system tests (they hit real app server)
WebMock.allow_net_connect! if ENV["RAILS_SYSTEM_TEST"]
```
And set `RAILS_SYSTEM_TEST=1` when running `rails test:system`.

Or simpler: just use URLs known to respond (example.com, ruby-lang.org).

**Run:** `rails test test/system/links_test.rb -v`
**Expected:** 3 passed.

**Commit:**
```bash
git add test/system/links_test.rb
git commit -m "test: add links system tests"
```

---

## Phase 7: Feeds & Feed Posts System Tests

### Task 12: Feeds management tests

**Objective:** Test feed CRUD operations.

**Files:**
- Create: `test/system/feeds_test.rb`

```ruby
require "application_system_test_case"

class FeedsTest < ApplicationSystemTestCase
  test "can view feeds index" do
    sign_in_as users(:one)
    visit feeds_path

    assert_text "Test Feed"
    assert_text "Another Feed"
  end

  test "can create a new feed" do
    sign_in_as users(:one)
    visit new_feed_path

    fill_in "Name", with: "Hacker News RSS"
    fill_in "Url", with: "https://news.ycombinator.com/rss"
    click_button "Create Feed"

    assert_text "Feed was successfully created"
  end

  test "can delete a feed" do
    sign_in_as users(:one)
    visit feeds_path

    accept_confirm do
      click_button "Delete"
    end

    assert_text "Feed was successfully destroyed"
  end
end
```

**Run:** `rails test test/system/feeds_test.rb -v`
**Expected:** 3 passed.

**Commit:**
```bash
git add test/system/feeds_test.rb
git commit -m "test: add feeds system tests"
```

### Task 13: Feed posts index test

**Objective:** Test the feed reader index page.

**Files:**
- Create: `test/system/feed_posts_test.rb`

```ruby
require "application_system_test_case"

class FeedPostsTest < ApplicationSystemTestCase
  test "can view feed posts index" do
    sign_in_as users(:one)
    visit feed_posts_path

    assert_text "Ruby 3.4 Released"
    assert_text "GitHub Copilot Updates"
  end
end
```

**Run:** `rails test test/system/feed_posts_test.rb -v`
**Expected:** 1 passed.

**Commit:**
```bash
git add test/system/feed_posts_test.rb
git commit -m "test: add feed posts system tests"
```

---

## Phase 8: Blog Feed Integration Tests

### Task 14: Blog feed and tag feed integration tests

**Objective:** Test RSS/Atom feed endpoints (these don't need a browser).

**Files:**
- Modify: `test/controllers/blog_controller_test.rb`

Replace contents:

```ruby
require "test_helper"

class BlogControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get root_path
    assert_response :success
    assert_selector "h2", text: "Hello World", count: 1
    assert_selector "h2", text: "About Rails", count: 1
    assert_selector "h2", text: "Draft Post", count: 0
  end

  test "should get post by slug" do
    post = posts(:hello_world)
    get dated_post_path(year: post.year, month: post.month, day: post.day, id: post)
    assert_response :success
    assert_selector "h1", text: "Hello World"
  end

  test "should get blog feed" do
    get blog_feed_path
    assert_response :success
    assert_equal "application/atom+xml", response.content_type
    assert_includes response.body, "Hello World"
    assert_includes response.body, "About Rails"
    refute_includes response.body, "Draft Post"
  end

  test "should get tag feed" do
    tag = tags(:one)
    get tag_feed_path(id: tag)
    assert_response :success
    assert_equal "application/atom+xml", response.content_type
  end

  test "should redirect old post URLs" do
    post = posts(:hello_world)
    post.update!(redirect_from: "/post/#{post.slug}")

    get "/post/#{post.slug}"
    assert_redirected_to dated_post_path(
      year: post.year,
      month: post.month,
      day: post.day,
      id: post
    )
  end

  test "unauthenticated user cannot access new post form" do
    get new_post_path
    assert_redirected_to new_session_path
  end

  test "authenticated user can access new post form" do
    post session_path, params: { email_address: users(:one).email_address, password: "password" }

    get new_post_path
    assert_response :success
  end
end
```

**Run:** `rails test test/controllers/blog_controller_test.rb -v`
**Expected:** 7 passed.

**Commit:**
```bash
git add test/controllers/blog_controller_test.rb
git commit -m "test: add comprehensive blog controller integration tests"
```

---

## Verification & Cleanup

### Task 15: Run full test suite and fix any issues

**Run:** `rails test:all`
**Expected:** All tests pass (unit + integration + system).

If system tests fail due to Playwright browser missing:
- Run `bundle exec playwright install chromium`
- Verify `HEADLESS` env var is not set to `"false"`

If integration tests fail due to MetaInspector HTTP calls:
- Ensure `WebMock.allow_net_connect!` is set in the test helper, or
- Check if `WebMock` is already allowing certain hosts

### Task 16: Update AGENTS.md with Playwright information

**Files:**
- Modify: `AGENTS.md`

Add to the **Test** commands section:
```
- `rails test:all` - Run all tests including system tests (Playwright)
- `rails test:system` - Run only system tests
- `HEADLESS=false rails test:system` - Run system tests with visible browser
```

**Commit:**
```bash
git add AGENTS.md
git commit -m "docs: update AGENTS.md with Playwright test commands"
```

---

## Summary

This plan adds Playwright-based system tests while preserving the existing Minitest infrastructure. The test coverage spans:

| Category | Tests | What They Verify |
|----------|-------|----------------|
| Blog (public) | 4 | Homepage, post viewing, RSS, dates |
| Blog (admin) | 5 | Create, edit, delete, validation, drafts |
| Navigation | 7 | Header, footer, nav links, admin bar |
| Auth | 7 | Login, logout, redirects, access control |
| Pages | 4 | View, create, edit, delete |
| Links | 3 | View, create, delete |
| Feeds | 3 | View, create, delete |
| Feed Posts | 1 | Index view |
| Integration | 7 | Feed XML, redirects, access control |
| **Total** | **~41** | Full app coverage |

**Key conventions used:**
- **DRY:** Shared `SignInHelper` module avoids duplicating login logic
- **YAGNI:** Only test routes and flows that exist — no future-proofing for features not in the codebase
- **TDD:** Each test file is written and verified independently; if a test fails, fix the app code or test selector before moving to the next task
- **Frequent commits:** One commit per test file/phase for clean git history
