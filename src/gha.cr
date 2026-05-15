alias Step = Hash(String, Hash(String, String) | String)
alias Job = Hash(String, String | Array(Step))

module GHA
  def self.install_crystal_step(crystal, shards)
    Step{
      "uses" => "crystal-lang/install-crystal@v1",
      "with" => {
        "crystal" => "${{ github.event.inputs.crystal || '#{crystal}' }}",
        "shards" => "${{ github.event.inputs.shards || '#{shards}' }}",
      },
    }
  end

  def self.checkout_step
    Step{
      "uses" => "actions/checkout@v5",
    }
  end

  def self.mysql_service_steps(version)
    [Step{
      "uses" => "shogo82148/actions-setup-mysql@v1",
      "with" => {
        "mysql-version" => version,
      }
    }]
  end

  def self.postgresql_service_steps(version)
    [Step{
      "uses" => "ikalnytskyi/action-setup-postgres@v8",
      "with" => {
        "postgres-version" => version
      }
    }]
  end

  def self.redis_service_steps
    [Step{
      "uses" => "pustovitDmytro/redis-github-action@v1.0.1",
    }]
  end

  def self.install_packages_steps(projects, system)
    packages = projects.flat_map(&.packages(system)).compact.uniq
    return [] of Step if packages.empty?

    case system
    when "linux"
      [Step{
        "name" => "Install system dependencies",
        "run" => "sudo apt-get install --quiet --yes --no-install-recommends #{packages.join(' ')}",
      }]
    when "darwin"
      [Step{
        "name" => "Install system dependencies",
        "run" => "brew install #{packages.join(' ')}",
      }]
    when "windows"
      [Step{
        "name" => "Install system dependencies",
        "run" => "choco install --no-progress #{packages.join(' ')}",
      }]
    else
      raise "fatal: unsupported system #{system}"
    end
  end

  def self.clone_step(project, composite = true, test = nil)
    step = Step{
      "run" => "git clone #{project.source.inspect} #{project.name.inspect}",
    }
    step["if"] = test if test
    step["shell"] = "${{ inputs.shell }}" if composite
    step
  end

  def self.shards_install_step(project)
    step = Step{
      "run" => "shards install --skip-postinstall --skip-executables",
      "working-directory" => project.name,
      "shell" => "${{ inputs.shell }}",
    }
    if h = project.env
      env = Hash(String, String).new
      h.each { |k, v| env[k] = v }
      step["env"] = env
    end
    step
  end

  def self.project_composite_action_steps(project)
    return unless commands = project.commands
    return if commands.empty?

    steps = [
      GHA.clone_step(project),
      GHA.shards_install_step(project),
    ]

    if project.patch
      steps << Step{
        "run" => "git apply $GITHUB_ACTION_PATH/project.patch",
        "working-directory" => project.name,
        "shell" => "${{ inputs.shell }}",
      }
    end

    if h = project.env
      env = Hash(String, String).new
      h.each { |k, v| env[k] = v }
    end

    commands.each do |command|
      step = Step{
        "run" => command,
        "working-directory" => project.name,
        "shell" => "${{ inputs.shell }}",
      }
      step["env"] = env.dup if env
      steps << step
    end

    steps
  end

  def self.run_project_action_step(project, system)
    step = Step{
      "if" => "success() || failure()",
      "name" => "Project: #{project.name}",
      "uses" => "./.github/actions/#{project.name}",
    }
    # step["with"] = { "shell" => "pwsh" } if system == "windows"
    step
  end

  def self.format_step(name, formats)
    Step{
      "if" => "success() || failure()",
      "name" => name,
      "run" => formats.join("\n"),
      "working-directory" => name,
    }
  end
end
