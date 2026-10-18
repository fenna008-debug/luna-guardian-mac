import unittest,tempfile,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'src'))
from extra_files import extract_extra
class ExtraFilesTests(unittest.TestCase):
 def test_html_excel_and_script_exclusion(self):
  with tempfile.TemporaryDirectory() as d:
   p=Path(d)/'school.xls';p.write_bytes('<table><tr><td>月曜</td><td>授業</td></tr></table>'.encode('cp932'))
   self.assertIn('月曜 | 授業',extract_extra(p)[0])
   p=Path(d)/'page.html';p.write_text('<script>secretScript()</script><p>正文</p>')
   self.assertIn('正文',extract_extra(p)[0]);self.assertNotIn('secretScript',extract_extra(p)[0])
 def test_xml_is_data_only(self):
  with tempfile.TemporaryDirectory() as d:
   p=Path(d)/'data.xml';p.write_text('<entry>hello</entry>');self.assertIn('hello',extract_extra(p)[0])
