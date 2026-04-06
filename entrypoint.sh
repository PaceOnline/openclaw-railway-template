#!/bin/bash
set -euo pipefail

rm -rf /data/.openclaw /data/workspace /data/repos || true
mkdir -p /tmp/openclaw-removed

exec node <<'NODE'
const http = require("http");

const port = Number(process.env.PORT || 8080);
const goneBody = "OpenClaw has been removed.\n";
const healthBody = JSON.stringify({ ok: true, removed: true });

http
  .createServer((req, res) => {
    const url = req.url || "/";
    if (url === "/healthz" || url === "/setup/healthz") {
      res.statusCode = 200;
      res.setHeader("Content-Type", "application/json; charset=utf-8");
      res.end(healthBody);
      return;
    }

    res.statusCode = 410;
    res.setHeader("Content-Type", "text/plain; charset=utf-8");
    res.end(goneBody);
  })
  .listen(port, "0.0.0.0", () => {
    console.log(`OpenClaw removed server listening on ${port}`);
  });
NODE
