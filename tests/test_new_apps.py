# SPDX-License-Identifier: GPL-2.0-or-later
import json
import os
os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')
import unittest
from pathlib import Path
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QJSEngine

APP = QGuiApplication.instance() or QGuiApplication([])


class NewAppsTest(unittest.TestCase):
    def setUp(self):
        self.engine = QJSEngine()
        source = Path(__file__).parents[1] / 'contents/ui/code/NewApps.js'
        self.engine.evaluate(source.read_text())

    def evaluate(self, code):
        result = self.engine.evaluate(code)
        self.assertFalse(result.isError(), result.toString())
        return result

    def test_initial_apps_are_not_new(self):
        self.evaluate('var state = scan(parse(""), ["a", "b"], 1000)')
        self.assertFalse(self.evaluate('isNew(state, "a", 1000)').toBool())
        self.assertTrue(self.evaluate('state.initialized').toBool())

    def test_only_additions_are_new(self):
        self.evaluate('var state = scan(parse(""), ["a"], 1000); state = scan(state, ["a", "b"], 2000)')
        self.assertTrue(self.evaluate('isNew(state, "b", 2000)').toBool())
        self.assertFalse(self.evaluate('isNew(state, "a", 2000)').toBool())
        self.evaluate('state = scan(state, ["b", "a"], 3000)')
        self.assertEqual(self.evaluate('state.recent.b').toInt(), 2000)

    def test_restart_and_launch_acknowledgement(self):
        self.evaluate('var state = scan(scan(parse(""), ["a"], 1000), ["a", "b"], 2000); state = parse(JSON.stringify(state))')
        self.assertTrue(self.evaluate('isNew(state, "b", 3000)').toBool())
        self.evaluate('state = launched(state, "b"); state = scan(state, ["a", "b"], 4000)')
        self.assertFalse(self.evaluate('isNew(state, "b", 4000)').toBool())

    def test_expiry_does_not_restart_badge(self):
        self.evaluate('var state = scan(scan(parse(""), ["a"], 1000), ["a", "b"], 2000); state = scan(state, ["a", "b"], 2000 + lifetime)')
        self.assertFalse(self.evaluate('isNew(state, "b", 2000 + lifetime)').toBool())

    def test_transient_empty_model_and_reinstall(self):
        self.evaluate('var state = scan(parse(""), ["a", "b"], 1000); state = scan(state, [], 2000)')
        self.assertEqual(self.evaluate('state.known.length').toInt(), 2)
        self.evaluate('state = scan(state, ["a"], 3000); state = scan(state, ["a", "b"], 4000)')
        self.assertTrue(self.evaluate('isNew(state, "b", 4000)').toBool())

    def test_malformed_state_creates_safe_baseline(self):
        for raw in ['invalid', '{}', '{"initialized":true,"known":[],"recent":[]}']:
            self.evaluate('var state = scan(parse(' + json.dumps(raw) + '), ["a"], 1000)')
            self.assertFalse(self.evaluate('isNew(state, "a", 1000)').toBool())


if __name__ == '__main__': unittest.main()
