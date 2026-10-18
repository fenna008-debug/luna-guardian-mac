import unittest
from unittest.mock import patch
import computer_status as status
import worker

class ComputerStatusTests(unittest.TestCase):
    def test_natural_requests(self):
        for text in ['你看看电脑状况','帮我检查一下电脑状态','电脑怎么这么卡','看看内存占用','Mac现在怎么样']:
            self.assertTrue(status.requested(text), text)
        for text in ['你好','今天看什么书','我喜欢电脑游戏','天气如何']:
            self.assertFalse(status.requested(text), text)
    def test_status_bypasses_language_model(self):
        with patch.object(status,'report',return_value='real snapshot') as snapshot:
            self.assertEqual(worker.respond('帮我看看电脑状况'),'real snapshot')
            snapshot.assert_called_once()
    def test_missing_values_are_not_fabricated(self):
        with patch.object(status,'command',return_value=''),patch.object(status.shutil,'disk_usage',side_effect=OSError):
            reply=status.report()
        self.assertIn('CPU：未取得读数',reply)
        self.assertIn('内存压力：未取得读数',reply)
        self.assertNotIn('CPU：0',reply)
    def test_only_fixed_readonly_commands_and_no_path_disclosure(self):
        def value(args,*a):
            if args[0]=='/bin/ps':return '12.0 102400 /private/name/My App'
            return ''
        with patch.object(status,'command',side_effect=value) as run:
            reply=status.report()
        self.assertNotIn('/private',reply)
        self.assertIn('My App',reply)
        self.assertTrue(all(call.args[0][0] in ['/usr/bin/top','/usr/sbin/sysctl','/usr/bin/pmset','/bin/ps'] for call in run.call_args_list))
    def test_high_pressure_is_reported(self):
        def value(args,*a):
            if args[-1]=='kern.memorystatus_vm_pressure_level':return '4'
            if args[0]=='/usr/bin/top':return 'CPU usage: 70.0% user, 20.0% sys'
            return ''
        with patch.object(status,'command',side_effect=value):reply=status.report()
        self.assertIn('CPU：90.0%',reply)
        self.assertIn('内存压力：严重',reply)
        self.assertIn('本次发现：',reply)
