require "yaml"

class Project
  include YAML::Serializable

  property name : String
  property source : String
  property systems : Array(String) = %w[darwin linux windows]
  property packages : Hash(String, Array(String)) = Hash(String, Array(String)).new
  property env : Hash(String, String) | Nil
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

