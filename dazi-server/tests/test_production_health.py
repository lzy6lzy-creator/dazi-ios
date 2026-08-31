import json
import unittest

from scripts.check_production_health import EXPECTED_SERVICES, container_status


class ProductionHealthTests(unittest.TestCase):
    def rows(self):
        return [{"Service": name, "State": "running", "Health": "healthy"} for name in EXPECTED_SERVICES]

    def test_compose_json_array_and_json_lines_are_supported(self):
        rows = self.rows()
        for raw in (json.dumps(rows), "\n".join(json.dumps(row) for row in rows)):
            self.assertTrue(container_status(raw)[0])

    def test_missing_or_unhealthy_worker_is_detected(self):
        rows = [row for row in self.rows() if row["Service"] != "worker"]
        self.assertFalse(container_status(json.dumps(rows))[0])
        rows.append({"Service": "worker", "State": "running", "Health": "unhealthy"})
        self.assertFalse(container_status(json.dumps(rows))[0])


if __name__ == "__main__":
    unittest.main()
