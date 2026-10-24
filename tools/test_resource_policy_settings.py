#!/usr/bin/env python3
"""Static agreement of the approved setting inventory and localization.

Actual setting domains, refresh and cold persistence are exercised by the
packaged tests.resource_policy_settings fixture, not inferred by this check.
"""
import configparser
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ResourcePolicySettingsTests(unittest.TestCase):
    def test_manifest_and_localization_are_complete(self):
        registry = (ROOT / 'scripts/runtime/budget-settings.lua').read_text()
        names = re.findall(r"name='(tc-[^']+)'", registry)
        policy = (ROOT / 'openspec/changes/replace-arbitrary-limits-with-resource-policy/limit-policy.md').read_text()
        required = set(re.findall(r'`(tc-[a-z-]+)`', policy))
        self.assertEqual(len(names), len(set(names)), 'duplicate setting name')
        self.assertEqual(set(names), required)
        locale = configparser.ConfigParser(interpolation=None)
        locale.read(ROOT / 'locale/en/settings.cfg')
        for section in ('mod-setting-name', 'mod-setting-description'):
            self.assertEqual(set(locale[section]), required)
            for name in names:
                self.assertTrue(locale[section][name].strip(), name)


if __name__ == '__main__':
    unittest.main()
