Universal alert aggregator: mailrise accepts email (SMTP) and forwards it to
Apprise, which fans out to the configured notification targets.

Endpoints:

  mailrise (SMTP):  dockerint01:8025
  apprise (API/UI):  dockerint01:8000

mailrise routes everything to the apprise "apprise" config
(apprise://apprise:8000/apprise/?tags=all).

Notification targets (Discord, Matrix, etc.) are configured through the
apprise container itself and persisted to its ./apprise/config volume —
that's runtime state, not IaC, so it isn't committed here. Redeploying this
compose file from scratch means re-adding those targets via the apprise web
UI at :8000.

APPRISE_WORKER_COUNT is pinned to 2 (default is cpu_count*2+1, which spawned
25 gunicorn workers / ~450MB RSS on a 12-core host for what is a low-traffic
relay). Bump it if delivery ever lags under real load.

As of 2026-08-10, nothing in the stack actually sends mail to mailrise — it's
configured end-to-end but not yet adopted by any service as an alert sink.
