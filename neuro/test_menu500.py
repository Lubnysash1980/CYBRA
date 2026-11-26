import importlib.util
import tempfile
import unittest
from pathlib import Path

MODULE_PATH = Path(__file__).with_name("menu500.py")
spec = importlib.util.spec_from_file_location("menu500", MODULE_PATH)
menu500 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(menu500)

class Menu500Tests(unittest.TestCase):
    def test_exactly_500_entries(self):
        rows = menu500.catalog()
        self.assertEqual(len(rows), 500)

    def test_unique_ids_and_numbers(self):
        rows = menu500.catalog()
        self.assertEqual(len({x["id"] for x in rows}), 500)
        self.assertEqual({x["number"] for x in rows}, set(range(1, 501)))

    def test_all_entries_are_read_only(self):
        self.assertTrue(all(x["mode"] == "READ_ONLY" for x in menu500.catalog()))

    def test_ten_categories_with_fifty_items_each(self):
        rows = menu500.catalog()
        counts = {}
        for row in rows:
            counts[row["category"]] = counts.get(row["category"], 0) + 1
        self.assertEqual(len(counts), 10)
        self.assertEqual(set(counts.values()), {50})

    def test_catalog_has_no_execution_payload(self):
        for row in menu500.catalog():
            self.assertNotIn("command", row)
            self.assertNotIn("shell", row)
            self.assertNotIn("exec", row)

if __name__ == "__main__":
    unittest.main(verbosity=2)
