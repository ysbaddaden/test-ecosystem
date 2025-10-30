# test-ecosystem

Each project generates a composite action that will be called from one of the
system job (Linux, macOS or Windows) and that will run individual steps (clone,
shards, build, spec, ...).

Steps to contribute:

- To modify a project, edit a `.yaml` file in the `projects/` directory.
- To add a project, create a `.yaml` file in the `projects/` directory.
- Run `./bin/gha.cr` to update the GitHub Actions and Workflows.
- Commit everything and push.

## `projects/*.yaml`

- `name` (`string`): name of the shard or application;

- `source` (`string`): Git source to clone;

- `systems` (`array<string>`, optional): list of operating systems (defaults to
  linux, darwin and windows);

- `services` (`map<string,string>`, optional): list of services to setup
  (currently `mysql` or `postgresql`).

- `packages` (`map<string,string>`, optional): list of packages to install for
  each system (linux: apt-get, darwin: homebrew, windows: chocolatey).

- `env` (`map<string,string>`, optional): list of packages to install for each
  system (linux: apt-get, darwin: homebrew, windows: chocolatey).

- `commands` (`array<string>`): list of commands to build and test the project;

- `formats` (`array<string>`): list of commands to format the project.

## TODO

- [ ] group projects in sub-directories (e.g. `projects/db`,
  `projects/lucky_framework`, ...)
- [ ] create a workflow for each directory
