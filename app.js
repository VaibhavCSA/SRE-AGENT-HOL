const express = require('express');
const app = express();
const PORT = process.env.PORT || 8080;

// Bad-deploy crash loop scenario: when SIMULATE_CRASH=true, the process
// exits immediately on startup so the platform keeps restarting it,
// producing a real crash loop (fix = roll back to the prior revision).
if (process.env.SIMULATE_CRASH === 'true') {
    console.error('[FATAL] Simulated bad deploy: crashing on startup (SIMULATE_CRASH=true)');
    process.exit(1);
}


// In-memory "broken" state. This is the entire simulated bug:
// a flag that, once set, makes the main endpoint throw.
// Restarting the container clears it — this is deliberate, so that
// the SRE Agent's realistic remediation action (restart the revision)
// is a genuine, working fix rather than a fake demo action.
let broken = false;
let brokenAt = null;

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok' });
});

// Main "business" endpoint. Behaves normally until broken=true.
app.get('/orders', (req, res) => {
  if (broken) {
    console.error(`[ERROR] OrdersService: NullReferenceException — order cache not initialized (broken since ${brokenAt})`);
    return res.status(500).json({ error: 'Internal Server Error', detail: 'order cache not initialized' });
  }
  res.status(200).json({ orders: [{ id: 1, item: 'Coffee' }, { id: 2, item: 'Bagel' }] });
});

// Trigger endpoint — this is our "break the app" button.
// A real bug wouldn't have this, but it's the cleanest way to demo
// deterministically instead of flooding an endpoint and hoping a
// memory limit gets crossed in time for the demo.
app.post('/admin/break', (req, res) => {
  broken = true;
  brokenAt = new Date().toISOString();
  console.error(`[ERROR] OrdersService: cache initialization failed at startup — entering degraded mode`);
  res.status(200).json({ message: 'App is now broken. /orders will return 500.' });
});

app.post('/admin/fix', (req, res) => {
  broken = false;
  res.status(200).json({ message: 'App manually fixed.' });
});

app.get('/', (req, res) => {
  res.send(`<h1>Grubify-mini</h1><p>Status: ${broken ? 'DEGRADED' : 'healthy'}</p><p><a href="/orders">/orders</a></p>`);
});

app.listen(PORT, () => console.log(`Grubify-mini listening on ${PORT}`));
