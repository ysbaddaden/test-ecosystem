#! /usr/bin/env -S crystal i

DEFAULT_CRYSTAL = ENV.fetch("CRYSTAL", "nightly")
DEFAULT_SHARDS = ENV.fetch("SHARDS", "nightly")
DEFAULT_LINUX_RUNNER = ENV.fetch("LINUX_RUNNER", "ubuntu-latest")
DEFAULT_MACOS_RUNNER = ENV.fetch("MACOS_RUNNER", "macos-latest")
DEFAULT_WINDOWS_RUNNER = ENV.fetch("WINDOWS_RUNNER", "windows-latest")

require "../src/project"
require "../src/gha"

projects = Dir.glob("./projects/*.yaml").map do |path|
  File.open(path) { |file| Project.from_yaml(file) }
end

linux_steps = [] of Step
darwin_steps = [] of Step
windows_steps = [] of Step
format_steps = [] of Step

jobs = [
  linux_steps,
  darwin_steps,
  windows_steps,
]

# CHECKOUT
jobs.each do |steps|
  steps << Step{
    "uses" => "actions/checkout@v5",
  }
end

# INSTALL CRYSTAL + SHARDS
[*jobs, format_steps].each do |steps|
  steps << Step{
    "uses" => "crystal-lang/install-crystal@v1",
    "with" => {
      "crystal" => "${{ github.event.inputs.crystal || '#{DEFAULT_CRYSTAL}' }}",
      "shards" => "${{ github.event.inputs.shards || '#{DEFAULT_SHARDS}' }}",
    },
  }
end

# INSTALL SERVICES
jobs.each do |steps|
  if projects.any?(&.service?("mysql"))
    steps.concat GHA.mysql_service_steps
  end
  if projects.any?(&.service?("postgresql"))
    steps.concat GHA.postgresql_service_steps
  end
end

# INSTALL SYSTEM DEPENDENCIES
linux_steps.concat GHA.install_packages_steps(projects, "linux")
darwin_steps.concat GHA.install_packages_steps(projects, "darwin")
windows_steps.concat GHA.install_packages_steps(projects, "windows")

# SETUP SYSTEM
windows_steps << Step{
  "run" => "git config --global core.autocrlf false",
}

# GENERATE COMPOSITE ACTION FOR EACH PROJECT
projects.each do |project|
  Dir.mkdir_p(".github/actions/#{project.name}")

  print "write .github/actions/#{project.name}/action.yaml\n"
  File.open(".github/actions/#{project.name}/action.yml", "w") do |file|
    {
      "name" => project.name,
      "inputs" => {
        "shell" => { "type" => "string", "default" => "bash" },
      },
      "runs" => {
        "using" => "composite",
        "steps" => GHA.project_composite_action_steps(project),
      }
    }.to_yaml(file)
  end

  # CALL THE COMPOSITE ACTION
  if project.systems.includes?("linux")
    linux_steps << GHA.run_project_action_step(project, "linux")
  end
  if project.systems.includes?("darwin")
    darwin_steps << GHA.run_project_action_step(project, "darwin")
  end
  if project.systems.includes?("windows")
    windows_steps << GHA.run_project_action_step(project, "windows")
  end

  # ADD FORMAT STEP
  if formats = project.formats
    format_steps << GHA.clone_step(project, composite: false)
    format_steps << GHA.format_step(project.name, formats)
  end
end

# GENERATE THE WORKFLOWS
Dir.mkdir_p(".github/workflows")

print "write .github/workflows/projects.yml\n"
File.open(".github/workflows/projects.yml", "w") do |file|
  {
    "name" => "Projects",
    "on" => {
      "push" => nil,
      "pull_request" => nil,
      "workflow_dispatch" => {
        "inputs": {
          "crystal" => { "type" => "string", "default" => DEFAULT_CRYSTAL },
          "shards" => { "type" => "string", "default" => DEFAULT_SHARDS },
        }
      }
    },
    "jobs" => {
      "Linux" => {
        "runs-on" => DEFAULT_LINUX_RUNNER,
        "steps" => linux_steps,
      },
      "macOS" => {
        "runs-on" => DEFAULT_MACOS_RUNNER,
        "steps" => darwin_steps,
      },
      "Windows" => {
        "runs-on" => DEFAULT_WINDOWS_RUNNER,
        "steps" => windows_steps,
      },
    },
  }.to_yaml(file)
end

print "write .github/workflows/formats.yml\n"
File.open(".github/workflows/formats.yml", "w") do |file|
  {
    "name" => "Formats",
    "on" => {
      "push" => nil,
      "pull_request" => nil,
      "workflow_dispatch" => {
        "inputs": {
          "crystal" => { "type" => "string", "default" => DEFAULT_CRYSTAL },
        }
      }
    },
    "jobs" => {
      "Formats" => {
        "runs-on" => DEFAULT_LINUX_RUNNER,
        "steps" => format_steps,
      },
    },
  }.to_yaml(file)
end
