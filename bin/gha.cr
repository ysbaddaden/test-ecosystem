#! /usr/bin/env -S crystal i

DEFAULT_CRYSTAL = ENV.fetch("CRYSTAL", "nightly")
DEFAULT_SHARDS = ENV.fetch("SHARDS", "nightly")
DEFAULT_LINUX_RUNNER = ENV.fetch("LINUX_RUNNER", "ubuntu-latest")
DEFAULT_MACOS_RUNNER = ENV.fetch("MACOS_RUNNER", "macos-latest")
DEFAULT_WINDOWS_RUNNER = ENV.fetch("WINDOWS_RUNNER", "windows-latest")
MYSQL_VERSION = ENV.fetch("MYQSL_VERSION", "5.7")
POSTGRESQL_VERSION = ENV.fetch("POSTGRESQL_VERSION", "16")

require "../src/project"
require "../src/gha"

workflow_projects = Hash(String, Array(Project)).new

Dir.glob("./projects/*/*.yaml").each do |path|
  project = File.open(path) { |file| Project.from_yaml(file) }
  name = File.basename(File.dirname(path))
  hash = workflow_projects[name] ||= Array(Project).new
  hash << project
end

linux_steps = [] of Step
darwin_steps = [] of Step
windows_steps = [] of Step

format_steps = [] of Step
format_steps << GHA.install_crystal_step(DEFAULT_CRYSTAL, DEFAULT_SHARDS)

workflow_projects.each do |workflow_name, projects|
  linux_steps.clear
  darwin_steps.clear
  windows_steps.clear

  # SETUP
  {linux_steps, darwin_steps, windows_steps}.each do |steps|
    steps << GHA.checkout_step
    steps << GHA.install_crystal_step(DEFAULT_CRYSTAL, DEFAULT_SHARDS)

    if projects.any?(&.service?("mysql"))
      steps.concat GHA.mysql_service_steps(MYSQL_VERSION)
    end

    if projects.any?(&.service?("postgresql"))
      steps.concat GHA.postgresql_service_steps(POSTGRESQL_VERSION)
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

  linux_steps_count = linux_steps.size
  darwin_steps_count = darwin_steps.size
  windows_steps_count = windows_steps.size

  # GENERATE COMPOSITE ACTION FOR EACH PROJECT
  projects.each do |project|
    next unless steps = GHA.project_composite_action_steps(project)

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
          "steps" => steps,
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
      format_steps << GHA.clone_step(project, composite: false, test: "success() || failure()")
      format_steps << GHA.format_step(project.name, formats)
    end
  end

  # GENERATE THE WORKFLOWS
  Dir.mkdir_p(".github/workflows")

  # FIXME: don't create job if it has no steps

  print "write .github/workflows/#{workflow_name}.yml\n"
  File.open(".github/workflows/#{workflow_name}.yml", "w") do |file|
    workflow = {
      "name" => "#{workflow_name}",
      "on" => {
        "push" => nil,
        "pull_request" => nil,
        "workflow_dispatch" => {
          "inputs" => {
            "crystal" => { "type" => "string", "default" => DEFAULT_CRYSTAL },
            "shards" => { "type" => "string", "default" => DEFAULT_SHARDS },
          }
        }
      },
      "jobs" => Job.new,
    }

    jobs = workflow["jobs"].as(Job)

    unless linux_steps_count == linux_steps.size
      jobs["Linux"] = {
        "runs-on" => DEFAULT_LINUX_RUNNER,
        "steps" => linux_steps,
      }
    end

    unless darwin_steps_count == darwin_steps.size
      jobs["macOS"] = {
        "runs-on" => DEFAULT_MACOS_RUNNER,
        "steps" => darwin_steps,
      }
    end

    unless windows_steps_count == windows_steps.size
      jobs["Windows"] = {
        "runs-on" => DEFAULT_WINDOWS_RUNNER,
        "steps" => windows_steps,
      }
    end

    workflow.to_yaml(file)
  end
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
