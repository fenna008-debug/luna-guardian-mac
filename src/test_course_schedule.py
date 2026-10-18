import unittest,tempfile,json
from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
from course_schedule import tick,html_rows
class CourseTests(unittest.TestCase):
 def test_reminder_game_warning_and_holiday(self):
  with tempfile.TemporaryDirectory() as d:
   b=Path(d);(b/'course-schedule.json').write_text(json.dumps({'enabled':True,'courses':[dict(name='课程',room='405',start='10:40',end='12:10',dates=['2026-10-19'])]}))
   def now(t):return datetime.fromisoformat(t).replace(tzinfo=ZoneInfo('Asia/Tokyo'))
   self.assertEqual(tick(b,'',now('2026-10-19T10:30'))['kind'],'remind')
   self.assertEqual(tick(b,'',now('2026-10-19T10:31')), {})
   self.assertEqual(tick(b,'Safari',now('2026-10-19T11:00')), {})
   self.assertEqual(tick(b,'王者万象棋',now('2026-10-19T11:00'))['kind'],'warn')
   self.assertEqual(tick(b,'王者万象棋',now('2026-10-19T11:01')), {})
   self.assertEqual(tick(b,'王者万象棋',now('2026-10-20T11:00')), {})
 def test_japanese_html_excel(self):
  self.assertEqual(html_rows('<table><tr><td>月曜</td><td>日本語<br>405</td></tr></table>'.encode('cp932')),[['月曜','日本語\n405']])
