#! /usr/bin/env -S crystal i

require "yaml"

DEFAULT_CRYSTAL = ENV.fetch("DEFAULT_CRYSTAL", "nightly")
DEFAULT_SHARDS = ENV.fetch("DEFAULT_SHARDS", "nightly")
DEFAULT_LINUX_RUNNER = ENV.fetch("DEFAULT_LINUX_RUNNER", "ubuntu-latest")
DEFAULT_MACOS_RUNNER = ENV.fetch("DEFAULT_MACOS_RUNNER", "macos-latest")
DEFAULT_WINDOWS_RUNNER = ENV.fetch("DEFAULT_WINDOWS_RUNNER", "windows-latest")

alias Step = Hash(String, Hash(String, String) | String)

class Project
  include YAML::Serializable

  property name : String
  property source : String
  property systems : Array(String) = %w[darwin linux windows]
  property packages : Hash(String, Array(String)) = Hash(String, Array(String)).new
  property commands : String | Array(String) | Nil
  property formats : String | Array(String) | Nil

  def initialize(@name, @source, @systems, @packages, @commands, @formats)
  end

  def commands
    commands = @commands
    commands.is_a?(String) ? [commands] : commands
  end

  def formats
    formats = @formats
    formats.is_a?(String) ? [formats] : formats
  end

  def packages(system)
    @packages[system]?
  end
end

projects = Dir.glob("./projects/*.yaml").map do |path|
  File.open(path) { |file| Project.from_yaml(file) }
end

linux_steps = [] of Step
darwin_steps = [] of Step
windows_steps = [] of Step
format_steps = [] of Step

# INSTALL CRYSTAL + SHARDS
[linux_steps, darwin_steps, windows_steps, format_steps].each do |steps|
  steps << Step{
    "uses" => "crystal-lang/install-crystal@v1",
    "with" => {
      "crystal" => "${{ github.event.inputs.crystal || '#{DEFAULT_CRYSTAL}' }}",
      "shards" => "${{ github.event.inputs.shards || '#{DEFAULT_SHARDS}' }}",
    },
  }
end

# INSTALL SYSTEM DEPENDENCIES
unless (packages = projects.flat_map(&.packages("linux")).compact).empty?
  linux_steps << Step{
    "name" => "Install system dependencies",
    "run" => "sudo apt-get install --yes --no-install-recommends #{packages.join(' ')}",
  }
end

unless (packages = projects.flat_map(&.packages("darwin")).compact).empty?
  darwin_steps << Step{
    "name" => "Install system dependencies",
    "run" => "brew install #{packages.join(' ')}",
  }
end

# WINDOWS: INSTALL MSYS2 + SYSTEM DEPENDENCIES
windows_packages = projects.flat_map(&.packages("windows")).compact
windows_steps << Step{
  "name" => "Setup MSYS2",
  "uses" => "msys2/setup-msys2@v2",
  "with" => {
    "msystem" => "UCRT64",
    "install" => p(<<-TEXT)
      git
      make
      mingw-w64-ucrt-x86_64-pkgconf
      #{windows_packages.map { |name| "mingw-w64-ucrt-x86_64-#{name}" }.join('\n')}
      TEXT
  }
}
windows_steps << Step{
  "run" => "git config --global core.autocrlf false",
}

# GENERATE STEPS FOR EACH PROJECT
projects.each do |project|
  steps = [
    Step{
      "name" => "#{project.name}: checkout",
      "run" => "git clone #{project.source.inspect} #{project.name.inspect}",
    },
    Step{
      "name" => "#{project.name}: install dependencies",
      "run" => "shards install",
      "working-directory" => project.name,
    },
  ]

  project.commands.try(&.each do |command|
    steps << Step{
      "name" => "#{project.name}: #{command}",
      "run" => command,
      "working-directory" => project.name,
    }
  end)

  if project.systems.includes?("linux")
    linux_steps.concat(steps.map(&.dup))
  end

  if project.systems.includes?("darwin")
    darwin_steps.concat(steps.map(&.dup))
  end

  if project.systems.includes?("windows")
    steps.each do |step|
      step = step.dup
      step["shell"] = "msys2 {0}"
      windows_steps << step
    end
  end

  if formats = project.formats
    format_steps << Step{
      "name" => "#{project.name}",
      "run" => formats.join("\n"),
    }
  end
end

# GENERATE THE WORKFLOWS
Dir.mkdir_p(".github/workflows")

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
