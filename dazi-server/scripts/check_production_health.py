"""Host-side health checks, compatible with the production host's Python 3.6."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import urllib.request


EXPECTED_SERVICES = {"api", "worker", "db", "redis", "web"}


def command(arguments):
    result = subprocess.run(arguments, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=15)
    result.check_returncode()
    return result.stdout.decode("utf-8")


def container_status(raw):
    try:
        parsed = json.loads(raw)
        rows = parsed if isinstance(parsed, list) else [parsed]
    except ValueError:
        rows = [json.loads(line) for line in raw.splitlines() if line.strip()]
    services = {row["Service"]: row for row in rows}
    states = {}
    for name in sorted(EXPECTED_SERVICES):
        row = services.get(name, {})
        running = row.get("State") == "running"
        healthy = row.get("Health") == "healthy" if name != "web" else True
        states[name] = "ok" if running and healthy else "unhealthy"
    return all(state == "ok" for state in states.values()), states


def collect_health(app_dir):
    compose = ["docker", "compose", "--project-directory", app_dir, "-f", app_dir + "/docker-compose.prod.yml"]
    checks = {}

    def run_check(name, operation):
        try:
            healthy, detail = operation()
            checks[name] = {"ok": bool(healthy), "detail": detail}
        except Exception as error:
            checks[name] = {"ok": False, "detail": type(error).__name__}

    def readiness(url):
        with urllib.request.urlopen(url, timeout=5) as response:
            payload = json.load(response)
        return payload.get("status") == "ready", payload

    def disk():
        usage = os.statvfs(app_dir)
        free_percent = 100.0 * usage.f_bavail / usage.f_blocks
        return free_percent >= 15, {"free_percent": round(free_percent, 1)}

    def memory():
        values = {}
        with open("/proc/meminfo") as stream:
            for line in stream:
                key, value = line.split(":", 1)
                values[key] = int(value.strip().split()[0])
        percent = 100.0 * values["MemAvailable"] / values["MemTotal"]
        return percent >= 8, {"available_percent": round(percent, 1)}

    def database_connections():
        payload = json.loads(command(compose + ["exec", "-T", "db", "psql", "-U", "dazi", "-d", "dazi", "-Atc",
            "SELECT json_build_object('used', count(*), 'limit', current_setting('max_connections')::int) FROM pg_stat_activity"]))
        return payload["used"] < payload["limit"] * 0.8, payload

    def recent_errors():
        raw = command(compose + ["logs", "--no-color", "--since", "5m", "--tail", "200", "api", "worker"])
        count = sum(bool(re.search(r"\bERROR\b|Traceback \(most recent call last\)", line)) for line in raw.splitlines())
        return count == 0, {"error_lines_last_5m": count}

    run_check("local_readiness", lambda: readiness("http://localhost:8000/ready"))
    run_check("public_readiness", lambda: readiness("https://idabuda.com/ready"))
    run_check("containers", lambda: container_status(command(compose + ["ps", "--all", "--format", "json"])))
    run_check("disk", disk)
    run_check("memory", memory)
    run_check("database_connections", database_connections)
    run_check("recent_errors", recent_errors)
    return {
        "checked_at": datetime.now(timezone.utc).isoformat(),
        "status": "ok" if all(item["ok"] for item in checks.values()) else "degraded",
        "checks": checks,
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--app-dir", default="/opt/dazi-server")
    parser.add_argument("--output")
    arguments = parser.parse_args()
    report = collect_health(arguments.app_dir)
    serialized = json.dumps(report, ensure_ascii=False, indent=2)
    if arguments.output:
        target = Path(arguments.output)
        target.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile("w", dir=str(target.parent), delete=False, encoding="utf-8") as stream:
            stream.write(serialized)
            temporary = stream.name
        os.replace(temporary, str(target))
    print(serialized)
    raise SystemExit(0 if report["status"] == "ok" else 1)
