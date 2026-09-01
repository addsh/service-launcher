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


class DatabaseStackTests(unittest.TestCase):
    def test_database_false_creates_no_database_stack(self):
        config = config_with([{"name": "a"}])
        template = generate.generate(config)
        resources = template["Resources"]
        self.assertNotIn("ADatabaseStack", resources)
        params = resources["AStack"]["Properties"]["Parameters"]
        self.assertEqual(params["DatabaseEndpoint"], "")
        self.assertEqual(params["DatabaseSecretArn"], "")

    def test_database_true_creates_database_stack_and_wires_outputs(self):
        config = config_with([{"name": "a", "database": True}])
        template = generate.generate(config)
        resources = template["Resources"]
        self.assertIn("ADatabaseStack", resources)
        self.assertEqual(
            resources["ADatabaseStack"]["Properties"]["TemplateURL"],
            generate.SERVICE_DATABASE_TEMPLATE,
        )
        params = resources["AStack"]["Properties"]["Parameters"]
        self.assertEqual(
            params["DatabaseEndpoint"],
            {"Fn::GetAtt": "ADatabaseStack.Outputs.Endpoint"},
        )
        self.assertEqual(
            params["DatabaseSecretArn"],
            {"Fn::GetAtt": "ADatabaseStack.Outputs.SecretArn"},
        )


class CacheFieldTests(unittest.TestCase):
    def test_missing_cache_is_allowed(self):
        config = config_with([{"name": "orders-api"}])
        generate.validate(config)  # should not raise

    def test_cache_true_passes(self):
        config = config_with([{"name": "orders-api", "cache": True}])
        generate.validate(config)  # should not raise

    def test_non_bool_cache_exits(self):
        config = config_with([{"name": "orders-api", "cache": "yes"}])
        with self.assertRaises(SystemExit):
            generate.validate(config)


class CacheStackTests(unittest.TestCase):
    def test_cache_false_creates_no_cache_stack(self):
        config = config_with([{"name": "a"}])
        template = generate.generate(config)
        resources = template["Resources"]
        self.assertNotIn("ACacheStack", resources)
        params = resources["AStack"]["Properties"]["Parameters"]
        self.assertEqual(params["CacheEndpoint"], "")
        self.assertEqual(params["CachePort"], "")

    def test_cache_true_creates_cache_stack_and_wires_outputs(self):
        config = config_with([{"name": "a", "cache": True}])
        template = generate.generate(config)
        resources = template["Resources"]
        self.assertIn("ACacheStack", resources)
        self.assertEqual(
            resources["ACacheStack"]["Properties"]["TemplateURL"],
            generate.SERVICE_CACHE_TEMPLATE,
        )
        params = resources["AStack"]["Properties"]["Parameters"]
        self.assertEqual(
            params["CacheEndpoint"],
            {"Fn::GetAtt": "ACacheStack.Outputs.Endpoint"},
        )
        self.assertEqual(
            params["CachePort"],
            {"Fn::GetAtt": "ACacheStack.Outputs.Port"},
        )

    def test_compute_ecs_with_cache_wires_outputs(self):
        config = config_with([{"name": "a", "compute": "ecs", "cache": True}])
        template = generate.generate(config)
        params = template["Resources"]["AStack"]["Properties"]["Parameters"]
        self.assertEqual(
            params["CacheEndpoint"],
            {"Fn::GetAtt": "ACacheStack.Outputs.Endpoint"},
        )


class ComputeStackTests(unittest.TestCase):
    def test_compute_ec2_is_default_and_uses_service_template(self):
        config = config_with([{"name": "a"}])
        template = generate.generate(config)
        resources = template["Resources"]
        self.assertEqual(
            resources["AStack"]["Properties"]["TemplateURL"],
            generate.SERVICE_TEMPLATE,
        )

    def test_compute_ecs_uses_ecs_template(self):
        config = config_with([{"name": "a", "compute": "ecs"}])
        template = generate.generate(config)
        resources = template["Resources"]
        self.assertEqual(
            resources["AStack"]["Properties"]["TemplateURL"],
            generate.SERVICE_ECS_TEMPLATE,
        )
        params = resources["AStack"]["Properties"]["Parameters"]
        self.assertNotIn("InstanceType", params)
        self.assertNotIn("Repo", params)

    def test_compute_ecs_with_database_wires_outputs(self):
        config = config_with([{"name": "a", "compute": "ecs", "database": True}])
        template = generate.generate(config)
        params = template["Resources"]["AStack"]["Properties"]["Parameters"]
        self.assertEqual(
            params["DatabaseEndpoint"],
            {"Fn::GetAtt": "ADatabaseStack.Outputs.Endpoint"},
        )

    def test_invalid_compute_exits(self):
        config = config_with([{"name": "a", "compute": "lambda"}])
        with self.assertRaises(SystemExit):
            generate.validate(config)

    def test_compute_ecs_with_repo_exits(self):
        config = config_with(
            [{"name": "a", "compute": "ecs", "repo": "example-org/a"}],
            codeStarConnectionArn="arn:aws:codestar-connections:us-east-1:111111111111:connection/abc",
        )
        with self.assertRaises(SystemExit):
            generate.validate(config)


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

    def test_missing_repo_is_allowed(self):
        config = config_with([{"name": "orders-api"}])
        generate.validate(config)  # should not raise

    def test_valid_repo_passes(self):
        config = config_with(
            [{"name": "orders-api", "repo": "example-org/orders-api"}],
            codeStarConnectionArn="arn:aws:codestar-connections:us-east-1:111111111111:connection/abc",
        )
        generate.validate(config)  # should not raise

    def test_malformed_repo_exits(self):
        config = config_with([{"name": "orders-api", "repo": "not-a-repo"}])
        with self.assertRaises(SystemExit):
            generate.validate(config)

    def test_repo_without_connection_arn_exits(self):
        config = config_with([{"name": "orders-api", "repo": "example-org/orders-api"}])
        with self.assertRaises(SystemExit):
            generate.validate(config)

    def test_missing_database_is_allowed(self):
        config = config_with([{"name": "orders-api"}])
        generate.validate(config)  # should not raise

    def test_database_true_passes(self):
        config = config_with([{"name": "orders-api", "database": True}])
        generate.validate(config)  # should not raise

    def test_non_bool_database_exits(self):
        config = config_with([{"name": "orders-api", "database": "yes"}])
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
