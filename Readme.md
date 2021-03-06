This tool builds a report of users with more than N PRs in some public GitHub repositories. This is usefull if you are running a Hacktoberfest challenge.

## Usage

flag | description
--- | ---
`--org` | if specified, will get the list of repositories for this organization.  this flag will override --repo.
`--repo` | if specified, will include PRs from this repo. must be in the form of "organization/repo". this flag can be specified multiple times. this flag will be overriden by --org
`--since` | only take PRs since this ISO 8601 date
`--before` | only take PRs before this ISO 8601 date
`--labels` | only take PRs with all of these labels defined (comma seperated)
`--minpr` | find users with at least this many PRs
`--noclean` | specify this boolean flag (no value requires) to keep the intermediate artifacts generated by the scripts
`--token` | if specified, will use the token as a bearer token to authenticate with GitHub. Authenticating increases throttling limits. Can be a GitHub personal access token or a JWT token
`--workdir` | if specified, will skip downloading from GitHub API, and will generate the report against an existing directory that was previously populated with data by running this tool and the --noclean flag.

## Examples
```bash
hacktober-script.sh --repo aquasecurity/kube-hunter --repo aquasecurity/trivy --since "2019-10-01T00:00:00Z" --before "2019-10-31T00:00:00Z" --minpr 3

hacktober-script.sh --org aquasecurity --since "2019-10-01T00:00:00Z" --before "2019-10-31T23:59:59Z" --minpr 3 --noclean --token a1b2c3

hacktober-script.sh --workdir "/path/to/dir" --since "2019-10-01T00:00:00Z" --before "2019-10-31T23:59:59Z" --minpr 3 --noclean
```

The [examples](./examples) directory contains more on how to further investigate the artifacts created by running the script with the `--noclean` option.

## Requirements
bash 4+, jq, gnu find (gfind on mac), gnu sed (gsed on mac), curl, tee
