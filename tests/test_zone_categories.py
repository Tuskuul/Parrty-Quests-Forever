import sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from zone_categories import enum_symbols,apply_categories,resolve_category,sort_labels
class Categories(unittest.TestCase):
 def test_enum_comments_and_negative_values(self):
  self.assertEqual(enum_symbols(' PALADIN = -141, -- class\n DUROTAR = 14,\n'),{'PALADIN':-141,'DUROTAR':14})
 def test_categories_and_priority(self):
  data={}
  source='''        [91316] = {
            [questKeys.zoneOrSort] = sortKeys.PALADIN,
        },
        [91858] = {
            [questKeys.zoneOrSort] = sortKeys.PALADIN,
        },
        [1] = {
            [questKeys.zoneOrSort] = zoneIDs.DUROTAR,
        },'''
  apply_categories(source,data,{'DUROTAR':14},{'PALADIN':-141})
  self.assertEqual(data,{91316:-141,91858:-141,1:14})
  apply_categories('        [1] = {\n[questKeys.zoneOrSort] = 25,\n}',data,{}, {})
  self.assertEqual(data[1],25)
 def test_unknown_symbol_preserves_existing(self):
  data={1:14};apply_categories('        [1] = {\n[questKeys.zoneOrSort] = sortKeys.MISSING,\n}',data,{}, {})
  self.assertEqual(data,{1:14});self.assertIsNone(resolve_category('random.PALADIN',{}, {'PALADIN':-141}))
 def test_class_label(self):
  self.assertEqual(sort_labels({'PALADIN':-141})[-141],'Paladin quests')
if __name__=='__main__': unittest.main()
