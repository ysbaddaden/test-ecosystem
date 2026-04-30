# test-ecosystem

This project manages an ecosystem test suite for the Crystal language. It
generates GitHub Actions workflows for various Crystal projects across different
operating systems (Linux, macOS, Windows).

## Project Definitions

Each project generates a composite action that will be called from one of the
system job and that will run individual steps (git clone, shards install) then
each command (e.g. shards build, crystal spec, ...).

Each project is a YAML file in the `projects` directory.

### File Format

- `name` (`string`): name of the shard or application;

- `source` (`string`): Git source to clone;

- `systems` (`array<string>`, optional): operating systems (defaults to
  linux, darwin and windows);

- `services` (`map<string,<array<string>>`, optional): services to setup
  (currently `mysql` or `postgresql`).

- `packages` (`map<string,string>`, optional): packages to install fordd
  each system (linux: apt-get, darwin: homebrew, windows: chocolatey).

- `patch` (`string`, optional): a custom patch to apply to the cloned
  repository (e.g. disable specs).

- `env` (`map<string,string>`, optional): environment variables

- `commands` (`array<string>`): commands to build and test the project;

- `formats` (`array<string>`): commands to format the project.

### Build

After any change, run `make` to regenerate the GitHub actions and worflows and
commit all the changes.

## TODO

- [ ] add an architecture to the system: `linux/x86_64`, `linux/aarch64`,
  `darwin/x86_64`, `windows/aarch64` (?) with default aliases (e.g. `linux` =>
  `linux/aarch64` (?)
