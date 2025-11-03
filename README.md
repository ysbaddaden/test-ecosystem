# test-ecosystem

Each project generates a composite action that will be called from one of the
system job (Linux, macOS or Windows) and that will run individual steps (clone,
shards, build, spec, ...).

Steps to contribute:

- To modify a project, edit a `.yaml` file in the `projects/` directory.
- To add a project, create a `.yaml` file in the `projects/` directory.
- Run `make` to update the GitHub Actions and Workflows.
- Commit everything and push.

You can configure defaults using ENV variables. See `bin/gha.cr` for details.

## `projects/*.yaml`

- `name` (`string`): name of the shard or application;

- `source` (`string`): Git source to clone;

- `systems` (`array<string>`, optional): list of operating systems (defaults to
  linux, darwin and windows);

- `services` (`map<string,string>`, optional): list of services to setup
  (currently `mysql` or `postgresql`).

- `packages` (`map<string,string>`, optional): list of packages to install for
  each system (linux: apt-get, darwin: homebrew, windows: chocolatey).

- `patch` (`string`, optional): a custom patch to apply to the cloned
  repository (e.g. disable specs).

- `env` (`map<string,string>`, optional): list of packages to install for each
  system (linux: apt-get, darwin: homebrew, windows: chocolatey).

- `commands` (`array<string>`): list of commands to build and test the project;

- `formats` (`array<string>`): list of commands to format the project.

## TODO

- [ ] add arch to the system: `linux/x86_64`, `linux/aarch64`, `darwin/x86_64`,
  `windows/aarch64` (optional? `linux` or `darwin` would use the GHA default);
