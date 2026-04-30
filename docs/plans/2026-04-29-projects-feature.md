# Projects Feature Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** Replace the static "Projects" Page with a dedicated Project model and controller, so admins can add/edit individual project rows that render at `/projects`.

**Architecture:** New `Project` model with fields: `name`, `year`, `github_url`, `license`, `language`, `description`. New `ProjectsController` with a public `index` action and admin-only CRUD. The `/projects` route points directly to `ProjectsController#index` instead of redirecting to the old Page. The old "Projects" Page seed and fixture are removed.

**Tech Stack:** Rails 8, ActiveRecord, Tailwind CSS, Minitest

---

### Task 1: Create the Project model migration

**Objective:** Add a `projects` table with the required fields.

**Files:**
- Create: `db/migrate/YYYYMMDDHHMMSS_create_projects.rb`

**Step 1: Generate the migration**

```bash
cd ~/.hermes-openrouter/github-repos/abbey
bin/rails generate migration CreateProjects name:string year:integer github_url:string license:string language:string description:text
```

**Step 2: Open the generated migration and verify it looks correct**

The migration file (in `db/migrate/`) should contain:

```ruby
class CreateProjects < ActiveRecord::Migration[8.0]
  def change
    create_table :projects do |t|
      t.string :name, null: false
      t.integer :year
      t.string :github_url
      t.string :license
      t.string :language
      t.text :description

      t.timestamps
    end
  end
end
```

If `null: false` wasn't added automatically, add it to the `:name` line manually.

**Step 3: Run the migration**

```bash
bin/rails db:migrate
```

Expected: output showing `CreateProjects: migrated`.

**Step 4: Verify schema.rb updated**

```bash
grep -A 12 'create_table "projects"' db/schema.rb
```

Expected: shows the `projects` table with all columns.

**Step 5: Commit**

```bash
git add db/migrate/*_create_projects.rb db/schema.rb
git commit -m "feat: add projects table migration"
```

---

### Task 2: Create the Project model with validations

**Objective:** Define the Project model with presence validations and a default scope.

**Files:**
- Create: `app/models/project.rb`
- Test: `test/models/project_test.rb`

**Step 1: Write failing model tests**

Create `test/models/project_test.rb`:

```ruby
require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  test "valid project with all fields" do
    project = Project.new(
      name: "Abbey",
      year: 2024,
      github_url: "https://github.com/capotej/abbey",
      license: "MIT",
      language: "Ruby",
      description: "A personal blog."
    )
    assert project.valid?
  end

  test "invalid without name" do
    project = Project.new(name: nil)
    assert_not project.valid?
    assert_includes project.errors[:name], "can't be blank"
  end

  test "ordered by year descending by default" do
    old = Project.create!(name: "Old", year: 2020)
    recent = Project.create!(name: "Recent", year: 2024)
    assert_equal [ recent, old ], Project.order(year: :desc)
  end
end
```

**Step 2: Run tests to verify failure**

```bash
bin/rails test test/models/project_test.rb -v
```

Expected: FAIL — `uninitialized constant ProjectTest::Project`

**Step 3: Write the Project model**

Create `app/models/project.rb`:

```ruby
class Project < ApplicationRecord
  validates :name, presence: true

  scope :by_year, -> { order(year: :desc) }
end
```

**Step 4: Run tests to verify pass**

```bash
bin/rails test test/models/project_test.rb -v
```

Expected: 3 tests, 3 passes.

**Step 5: Commit**

```bash
git add app/models/project.rb test/models/project_test.rb
git commit -m "feat: add Project model with validations"
```

---

### Task 3: Create the ProjectsController with public index and admin CRUD

**Objective:** Controller with `index` (public), and `new/create/edit/update/destroy` (admin-only).

**Files:**
- Create: `app/controllers/projects_controller.rb`
- Test: `test/controllers/projects_controller_test.rb`

**Step 1: Write failing controller tests**

Create `test/controllers/projects_controller_test.rb`:

```ruby
require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @project = projects(:abbey)
  end

  # Public access
  test "should get index without authentication" do
    get projects_url
    assert_response :success
  end

  # Admin-only access
  test "should not get new without authentication" do
    get new_project_url
    assert_response :redirect
  end

  test "should get new when authenticated" do
    sign_in_as(@user)
    get new_project_url
    assert_response :success
  end

  test "should create project when authenticated" do
    sign_in_as(@user)
    assert_difference("Project.count", 1) do
      post projects_url, params: {
        project: {
          name: "New Project",
          year: 2025,
          github_url: "https://github.com/capotej/new-project",
          license: "MIT",
          language: "Go",
          description: "A new project."
        }
      }
    end
    assert_redirected_to projects_url
  end

  test "should not create project with invalid data" do
    sign_in_as(@user)
    assert_no_difference("Project.count") do
      post projects_url, params: { project: { name: "" } }
    end
    assert_response :unprocessable_content
  end

  test "should get edit when authenticated" do
    sign_in_as(@user)
    get edit_project_url(@project)
    assert_response :success
  end

  test "should update project when authenticated" do
    sign_in_as(@user)
    patch project_url(@project), params: {
      project: { name: "Updated Abbey" }
    }
    assert_redirected_to projects_url
    assert_equal "Updated Abbey", @project.reload.name
  end

  test "should destroy project when authenticated" do
    sign_in_as(@user)
    assert_difference("Project.count", -1) do
      delete project_url(@project)
    end
    assert_redirected_to projects_url
  end

  private

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }
  end
end
```

**Step 2: Run tests to verify failure**

```bash
bin/rails test test/controllers/projects_controller_test.rb -v
```

Expected: FAIL — uninitialized constant or missing route.

**Step 3: Add projects route**

Edit `config/routes.rb`. Add the projects resource route and change the legacy redirect. The routes section should look like:

```ruby
  # pages
  resources :pages, except: :index, path: "p"

  # projects
  resources :projects, only: %i[ index new create edit update destroy ]
  get "/projects", to: "projects#index"  # redundant safety, resources already handles it
```

Remove the old `/projects` redirect line:
```ruby
  # DELETE this line:
  get "/projects", to: redirect("/p/projects")
```

**Step 4: Write the controller**

Create `app/controllers/projects_controller.rb`:

```ruby
class ProjectsController < ApplicationController
  allow_unauthenticated_access only: %i[ index ]

  def index
    @projects = Project.by_year
  end

  def new
    @project = Project.new
  end

  def create
    @project = Project.new(project_params)
    if @project.save
      redirect_to projects_url, notice: "Project was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @project = Project.find(params[:id])
  end

  def update
    @project = Project.find(params[:id])
    if @project.update(project_params)
      redirect_to projects_url, notice: "Project was successfully updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @project = Project.find(params[:id])
    @project.destroy
    redirect_to projects_url, notice: "Project was successfully destroyed."
  end

  private

  def project_params
    params.expect(project: [ :name, :year, :github_url, :license, :language, :description ])
  end
end
```

**Step 5: Run tests to verify pass**

```bash
bin/rails test test/controllers/projects_controller_test.rb -v
```

Expected: 9 tests, 9 passes.

**Step 6: Commit**

```bash
git add config/routes.rb app/controllers/projects_controller.rb test/controllers/projects_controller_test.rb
git commit -m "feat: add ProjectsController with public index and admin CRUD"
```

---

### Task 4: Create test fixture for projects

**Objective:** Add a YAML fixture so controller tests can load `projects(:abbey)`.

**Files:**
- Create: `test/fixtures/projects.yml`

**Step 1: Create the fixture file**

Create `test/fixtures/projects.yml`:

```yaml
abbey:
  name: Abbey
  year: 2024
  github_url: https://github.com/capotej/abbey
  license: MIT
  language: Ruby
  description: A personal blog built with Rails.

example:
  name: Example Project
  year: 2022
  github_url: https://github.com/capotej/example
  license: Apache-2.0
  language: Go
  description: An example Go project.
```

**Step 2: Run controller tests to verify they pass with fixture**

```bash
bin/rails test test/controllers/projects_controller_test.rb -v
```

Expected: 9 tests, 9 passes.

**Step 3: Commit**

```bash
git add test/fixtures/projects.yml
git commit -m "test: add project fixtures"
```

---

### Task 5: Create views — public index, form partial, new, edit

**Objective:** Build all the view templates for the projects feature.

**Files:**
- Create: `app/views/projects/index.html.erb`
- Create: `app/views/projects/_form.html.erb`
- Create: `app/views/projects/new.html.erb`
- Create: `app/views/projects/edit.html.erb`
- Create: `app/views/projects/_project.html.erb`

**Step 1: Create the project row partial**

Create `app/views/projects/_project.html.erb`:

```erb
<div class="border-b border-gray-200 dark:border-gray-700 py-6">
  <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2 mb-2">
    <h3 class="text-lg font-semibold text-gray-900 dark:text-white">
      <%= link_to project.name, project.github_url, target: "_blank", rel: "noopener noreferrer",
          class: "text-blue-600 dark:text-blue-400 hover:text-blue-800 dark:hover:text-blue-300" %>
    </h3>
    <div class="flex items-center gap-3 text-sm text-gray-500 dark:text-gray-400">
      <% if project.year.present? %>
        <span><%= project.year %></span>
      <% end %>
      <% if project.language.present? %>
        <span class="rounded-full bg-gray-100 dark:bg-gray-700 px-2 py-0.5 text-xs font-medium text-gray-700 dark:text-gray-300">
          <%= project.language %>
        </span>
      <% end %>
      <% if project.license.present? %>
        <span class="rounded-full bg-gray-100 dark:bg-gray-700 px-2 py-0.5 text-xs font-medium text-gray-700 dark:text-gray-300">
          <%= project.license %>
        </span>
      <% end %>
      <% if project.github_url.present? %>
        <%= link_to project.github_url, target: "_blank", rel: "noopener noreferrer",
            class: "text-gray-400 hover:text-gray-600 dark:hover:text-gray-300" do %>
          <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24" aria-hidden="true">
            <path fill-rule="evenodd" d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z" clip-rule="evenodd"/>
          </svg>
        <% end %>
      <% end %>
    </div>
  </div>
  <% if project.description.present? %>
    <p class="text-gray-600 dark:text-gray-300 text-sm">
      <%= project.description %>
    </p>
  <% end %>
  <% if authenticated? %>
    <div class="mt-2">
      <%= link_to "Edit", edit_project_path(project), class: "text-sm text-gray-400 hover:text-gray-600 dark:hover:text-gray-300" %>
    </div>
  <% end %>
</div>
```

**Step 2: Create the index view**

Create `app/views/projects/index.html.erb`:

```erb
<% content_for :title do %>
Projects | <%= Rails.application.config.site_name %>
<% end %>

<article class="max-w-2xl mx-auto">
  <header class="mb-8">
    <h1 class="text-3xl md:text-4xl font-bold text-gray-900 dark:text-white mb-4">Projects</h1>
  </header>

  <% if @projects.any? %>
    <div>
      <%= render @projects %>
    </div>
  <% else %>
    <p class="text-gray-500 dark:text-gray-400">No projects yet.</p>
  <% end %>
</article>
```

**Step 3: Create the form partial**

Create `app/views/projects/_form.html.erb`:

```erb
<%= form_with model: project, class: "space-y-6", url: project.persisted? ? project_url(project) : projects_url do |form| %>
  <%= render "shared/form_errors", object: project %>

  <div class="space-y-2">
    <%= form.label :name, class: "block text-sm font-medium text-gray-700 dark:text-gray-200" %>
    <%= form.text_field :name, class: "mt-1 block w-full rounded-md border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white shadow-xs focus:border-indigo-500 focus:ring-indigo-500" %>
  </div>

  <div class="space-y-2">
    <%= form.label :year, class: "block text-sm font-medium text-gray-700 dark:text-gray-200" %>
    <%= form.number_field :year, class: "mt-1 block w-full rounded-md border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white shadow-xs focus:border-indigo-500 focus:ring-indigo-500" %>
  </div>

  <div class="space-y-2">
    <%= form.label :github_url, class: "block text-sm font-medium text-gray-700 dark:text-gray-200" %>
    <%= form.text_field :github_url, class: "mt-1 block w-full rounded-md border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white shadow-xs focus:border-indigo-500 focus:ring-indigo-500" %>
  </div>

  <div class="space-y-2">
    <%= form.label :license, class: "block text-sm font-medium text-gray-700 dark:text-gray-200" %>
    <%= form.text_field :license, class: "mt-1 block w-full rounded-md border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white shadow-xs focus:border-indigo-500 focus:ring-indigo-500" %>
  </div>

  <div class="space-y-2">
    <%= form.label :language, class: "block text-sm font-medium text-gray-700 dark:text-gray-200" %>
    <%= form.text_field :language, class: "mt-1 block w-full rounded-md border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white shadow-xs focus:border-indigo-500 focus:ring-indigo-500" %>
  </div>

  <div class="space-y-2">
    <%= form.label :description, class: "block text-sm font-medium text-gray-700 dark:text-gray-200" %>
    <%= form.text_area :description, rows: 3, class: "mt-1 block w-full rounded-md border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white shadow-xs focus:border-indigo-500 focus:ring-indigo-500" %>
  </div>

  <div>
    <%= form.submit class: "rounded-md bg-indigo-600 px-4 py-2 text-sm font-semibold text-white shadow-xs hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600" %>
  </div>
<% end %>
```

**Step 4: Create the new view**

Create `app/views/projects/new.html.erb`:

```erb
<h1 class="text-3xl font-bold text-gray-900 dark:text-white mb-6">New Project</h1>
<%= render "form", project: @project %>
```

**Step 5: Create the edit view**

Create `app/views/projects/edit.html.erb`:

```erb
<h1 class="text-3xl font-bold text-gray-900 dark:text-white mb-6">Editing Project</h1>
<%= button_to "Delete", @project, method: :delete, data: { turbo_confirm: "Are you sure?" }, class: "rounded-md bg-indigo-600 px-4 py-2 text-sm font-semibold text-white shadow-xs hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 mb-6" %>
<%= render "form", project: @project %>
```

**Step 6: Run controller tests to verify views render**

```bash
bin/rails test test/controllers/projects_controller_test.rb -v
```

Expected: 9 tests, 9 passes.

**Step 7: Commit**

```bash
git add app/views/projects/
git commit -m "feat: add projects views — index, form, new, edit"
```

---

### Task 6: Update navigation links

**Objective:** Change the "Projects" nav link from `/p/projects` to `/projects`, and add a "New Project" link to the admin bar.

**Files:**
- Modify: `app/views/shared/_navigation.html.erb:20-21`
- Modify: `app/views/shared/_admin_navigation.html.erb:19-20`

**Step 1: Update the main navigation**

In `app/views/shared/_navigation.html.erb`, change the Projects link from `/p/projects` to `projects_path`:

```erb
      <%= link_to "Projects", projects_path,
          class: "#{current_page?(projects_path) ? 'text-blue-600 dark:text-blue-400 font-medium' : 'text-gray-600 dark:text-gray-300 hover:text-gray-900 dark:hover:text-white'} transition-colors" %>
```

**Step 2: Update the admin navigation**

In `app/views/shared/_admin_navigation.html.erb`, add a "New Project" link after the "New Link" link:

```erb
            <%= link_to new_project_path,
                class: "text-white hover:text-gray-300 transition-colors" do %>
                New Project
            <% end %>
```

**Step 3: Run all tests to verify nothing broke**

```bash
bin/rails test -v
```

Expected: all tests pass.

**Step 4: Commit**

```bash
git add app/views/shared/_navigation.html.erb app/views/shared/_admin_navigation.html.erb
git commit -m "feat: update nav links for projects resource"
```

---

### Task 7: Clean up old Projects page seed and fixture

**Objective:** Remove the old "Projects" Page seed, fixture entry, and legacy redirect, since `/projects` is now a dedicated route.

**Files:**
- Modify: `test/fixtures/pages.yml` (remove `projects` entry)
- Modify: `db/seeds/projects.rb` (delete or replace with Project seed data)
- Modify: `config/routes.rb` (remove `/projects` redirect — already done in Task 3)

**Step 1: Remove the projects fixture from pages.yml**

Edit `test/fixtures/pages.yml`, remove the `projects:` entry so it becomes:

```yaml
about:
  title: About
  slug: about
  markdown_body: This is the about page.

presentations:
  title: Presentations
  slug: presentations
  markdown_body: Conference talks and presentations.
```

**Step 2: Update the projects seed file**

Replace `db/seeds/projects.rb` with:

```ruby
begin
  Project.find_or_create_by!(name: "Abbey") do |p|
    p.year = 2024
    p.github_url = "https://github.com/capotej/abbey"
    p.license = "MIT"
    p.language = "Ruby"
    p.description = "A personal blog built with Rails."
  end
rescue ActiveRecord::RecordInvalid => e
  puts "Error importing project: #{e.message}"
end
```

**Step 3: Run all tests**

```bash
bin/rails test -v
```

Expected: all tests pass (nothing references the old projects Page fixture).

**Step 4: Commit**

```bash
git add test/fixtures/pages.yml db/seeds/projects.rb
git commit -m "refactor: remove old Projects page seed and fixture"
```

---

### Task 8: Verify the full flow in the browser

**Objective:** Smoke test the entire feature end-to-end.

**Step 1: Start the dev server**

```bash
cd ~/.hermes-openrouter/github-repos/abbey
bin/rails server
```

**Step 2: Verify the following in the browser**

1. Visit `/projects` — should show the projects index page (empty or with seeded data)
2. Visit `/projects/new` while logged out — should redirect to login
3. Log in as admin — should see "New Project" in the admin bar
4. Visit `/projects/new` — should show the form
5. Fill in the form and submit — should redirect to `/projects` with the new project listed
6. Edit a project — should update and redirect to `/projects`
7. Navigation "Projects" link should point to `/projects`
8. The old `/p/projects` page (the Page record) still works independently if it exists

**Step 3: Run the full test suite**

```bash
bin/rails test
```

Expected: all tests pass.

**Step 4: Commit any fixes if needed, then final commit**

```bash
git add -A
git commit -m "chore: final adjustments for projects feature"
```

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | Migration | `db/migrate/*_create_projects.rb` |
| 2 | Model + model tests | `app/models/project.rb`, `test/models/project_test.rb` |
| 3 | Controller + controller tests + routes | `app/controllers/projects_controller.rb`, `test/controllers/projects_controller_test.rb`, `config/routes.rb` |
| 4 | Test fixtures | `test/fixtures/projects.yml` |
| 5 | Views | `app/views/projects/**` |
| 6 | Navigation updates | `app/views/shared/_navigation.html.erb`, `app/views/shared/_admin_navigation.html.erb` |
| 7 | Cleanup old seed/fixture | `test/fixtures/pages.yml`, `db/seeds/projects.rb` |
| 8 | Smoke test | Manual verification |
