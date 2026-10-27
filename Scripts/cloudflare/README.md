# Cloudflare reconciliation on Pleiades

The merged `~/ygg-compose` checkout is read-only. Cloudflare audit commands
read its Compose files and query Cloudflare directly. The live audit does not
write to Cloudflare, Git, or Terraform.

## One-time Python environment

Create a virtual environment outside the GitOps checkout:

```bash
python3 -m venv ~/cloudflare/.venv
~/cloudflare/.venv/bin/python -m pip install \
  -r ~/ygg-compose/Scripts/cloudflare/requirements.txt
```

If that directory is removed, repeat these commands. No persistent Cloudflare
configuration is stored in the virtual environment.

## Run

```bash
cd ~/ygg-compose
~/cloudflare/.venv/bin/python -m unittest discover \
  -s Scripts/cloudflare -p 'test_cloudflare_*.py'

# The following uses the existing deployment-side credentials.
# Never print, log, or commit their values.
set -a
source terraform/cloudflare/cloudflare.env
set +a

~/cloudflare/.venv/bin/python Scripts/cloudflare/cloudflare-live.py
```

`cloudflare-live.py` requires `CLOUDFLARE_API_TOKEN` in the environment. Its
current implementation only calls Cloudflare's GET endpoints. Terraform-based
commands and their state are retained temporarily for rollback but should not
run automatic changes during the transition.
