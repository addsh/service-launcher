#!/usr/bin/env python3
"""Unit tests for generate.py. Run with: python3 -m unittest discover tests"""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import generate


def config_with(services, **overrides):
    base = {
        "sharedStackName": "launcher-shared",
        "domainName": "example.internal",
        "services": services,
    }
    base.update(overrides)
    return base


class PriorityAssignmentTests(unittest.TestCase):
    def test_priorities_start_at_one_per_exposure(self):
        config = config_with(
            [
                {"name": "a", "exposure": "public"},
                {"name": "b", "exposure": "internal"},
                {"name": "c", "exposure": "public"},
            ]
        )
        template = generate.generate(config)
        resources = template["Resources"]
        self.assertEqual(resources["AStack"]["Properties"]["Parameters"]["Priority"], 1)
        self.assertEqual(resources["BStack"]["Properties"]["Parameters"]["Priority"], 1)
        self.assertEqual(resources["CStack"]["Properties"]["Parameters"]["Priority"], 2)

    def test_default_exposure_is_public(self):
        config = config_with([{"name": "a"}])
        template = generate.generate(config)
        params = template["Resources"]["AStack"]["Properties"]["Parameters"]
        self.assertEqual(params["Exposure"], "public")
        self.assertEqual(params["Priority"], 1)


class DuplicateDetectionTests(unittest.TestCase):
    def test_duplicate_name_exits(self):
        config = config_with(
            [
                {"name": "orders-api"},
                {"name": "orders-api"},
            ]
        )
        with self.assertRaises(SystemExit):
            generate.validate(config)

    def test_unique_names_pass(self):
        config = config_with([{"name": "orders-api"}, {"name": "payments-api"}])
        generate.validate(config)  # should not raise

    def test_invalid_exposure_exits(self):
        config = config_with([{"name": "orders-api", "exposure": "private"}])
        with self.assertRaises(SystemExit):
            generate.validate(config)


class ListenerGuardTests(unittest.TestCase):
    def test_at_limit_passes(self):
        services = [{"name": f"svc-{i}"} for i in range(generate.MAX_SERVICES_PER_LISTENER)]
        config = config_with(services)
        generate.validate(config)  # should not raise

    def test_over_limit_exits(self):
        services = [{"name": f"svc-{i}"} for i in range(generate.MAX_SERVICES_PER_LISTENER + 1)]
        config = config_with(services)
        with self.assertRaises(SystemExit):
            generate.validate(config)

    def test_limit_is_per_listener_not_global(self):
        public = [{"name": f"pub-{i}"} for i in range(generate.MAX_SERVICES_PER_LISTENER)]
        internal = [{"name": f"int-{i}", "exposure": "internal"} for i in range(generate.MAX_SERVICES_PER_LISTENER)]
        config = config_with(public + internal)
        generate.validate(config)  # should not raise: each listener is at, not over, its own limit


if __name__ == "__main__":
    unittest.main()
