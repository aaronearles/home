# Linode Instance

Deploys a single Linode (Nanode, `us-west`, Rocky Linux 10) with SSH keys from your GitHub account and/or a list you provide.

## Setup

```bash
cp terraform.tfvars.sample terraform.tfvars   # loaded automatically, gitignored
```

Edit `terraform.tfvars`:

| Variable         | Required | Description                                                                 |
| ---------------- | -------- | --------------------------------------------------------------------------- |
| `linode_token`   | Yes      | API token from https://cloud.linode.com/profile/tokens (Linodes read/write) |
| `instance_label` | Yes      | Name of the instance in Linode                                              |
| `github_user`    | One of*  | Keys from `https://github.com/<user>.keys` are added to root's `authorized_keys` |
| `authorized_keys`| One of*  | List of SSH public keys, merged with any GitHub keys                        |
| `image`          | No       | Defaults to `linode/rocky10` ([image list](https://api.linode.com/v4/images)) |
| `tags`           | No       | Defaults to none                                                            |
| `stackscript_id` | No       | Optional StackScript to run on first boot                                   |

\* At least one SSH key is required, from `github_user`, `authorized_keys`, or both.

## Deploy

Use `tofu` or `terraform` (commands are identical):

```bash
tofu init
tofu plan
tofu apply
```

Then connect with `ssh root@$(tofu output -raw public_ip)`.

Tear down with `tofu destroy`.
