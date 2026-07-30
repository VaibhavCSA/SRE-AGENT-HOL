# Simple SRE Agent lab — no third-party repo, no preview APIs

This is a from-scratch replacement for the official `microsoft/sre-agent` starter-lab.
It skips every piece that broke on us: no `azd`, no Bicep, no calls to the SRE Agent's
preview data-plane API (`incidentPlayground/filters`) — that's specifically the endpoint
whose schema mismatch cost us hours. Instead:

- The app is 40 lines of Express, deployed with one GA-status CLI command
  (`az containerapp up`) that builds from source and creates everything it needs.
- The alert is created with `az monitor metrics alert create`, a stable GA command —
  the same metric/dimension (`Requests` / `StatusCodeCategory: 5xx`) that worked
  correctly for you in the official lab.
- The agent itself is created **through the sre.azure.com portal wizard**, not a
  script. According to Microsoft's own docs, a freshly created agent connects to
  Azure Monitor alerts by default — no manual "response plan"/filter step required
  for basic detection. That manual filter step is only needed for advanced routing
  (assigning specific named subagents), which we don't need for a simple demo.

## What you get

- `app.js` / `package.json` / `Dockerfile` — a tiny app called grubify-mini with:
  - `GET /orders` — returns 200 normally
  - `POST /admin/break` — flips an in-memory flag; from then on `/orders` returns 500
  - `POST /admin/fix` — flips it back (manual override, for testing)
  - Restarting the container app also clears the flag — so the agent's real
    remediation action (restart) is a genuine fix, not a fake demo button.
- `deploy.sh` — one script, three commands: create resource group, deploy app,
  create alert.

## 1. Deploy the app + alert

```bash
chmod +x deploy.sh
./deploy.sh rg-simple-sre-lab eastus2
```

Takes a few minutes. At the end it prints your app URL and Container App resource ID —
keep both handy.

## 2. Create the agent (portal, not script)

1. Go to **sre.azure.com** and sign in.
2. Select **Create agent**.
3. Fill in a name and region (use the same region as your app, e.g. `eastus2`).
4. Under **Managed resource groups**, select `rg-simple-sre-lab` (the one `deploy.sh`
   created).
5. Review the permissions screen — it'll auto-grant the agent's identity **Reader**
   on that resource group. Accept and select **Create**.
6. Wait 2-5 minutes for deployment to finish.

By default this is **read-only**: the agent can investigate, query logs/metrics, and
recommend a fix, but can't act on your infrastructure yet.

### Optional: let it actually restart the app

If you want the agent to genuinely execute the fix (not just recommend it), grant its
managed identity `Container Apps Contributor` on the resource group:

```bash
PRINCIPAL_ID=$(az identity list --resource-group <sre-agent-resource-group> \
  --query "[0].principalId" -o tsv)

az role assignment create \
  --assignee "$PRINCIPAL_ID" \
  --role "Container Apps Contributor" \
  --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/rg-simple-sre-lab"
```

(The SRE Agent resource group is separate from your app's resource group — the wizard
creates its own. Use `az group list -o table` to find it if unsure.)

## 3. Break it

```bash
curl -X POST https://<your-app-url>/admin/break
curl -i https://<your-app-url>/orders   # confirm HTTP 500
```

## 4. Investigate — two ways

**A. Wait for the autonomous alert** (5-min evaluation window + a few minutes
propagation — check sre.azure.com → Incidents).

**B. Or skip the wait — just ask directly** (works immediately, no dependency on
alert timing):

> The grubify-mini app's `/orders` endpoint is returning HTTP 500. Can you investigate
> the root cause and restart the container app to mitigate it?

## 5. Verify

```bash
curl -i https://<your-app-url>/orders   # should be 200 again after restart
```

## Cleanup

```bash
az group delete --name rg-simple-sre-lab --yes --no-wait
```
(Also delete the separate SRE Agent resource group created by the portal wizard.)
