# tf-plan-diff

Show what a Terraform plan changes, as JSON with one entry per changed value, with
sensitive values hidden by default.

```console
$ tf-plan-diff plan.tfplan "cloud run backend" env
{
  "module.cloud_run.google_cloud_run_v2_service.backend": {
    "actions": ["update"],
    "changes": {
      "template[0].containers[app].env[API_KEY]": {
        "value": { "before": { "sensitive": true }, "after": { "sensitive": true } }
      },
      "template[0].containers[app].env[LOG_LEVEL]": {
        "value": { "before": "info", "after": "debug" }
      },
      "template[0].containers[app].env[NEW_FLAG]": {
        "name": { "before": null, "after": "NEW_FLAG" },
        "value": { "before": null, "after": "on" }
      }
    }
  }
}
```

(Output reformatted to fit; the tool prints standard indented JSON.)

`terraform plan` is written for people reading the whole plan. This tool is for
answering a narrow question ("what changes in this service's env?") and for piping
into `jq`.

## Requirements

- bash
- [jq](https://jqlang.org/)
- `terraform`, only when reading a binary plan file

Tested with jq 1.8.1 and Terraform 1.15.8.

## Install

```sh
curl -fsSLo ~/.local/bin/tf-plan-diff https://raw.githubusercontent.com/shyam-anand/tf-plan-diff/main/tf-plan-diff
chmod +x ~/.local/bin/tf-plan-diff
```

Or clone the repo and put `tf-plan-diff` on your `PATH`.

## Usage

```
tf-plan-diff [flags] <plan> [resource] [attribute]
```

| Argument | Meaning |
|---|---|
| `plan` | A binary plan file (`terraform plan -out=...`), a JSON file from `terraform show -json`, or `-` for JSON on stdin. |
| `resource` | An exact resource address, or words that must all appear in the address, case-insensitive. `"cloud run backend"` matches `module.cloud_run.google_cloud_run_v2_service.backend`. Empty or omitted: every resource. |
| `attribute` | Keep only changes whose path contains this text, e.g. `env` or `image`. |

| Flag | Effect |
|---|---|
| `--show-sensitive-names` | Show sensitive `name` fields: list-item labels and `.name` values. |
| `--show-sensitive-values` | Show every other sensitive value. |
| `--show-sensitive` | Both. |

A binary plan file is read with `terraform show -json`, so run the command from the
initialized root module that produced the plan. JSON input works anywhere.

```sh
tf-plan-diff plan.tfplan                          # everything that changes
tf-plan-diff plan.tfplan "cloud run backend"      # one resource
tf-plan-diff plan.tfplan "" image                 # one attribute, every resource
terraform show -json plan.tfplan | tf-plan-diff - # from stdin
tf-plan-diff plan.tfplan | jq 'keys'              # just the changed addresses
```

If a resource or attribute filter matches nothing, the command lists the changed
resources on stderr and exits 1. A plan with no changes prints `{}`.

## Output

The top-level keys are resource addresses. Each one holds the plan's `actions` and a
`changes` object keyed by attribute path, each holding `{"before": ..., "after": ...}`.
Fields directly under a list item are grouped under that item's path instead, so
`env[LOG_LEVEL]` holds `{"value": {"before": ..., "after": ...}}`. Only values that
differ are listed; the `attribute` filter matches the full path, including the field. A
created resource lists every value it sets, and a deleted one lists every value it
had. Resources with no changes (`no-op`) are left out.

Values are the plan's own JSON values, except:

| Value | Meaning |
|---|---|
| `{"sensitive": true}` | Terraform marks the value as sensitive and the matching flag was not given. |
| `{"unknown": true}` | Known only after apply. If a whole block becomes unknown, each old value is listed with this `after`. |
| `null` | The value is null, or doesn't exist on that side (added or removed). |

The markers are objects, so they can't be confused with a real value: every real
value in `changes` is a string, number, boolean or `null`.

### List items are matched by name

When every item in a list is an object with a unique string `name` (Cloud Run env vars
and containers, Kubernetes containers and ports, and so on), items are matched by
`name` and labelled with it: `env[LOG_LEVEL]`. Adding or removing one item shows only
that item, instead of every item after it.

Other lists are matched by position: `allow[1]`. That includes lists where two items
share a name.

If the names themselves are sensitive and `--show-sensitive-names` is not given, items
are still matched by name, but each is labelled with its position in the new list
(`env[3]`). A removed item is labelled with its old position (`env[was 2]`).

## Sensitive values

Hiding follows Terraform's own sensitivity marks (`before_sensitive` and
`after_sensitive` in the plan JSON). A value Terraform doesn't mark is shown, exactly
as `terraform plan` would show it. For example, the `output` of a `terraform_data`
resource copies its `input`, but its old value isn't marked.

> **Warning:** the `--show-sensitive*` flags print secrets to your terminal. Don't use
> them in CI logs or anywhere the output is stored or shared.

The plan file and `terraform show -json` output contain sensitive values in plain
text whatever this tool does. Treat them as secrets.

## Limitations

- Only the `name` key is used to match list items.
- If any item's name is unknown until apply, the new list can't be matched by name,
  so every item in it shows as removed and re-added.
- Paths are joined as `a.b[0]`. An attribute key containing `.` or `[` makes a path
  ambiguous to read, though entries never collide.
- Resource drift (`resource_drift`) and output changes (`output_changes`) are not shown.

## Development

```sh
tests/run.sh           # run every case in tests/cases
tests/run.sh --update  # rewrite each case's expected output; review the diff before committing
```

Each case directory has `args` (one argument per line), an optional `stdin`, and
`expected` (stdout and stderr, then `exit=<code>`).

`tests/fixtures/synthetic.json` is written by hand. `tests/fixtures/terraform_data.json`
is a real plan from `tests/fixtures/terraform_data/main.tf`, which uses only Terraform's
built-in provider:

```sh
cd tests/fixtures/terraform_data
terraform init
TF_VAR_secret=s1 terraform apply -auto-approve -var v=1
TF_VAR_secret=s2 terraform plan -var v=2 -out=p.tfplan
terraform show -json p.tfplan | jq '{format_version, terraform_version, resource_changes}' > ../terraform_data.json
rm -rf .terraform* terraform.tfstate* p.tfplan
```

## License

MIT. See [LICENSE](LICENSE).
