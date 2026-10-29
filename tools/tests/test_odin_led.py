import importlib.util
import fcntl
import subprocess
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET

directory = Path(__file__).resolve().parents[2] / 'projects/ROCKNIX/devices/SDM845/filesystem/usr/lib/odin'
sys.path.insert(0, str(directory))
import odin_hardware as hw
import odin_bootstrap as bootstrap


class BackendTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.saved = {name: getattr(hw, name) for name in ('SYS', 'MODEL', 'CONFIG', 'LOCK', 'LED_LOCK')}
        hw.SYS = self.root / 'sys'
        hw.MODEL = self.root / 'model'
        hw.MODEL.write_bytes(b'AYN Odin M2\0')
        hw.CONFIG = self.root / 'settings/system.cfg'
        hw.CONFIG.parent.mkdir()
        hw.CONFIG.write_text('# untouched\nsystem.language=ko_KR\nodin.led.left-stick=0\n')
        hw.LOCK = self.root / 'lock'
        hw.LED_LOCK = self.root / 'led.lock'
        for name, (node, number) in hw.LEDS.items():
            led = hw.SYS / 'class/leds' / ('blue:backlight-' + str(number))
            led.mkdir(parents=True)
            (led / 'brightness').write_text('0\n')
            (led / 'max_brightness').write_text('1\n')
            (led / 'trigger').write_text('[none] timer odin-scan\n')
            (led / 'scan_running').write_text('0\n')
            (led / 'delay_on').write_text('500\n')
            (led / 'delay_off').write_text('500\n')
        original_write = Path.write_text
        def sysfs_write(path, value, *args, **kwargs):
            if path.name == 'trigger' and path.is_relative_to(hw.SYS) and value.strip() in ('none', 'timer', 'odin-scan'):
                selected = value.strip()
                value = ' '.join('[' + item + ']' if item == selected else item
                                 for item in ('none', 'timer', 'odin-scan')) + '\n'
                original_write(path, value)
                paths = [hw.led_path(name) for name in hw.LEDS]
                scanning = all('[odin-scan]' in (led / 'trigger').read_text() for led in paths)
                for index, led in enumerate(paths):
                    original_write(led / 'scan_running', str(int(scanning)) + '\n')
                    if selected == 'odin-scan' or '[odin-scan]' in (led / 'trigger').read_text():
                        original_write(led / 'brightness', str(int(scanning and index == 0)) + '\n')
            return original_write(path, value, *args, **kwargs)
        self.trigger_patch = patch.object(Path, 'write_text', sysfs_write)
        self.trigger_patch.start()
        self.power = hw.SYS / 'class/leds/power-led'
        self.power.mkdir()
        (self.power / 'brightness').write_text('255\n')
        for name in ('policy0', 'policy4'):
            node = hw.SYS / 'devices/system/cpu/cpufreq' / name
            node.mkdir(parents=True)
            (node / 'scaling_governor').write_text('schedutil\n')
            (node / 'scaling_available_governors').write_text('performance powersave schedutil\n')
        self.gpu = hw.SYS / 'class/devfreq/5000000.gpu'
        self.gpu.mkdir(parents=True)
        (self.gpu / 'governor').write_text('simple_ondemand\n')
        (self.gpu / 'available_governors').write_text('performance powersave simple_ondemand\n')

    def tearDown(self):
        self.trigger_patch.stop()
        for name, value in self.saved.items():
            setattr(hw, name, value)
        self.temporary.cleanup()

    def test_official_m0_model_controls_leds(self):
        hw.MODEL.write_bytes(b'AYN Odin M0\0')
        result = hw.set_plain_leds({'left-stick': 1})
        self.assertTrue(result['leds']['left-stick']['on'])

    def test_missing_other_led_does_not_block_available_led(self):
        missing = hw.led_path('right-side')
        for child in missing.iterdir():
            child.unlink()
        missing.rmdir()
        result = hw.set_plain_leds({'left-stick': 1})
        self.assertTrue(result['leds']['left-stick']['on'])
        self.assertFalse(result['leds']['right-side']['available'])

    def test_restore_blink_without_timer_uses_steady_and_keeps_saved_effect(self):
        hw.CONFIG.write_text('odin.led.left-stick=1\nodin.led.left-stick.effect=slow\n')
        for name in hw.LEDS:
            (hw.led_path(name) / 'trigger').write_text('[none]\n')
        result = hw.restore_leds()
        self.assertTrue(result['leds']['left-stick']['on'])
        self.assertEqual(hw.read_config()['odin.led.left-stick.effect'], 'slow')

    def test_restore_scan_without_module_uses_steady_and_keeps_setting(self):
        hw.CONFIG.write_text('odin.led.group-effect=scan\n' + ''.join(
            'odin.led.' + name + '=1\n' for name in hw.LEDS))
        for name in hw.LEDS:
            (hw.led_path(name) / 'trigger').write_text('[none] timer\n')
        result = hw.restore_leds()
        self.assertTrue(all(item['on'] for item in result['leds'].values()))
        self.assertFalse(result['group_running'])
        self.assertEqual(hw.read_config()['odin.led.group-effect'], 'scan')

    def test_led_individual_save_and_power_untouched(self):
        result = hw.set_leds({'left-stick': 1})
        self.assertTrue(result['leds']['left-stick']['on'])
        self.assertFalse(result['leds']['right-stick']['on'])
        self.assertEqual(hw.read_config()['odin.led.left-stick'], '1')
        self.assertIn('# untouched', hw.CONFIG.read_text())
        self.assertEqual(hw.read_config()['system.language'], 'ko_KR')
        self.assertEqual((self.power / 'brightness').read_text(), '255\n')
        self.assertTrue(hw.LOCK.exists())

    def test_led_all_and_sleep_restore(self):
        hw.set_leds({name: 1 for name in hw.LEDS})
        hw.restore_leds(off=True)
        self.assertTrue(all(not item['on'] and item['saved'] for item in hw.led_status()['leds'].values()))
        hw.restore_leds()
        self.assertTrue(all(item['on'] for item in hw.led_status()['leds'].values()))

    def test_model_m1(self):
        hw.MODEL.write_bytes(b'AYN Odin\0')
        self.assertEqual(len(hw.led_status()['leds']), 4)

    def test_invalid_saved_led_defaults_off(self):
        hw.CONFIG.write_text('odin.led.left-stick=invalid\n')
        hw.restore_leds()
        self.assertFalse(hw.led_status()['leds']['left-stick']['on'])

    def test_boolean_led_setting_persists_numeric(self):
        hw.set_leds({'left-stick': True})
        self.assertEqual(hw.read_config()['odin.led.left-stick'], '1')

    def test_model_rejects_other_device(self):
        hw.MODEL.write_bytes(b'AYN Odin 2\0')
        with self.assertRaises(ValueError):
            hw.set_leds({'left-stick': 1})
        self.assertEqual((hw.led_path('left-stick') / 'brightness').read_text(), '0\n')

    def test_missing_led_and_preflight(self):
        led = hw.led_path('right-side')
        for file in led.iterdir():
            file.unlink()
        led.rmdir()
        self.assertFalse(hw.led_status()['leds']['right-side']['available'])
        with self.assertRaises(FileNotFoundError):
            hw.set_leds({'left-stick': 1, 'right-side': 1})
        self.assertFalse(hw.led_status()['leds']['left-stick']['on'])

    def test_dt_binding_identifies_renamed_led(self):
        path = hw.led_path('left-stick')
        renamed = path.with_name('custom-board-light')
        path.rename(renamed)
        node = self.root / 'dt/led-left-stick'
        node.mkdir(parents=True)
        (renamed / 'of_node').symlink_to(node, target_is_directory=True)
        self.assertEqual(hw.led_path('left-stick'), renamed)

    def test_rejects_non_gpio_fallback(self):
        (hw.led_path('left-stick') / 'max_brightness').write_text('255\n')
        with self.assertRaises(FileNotFoundError):
            hw.led_path('left-stick')

    def test_invalid_settings(self):
        for changes in ({'power-led': 1}, {'left-stick': 9}):
            with self.assertRaises(ValueError):
                hw.set_leds(changes)

    def test_led_save_failure_rolls_back(self):
        with patch.object(hw, 'save_config', side_effect=OSError('fixture failure')):
            with self.assertRaises(OSError):
                hw.set_leds({name: 1 for name in hw.LEDS})
        self.assertTrue(all(not item['on'] for item in hw.led_status()['leds'].values()))

    def test_led_write_failure_rolls_back(self):
        original = Path.write_text
        target = hw.led_path('right-stick') / 'brightness'
        failed = False
        def writer(path, value, *args, **kwargs):
            nonlocal failed
            if path == target and value == '1\n' and not failed:
                failed = True
                raise OSError('fixture write failure')
            return original(path, value, *args, **kwargs)
        with patch.object(Path, 'write_text', writer):
            with self.assertRaises(OSError):
                hw.set_leds({'left-stick': 1, 'right-stick': 1})
        self.assertTrue(all(not item['on'] for item in hw.led_status()['leds'].values()))

    def test_led_trigger_restore_on_failure(self):
        path = hw.led_path('left-stick')
        (path / 'trigger').write_text('none [timer]\n')
        with patch.object(hw, 'save_config', side_effect=OSError('fixture failure')):
            with self.assertRaises(OSError):
                hw.set_leds({'left-stick': 1})
        self.assertEqual(hw.led_trigger(path)[0], 'timer')

    def test_effect_presets_and_save(self):
        for effect, delays in hw.LED_EFFECTS.items():
            status = hw.set_effects({'left-stick': effect})['leds']['left-stick']
            self.assertEqual(status['effect'], effect)
            self.assertTrue(status['on'])
            self.assertFalse(status['color_supported'])
            self.assertEqual(status['color'], 'blue')
            self.assertEqual(hw.read_config()['odin.led.left-stick.effect'], effect)
            if delays:
                self.assertEqual(tuple(int((hw.led_path('left-stick') / key).read_text())
                                       for key in ('delay_on', 'delay_off')), delays)

    def test_all_effect_presets_and_off_on_preserve(self):
        for effect in hw.LED_EFFECTS:
            status = hw.set_effects({name: effect for name in hw.LEDS})['leds']
            self.assertTrue(all(item['on'] and item['effect'] == effect for item in status.values()))
            self.assertTrue(all(hw.read_config()['odin.led.' + name + '.effect'] == effect for name in hw.LEDS))
        hw.set_leds({name: 0 for name in hw.LEDS})
        self.assertTrue(all(not item['on'] and item['effect'] == 'fast' for item in hw.led_status()['leds'].values()))
        hw.set_leds({name: 1 for name in hw.LEDS})
        self.assertTrue(all(item['on'] and item['effect'] == 'fast' for item in hw.led_status()['leds'].values()))

    def test_all_effect_missing_timer_preflight(self):
        saved = hw.CONFIG.read_bytes()
        (hw.led_path('right-stick') / 'trigger').write_text('[none]\n')
        with self.assertRaises(ValueError):
            hw.set_effects({name: 'slow' for name in hw.LEDS})
        self.assertTrue(all(not item['on'] for item in hw.led_status()['leds'].values()))
        self.assertEqual(hw.CONFIG.read_bytes(), saved)

    def test_effect_off_restore_and_sleep(self):
        hw.set_effects({'left-stick': 'fast'})
        hw.set_leds({'left-stick': 0})
        self.assertFalse(hw.led_status()['leds']['left-stick']['on'])
        self.assertEqual(hw.led_status()['leds']['left-stick']['effect'], 'fast')
        hw.set_leds({'left-stick': 1})
        hw.restore_leds(off=True)
        hw.restore_leds()
        self.assertEqual(hw.led_status()['leds']['left-stick']['effect'], 'fast')

    def test_blink_off_phase_stays_enabled(self):
        hw.set_effects({'left-stick': 'slow'})
        (hw.led_path('left-stick') / 'brightness').write_text('0\n')
        self.assertTrue(hw.led_status()['leds']['left-stick']['on'])

    def test_effect_save_failure_restores_timer_delays(self):
        hw.set_effects({'left-stick': 'slow'})
        saved = hw.CONFIG.read_bytes()
        with patch.object(hw, 'save_config', side_effect=OSError('fixture failure')):
            with self.assertRaises(OSError):
                hw.set_effects({'left-stick': 'fast'})
        self.assertEqual(hw.led_status()['leds']['left-stick']['effect'], 'slow')
        self.assertEqual(hw.CONFIG.read_bytes(), saved)

    def test_effect_write_failure_restores_timer_delays(self):
        hw.set_effects({'left-stick': 'slow'})
        saved = hw.CONFIG.read_bytes()
        original = Path.write_text
        target = hw.led_path('left-stick') / 'delay_off'
        failed = False
        def writer(path, value, *args, **kwargs):
            nonlocal failed
            if path == target and value == '150\n' and not failed:
                failed = True
                raise OSError('fixture delay failure')
            return original(path, value, *args, **kwargs)
        with patch.object(Path, 'write_text', writer):
            with self.assertRaises(OSError):
                hw.set_effects({'left-stick': 'fast'})
        self.assertEqual(hw.led_status()['leds']['left-stick']['effect'], 'slow')
        self.assertEqual(hw.CONFIG.read_bytes(), saved)

    def test_effect_invalid_rejected_before_write(self):
        for changes in ({'left-stick': 'rainbow'}, {'power-led': 'fast'}):
            with self.assertRaises(ValueError):
                hw.set_effects(changes)
        self.assertFalse(hw.led_status()['leds']['left-stick']['on'])

    def test_effect_unsupported_preflight(self):
        (hw.led_path('left-stick') / 'trigger').write_text('[none]\n')
        with self.assertRaises(ValueError):
            hw.set_effects({'left-stick': 'slow'})
        self.assertEqual(hw.led_status()['leds']['left-stick']['effects'], ['steady'])
        self.assertFalse(hw.led_status()['leds']['left-stick']['on'])

    def test_invalid_saved_effect_defaults_steady(self):
        hw.CONFIG.write_text('odin.led.left-stick=1\nodin.led.left-stick.effect=rainbow\n')
        hw.restore_leds()
        self.assertEqual(hw.led_status()['leds']['left-stick']['effect'], 'steady')

    def animation_fixture(self):
        self.scanning = False
        def apply_patch(patcher):
            result = patcher.start()
            self.addCleanup(patcher.stop)
            return result
        apply_patch(patch.object(hw, 'scan_running', lambda: self.scanning))
        def start():
            self.scanning = True
            hw.apply_led(hw.led_path('left-side'), True, 'steady')
        def stop():
            self.scanning = False
            for name in hw.LEDS:
                hw.apply_led(hw.led_path(name), False, 'steady')
        self.animate_start = apply_patch(patch.object(hw, 'start_scan', side_effect=start))
        self.animate_stop = apply_patch(patch.object(hw, 'stop_scan', side_effect=stop))

    def test_scan_start_and_logical_state(self):
        self.animation_fixture()
        status = hw.set_scan()
        self.assertEqual(status['group_effect'], 'scan')
        self.assertTrue(status['group_running'])
        self.assertTrue(all(item['on'] and item['effect'] == 'scan' for item in status['leds'].values()))
        self.assertEqual(hw.read_config()['odin.led.group-effect'], 'scan')
        self.assertEqual(sum(int((hw.led_path(name) / 'brightness').read_text()) for name in hw.LEDS), 1)

    def test_scan_all_off_on_preserves_mode(self):
        self.animation_fixture()
        hw.set_scan()
        status = hw.set_leds({name: 0 for name in hw.LEDS})
        self.assertFalse(status['group_running'])
        self.assertEqual(status['group_effect'], 'scan')
        self.assertTrue(all(not item['on'] for item in status['leds'].values()))
        status = hw.set_leds({name: 1 for name in hw.LEDS})
        self.assertTrue(status['group_running'])

    def test_scan_sleep_restore_preserves_config(self):
        self.animation_fixture()
        hw.set_scan()
        saved = hw.CONFIG.read_bytes()
        hw.restore_leds(off=True)
        self.assertFalse(self.scanning)
        hw.restore_leds()
        self.assertTrue(self.scanning)
        self.assertEqual(hw.CONFIG.read_bytes(), saved)

    def test_scan_individual_toggle_exits_group(self):
        self.animation_fixture()
        hw.set_scan()
        status = hw.set_leds({'left-stick': 0})
        self.assertFalse(self.scanning)
        self.assertEqual(status['group_effect'], 'individual')
        self.assertFalse(status['leds']['left-stick']['on'])
        self.assertTrue(all(item['on'] for name, item in status['leds'].items() if name != 'left-stick'))

    def test_scan_preset_change_exits_group(self):
        self.animation_fixture()
        hw.set_scan()
        status = hw.set_effects({name: 'normal' for name in hw.LEDS})
        self.assertFalse(self.scanning)
        self.assertEqual(status['group_effect'], 'individual')
        self.assertTrue(all(item['effect'] == 'normal' for item in status['leds'].values()))

    def test_scan_save_failure_stops_new_service(self):
        self.animation_fixture()
        saved = hw.CONFIG.read_bytes()
        with patch.object(hw, 'save_config', side_effect=OSError('fixture save failure')):
            with self.assertRaises(OSError):
                hw.set_scan()
        self.assertFalse(self.scanning)
        self.assertEqual(hw.CONFIG.read_bytes(), saved)
        self.assertTrue(all(not item['on'] for item in hw.led_status()['leds'].values()))

    def test_scan_transition_failure_restores_service(self):
        self.animation_fixture()
        hw.set_scan()
        saved = hw.CONFIG.read_bytes()
        with patch.object(hw, 'save_config', side_effect=OSError('fixture save failure')):
            with self.assertRaises(OSError):
                hw.set_leds({'left-stick': 0})
        self.assertTrue(self.scanning)
        self.assertEqual(hw.CONFIG.read_bytes(), saved)

    def test_scan_start_failure_restores_hardware(self):
        self.animation_fixture()
        saved = hw.CONFIG.read_bytes()
        with patch.object(hw, 'start_scan', side_effect=RuntimeError('fixture start failure')):
            with self.assertRaises(RuntimeError):
                hw.set_scan()
        self.assertFalse(self.scanning)
        self.assertEqual(hw.CONFIG.read_bytes(), saved)
        self.assertTrue(all(not item['on'] for item in hw.led_status()['leds'].values()))

    def test_kernel_scan_without_worker(self):
        status = hw.set_scan()
        self.assertTrue(status['scan_available'])
        self.assertTrue(hw.scan_running())
        self.assertTrue(all(hw.led_trigger(hw.led_path(name))[0] == 'odin-scan' for name in hw.LEDS))
        hw.stop_scan()
        self.assertFalse(hw.scan_running())
        self.assertTrue(all(hw.led_trigger(hw.led_path(name))[0] == 'none' for name in hw.LEDS))

    def test_plain_all_on_clears_kernel_scan(self):
        hw.set_scan()
        status = hw.set_plain_leds({name: 1 for name in hw.LEDS})
        self.assertFalse(status['group_running'])
        self.assertEqual(status['group_effect'], 'individual')
        self.assertTrue(all(item['on'] and item['effect'] == 'steady' for item in status['leds'].values()))
        self.assertTrue(all(hw.led_trigger(hw.led_path(name))[0] == 'none' for name in hw.LEDS))

    def test_plain_individual_off_on_clears_blink(self):
        hw.set_effects({'left-stick': 'fast', 'right-stick': 'slow'})
        hw.set_plain_leds({'left-stick': 0})
        status = hw.set_plain_leds({'left-stick': 1})
        self.assertEqual(status['leds']['left-stick']['effect'], 'steady')
        self.assertEqual(status['leds']['right-stick']['effect'], 'slow')
        self.assertEqual(hw.read_config()['odin.led.left-stick.effect'], 'steady')

    def test_plain_all_on_clears_mixed_effects(self):
        hw.set_effects(dict(zip(hw.LEDS, hw.LED_EFFECTS)))
        hw.set_plain_leds({name: 0 for name in hw.LEDS})
        status = hw.set_plain_leds({name: 1 for name in hw.LEDS})
        self.assertTrue(all(item['effect'] == 'steady' for item in status['leds'].values()))

    def test_plain_individual_on_exits_scan(self):
        hw.set_scan()
        hw.set_plain_leds({'left-stick': 0})
        status = hw.set_plain_leds({'left-stick': 1})
        self.assertFalse(hw.scan_running())
        self.assertEqual(status['leds']['left-stick']['effect'], 'steady')
        self.assertTrue(all(item['on'] for item in status['leds'].values()))

    def test_plain_on_save_failure_restores_blink(self):
        hw.set_effects({'left-stick': 'slow'})
        saved = hw.CONFIG.read_bytes()
        with patch.object(hw, 'save_config', side_effect=OSError('fixture failure')):
            with self.assertRaises(OSError):
                hw.set_plain_leds({'left-stick': 1})
        self.assertEqual(hw.CONFIG.read_bytes(), saved)
        self.assertEqual(hw.led_status()['leds']['left-stick']['effect'], 'slow')

    def test_boot_restore_keeps_explicit_effect(self):
        hw.set_effects({'left-stick': 'fast'})
        hw.restore_leds(off=True)
        hw.restore_leds()
        self.assertEqual(hw.led_status()['leds']['left-stick']['effect'], 'fast')

    def test_kernel_scan_missing_trigger_preflight(self):
        before = hw.CONFIG.read_bytes()
        (hw.led_path('right-stick') / 'trigger').write_text('[none] timer\n')
        self.assertFalse(hw.scan_available())
        with self.assertRaises(ValueError):
            hw.set_scan()
        self.assertEqual(hw.CONFIG.read_bytes(), before)
        self.assertTrue(all(not item['on'] for item in hw.led_status()['leds'].values()))

    def test_kernel_partial_group_stops(self):
        (hw.led_path('left-stick') / 'trigger').write_text('odin-scan\n')
        self.assertFalse(hw.scan_running())
        hw.set_leds({'right-stick': 1})
        self.assertTrue(all(hw.led_trigger(hw.led_path(name))[0] == 'none' for name in hw.LEDS))

    def test_kernel_attach_failure_detaches_partial_group(self):
        before = hw.CONFIG.read_bytes()
        original = Path.write_text
        target = hw.led_path('right-stick') / 'trigger'
        def writer(path, value, *args, **kwargs):
            if path == target and value == 'odin-scan\n':
                raise OSError('fixture attach failure')
            return original(path, value, *args, **kwargs)
        with patch.object(Path, 'write_text', writer):
            with self.assertRaises(OSError):
                hw.set_scan()
        self.assertEqual(hw.CONFIG.read_bytes(), before)
        self.assertTrue(all(hw.led_trigger(hw.led_path(name))[0] == 'none' for name in hw.LEDS))

    def test_config_deduplicates_and_atomic_failure(self):
        hw.CONFIG.write_text('x=0\nx=2\ny=3\n')
        hw.save_config({'x': 1})
        self.assertEqual(hw.CONFIG.read_text().count('x='), 1)
        previous = hw.CONFIG.read_bytes()
        with patch.object(os, 'replace', side_effect=OSError('fixture failure')):
            with self.assertRaises(OSError):
                hw.save_config({'x': 7})
        self.assertEqual(hw.CONFIG.read_bytes(), previous)
        self.assertTrue(hw.LOCK.exists())
        self.assertEqual(len(list(hw.CONFIG.parent.iterdir())), 1)

    def test_gui_change_enables_custom_led_mode_after_legacy_off(self):
        hw.CONFIG.write_text('led.color=off\n')
        hw.set_plain_leds({'left-stick': 1})
        self.assertEqual(hw.read_config()['led.color'], 'battery')

    def test_suspend_uses_temporary_off_without_changing_led_mode(self):
        repo = Path(__file__).resolve().parents[2]
        hook = repo / 'projects/ROCKNIX/packages/hardware/quirks/platforms/SDM845/sleep.d/pre/001-led'
        profile = self.root / 'profile'
        source_functions = repo / 'projects/ROCKNIX/packages/rocknix/profile.d/001-functions'
        functions = self.root / 'functions'
        functions.write_text(source_functions.read_text().replace('/storage/.config/system/configs', str(hw.CONFIG.parent)))
        profile.write_text('source "' + str(functions) + '"\nJ_CONF="' + str(hw.CONFIG) +
                           '"\nJ_CONF_LOCK="' + str(hw.LOCK) + '"\n')
        binary_dir = self.root / 'bin'
        binary_dir.mkdir()
        native = repo / 'projects/ROCKNIX/packages/hardware/quirks/platforms/SDM845/bin/ledcontrol'
        executable = binary_dir / 'ledcontrol'
        executable.write_text(native.read_text().replace('. /etc/profile.d/001-functions',
                              '. "$LED_TEST_PROFILE"').replace('/sys/class/leds', str(hw.SYS / 'class/leds')))
        executable.chmod(0o755)
        backend = binary_dir / 'odin-ledctl'
        backend.write_text('#!/bin/sh\nexit 0\n')
        backend.chmod(0o755)
        script = self.root / 'sleep-hook'
        script.write_text(hook.read_text().replace('. /etc/profile', '. "$LED_TEST_PROFILE"').replace(
                          '/usr/bin/ledcontrol', 'ledcontrol'))
        hw.CONFIG.write_text('led.color=battery\nodin.led.left-stick=1\n')
        subprocess.run(['bash', str(script)], env=os.environ | {
            'PATH': str(binary_dir) + ':' + os.environ['PATH'], 'LED_TEST_PROFILE': str(profile)}, check=True)
        self.assertEqual(hw.read_config()['led.color'], 'battery')
        self.assertEqual(hw.read_config()['sleep.led.color'], 'battery')

    def test_native_low_battery_flash_returns_control_to_led_backend(self):
        repo = Path(__file__).resolve().parents[2]
        scripts = repo / 'projects/ROCKNIX/packages/rocknix'
        profile = self.root / 'profile'
        profile.write_text('source "' + str(scripts / 'profile.d/001-functions') + '"\n'
                           'J_CONF="' + str(hw.CONFIG) + '"\n'
                           'J_CONF_LOCK="' + str(hw.LOCK) + '"\n')
        binary_dir = self.root / 'bin'
        binary_dir.mkdir()
        log = self.root / 'calls'
        ledctl = binary_dir / 'odin-ledctl'
        ledctl.write_text('#!/bin/sh\nprintf "%s\\n" "$1" >>"$LED_TEST_LOG"\n')
        ledctl.chmod(0o755)
        native = repo / 'projects/ROCKNIX/packages/hardware/quirks/platforms/SDM845/bin/ledcontrol'
        ledcontrol = binary_dir / 'ledcontrol'
        ledcontrol.write_text(native.read_text().replace('. /etc/profile.d/001-functions',
                              '. "$LED_TEST_PROFILE"').replace('/sys/class/leds', str(hw.SYS / 'class/leds')))
        ledcontrol.chmod(0o755)
        flash = self.root / 'led_flash'
        flash.write_text((scripts / 'sources/scripts/led_flash').read_text().replace(
                         '. /etc/profile', '. "$LED_TEST_PROFILE"'))
        hw.CONFIG.write_text('led.color=default\nodin.led.left-stick=1\nodin.led.left-stick.effect=slow\n')
        env = os.environ | {'PATH': str(binary_dir) + ':' + os.environ['PATH'],
                            'LED_TEST_PROFILE': str(profile), 'LED_TEST_LOG': str(log)}
        subprocess.run(['bash', str(flash)], env=env, check=True, capture_output=True, text=True)
        calls = log.read_text().splitlines() if log.exists() else []
        self.assertEqual(calls, ['restore', 'off'] * 3 + ['restore'])
        self.assertEqual(hw.read_config()['odin.led.left-stick.effect'], 'slow')

    def test_config_after_system_sort_settings_reuses_unlocked_inode(self):
        functions = Path(__file__).resolve().parents[2] / 'projects/ROCKNIX/packages/rocknix/profile.d/001-functions'
        subprocess.run(['bash', '-c', 'source "$1"; J_CONF="$2"; J_CONF_LOCK="$3"; sort_settings',
                        'test', str(functions), str(hw.CONFIG), str(hw.LOCK)], check=True)
        self.assertTrue(hw.LOCK.exists())
        inode = hw.LOCK.stat().st_ino
        hw.set_plain_leds({'left-stick': 1})
        self.assertTrue(hw.led_status()['leds']['left-stick']['on'])
        self.assertEqual(hw.read_config()['odin.led.left-stick'], '1')
        self.assertEqual(hw.LOCK.stat().st_ino, inode)

    def test_config_respects_foreign_lock(self):
        previous = hw.CONFIG.read_bytes()
        with hw.LOCK.open('a') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            with patch.object(hw.time, 'monotonic', side_effect=[0, 6]):
                with self.assertRaisesRegex(RuntimeError, 'settings_busy'):
                    hw.save_config({'x': 1})
            self.assertEqual(hw.CONFIG.read_bytes(), previous)
        hw.save_config({'x': 1})
        self.assertEqual(hw.read_config()['x'], '1')

    def test_performance_profiles_and_persistence(self):
        self.assertEqual(hw.performance_status()['profile'], 'balanced')
        for profile, (cpu, gpu) in hw.PROFILES.items():
            status = hw.set_performance(profile)
            self.assertEqual(status['profile'], profile)
            self.assertEqual(status['cpu'], [cpu, cpu])
            self.assertEqual(status['gpu'], gpu)
            self.assertEqual(hw.read_config()['system.odin.performance'], profile)

    def test_performance_runtime_only(self):
        original = hw.CONFIG.read_bytes()
        hw.set_performance('performance', persist=False)
        self.assertEqual(hw.CONFIG.read_bytes(), original)

    def test_performance_save_failure_rolls_back(self):
        with patch.object(hw, 'save_config', side_effect=OSError('fixture failure')):
            with self.assertRaises(OSError):
                hw.set_performance('performance')
        self.assertEqual(hw.performance_status()['profile'], 'balanced')

    def test_unsupported_profile_preflight(self):
        (self.gpu / 'available_governors').write_text('simple_ondemand\n')
        with self.assertRaises(ValueError):
            hw.set_performance('performance')
        self.assertEqual(hw.performance_status()['profile'], 'balanced')

    def test_performance_write_failure_rolls_back(self):
        original = Path.write_text
        target = self.gpu / 'governor'
        def writer(path, value, *args, **kwargs):
            if path == target and value == 'performance\n':
                raise OSError('fixture write failure')
            return original(path, value, *args, **kwargs)
        with patch.object(Path, 'write_text', writer):
            with self.assertRaises(OSError):
                hw.set_performance('performance')
        self.assertEqual(hw.performance_status()['profile'], 'balanced')

    def test_missing_cpu_policy_preflight(self):
        (hw.SYS / 'devices/system/cpu/cpufreq/policy4/scaling_governor').unlink()
        with self.assertRaises(FileNotFoundError):
            hw.set_performance('performance')

    def test_tools_registration_preserves_custom_entries(self):
        self.register_fixture(b'<gameList><game><path>./Custom.sh</path><name>Custom</name></game></gameList>')
        self.assertEqual(len(ET.parse(bootstrap.TARGET / 'gamelist.xml').getroot().findall('game')), 2)
        before = (bootstrap.TARGET / 'gamelist.xml').stat().st_mtime_ns
        bootstrap.register_tools()
        self.assertEqual((bootstrap.TARGET / 'gamelist.xml').stat().st_mtime_ns, before)
        self.assertTrue((bootstrap.TARGET / bootstrap.NAME).stat().st_mode & 0o111)

    def test_malformed_tools_backup_and_recover(self):
        original = b'<gameList><game><path>./Custom.sh</path><name>Custom</name></game></wrong>'
        self.register_fixture(original)
        backups = list(bootstrap.TARGET.glob('gamelist.xml.before-odin-*'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_bytes(), original)
        paths = [game.findtext('path') for game in ET.parse(bootstrap.TARGET / 'gamelist.xml').getroot().findall('game')]
        self.assertIn('./Custom.sh', paths)
        self.assertIn('./Odin LED Settings.sh', paths)

    def test_wrong_xml_root_is_repaired(self):
        self.register_fixture(b'<wrong/>')
        self.assertEqual(ET.parse(bootstrap.TARGET / 'gamelist.xml').getroot().tag, 'gameList')

    def test_malformed_default_and_storage_tools_are_recovered(self):
        source, target = self.root / 'source', self.root / 'target'
        source.mkdir()
        target.mkdir()
        (source / bootstrap.NAME).write_text('#!/bin/sh\nexit 0\n')
        (source / 'gamelist.xml').write_text('<gameList><game><path>./Default.sh</path></game></wrong>')
        (target / 'gamelist.xml').write_text('<gameList><game><path>./Custom.sh</path></game></wrong>')
        with patch.object(bootstrap, 'SOURCE', source), patch.object(bootstrap, 'TARGET', target):
            bootstrap.register_tools()
        paths = [game.findtext('path') for game in ET.parse(target / 'gamelist.xml').getroot().findall('game')]
        self.assertEqual(set(paths), {'./Default.sh', './Custom.sh', './' + bootstrap.NAME})
        self.assertEqual(len(list(target.glob('gamelist.xml.before-odin-*'))), 1)

    def test_wrong_default_root_is_recovered(self):
        source, target = self.root / 'source', self.root / 'target'
        source.mkdir()
        target.mkdir()
        (source / bootstrap.NAME).write_text('#!/bin/sh\nexit 0\n')
        (source / 'gamelist.xml').write_text('<wrong><game><path>./Default.sh</path></game></wrong>')
        with patch.object(bootstrap, 'SOURCE', source), patch.object(bootstrap, 'TARGET', target):
            bootstrap.register_tools()
        parsed = ET.parse(target / 'gamelist.xml').getroot()
        self.assertEqual(parsed.tag, 'gameList')
        self.assertEqual(len(parsed.findall('game')), 2)

    def register_fixture(self, content):
        source, target = self.root / 'source', self.root / 'target'
        source.mkdir()
        target.mkdir()
        (source / bootstrap.NAME).write_text('#!/bin/sh\nexec /usr/bin/odin-led-gui\n')
        (source / 'gamelist.xml').write_text('<gameList/>')
        (target / 'gamelist.xml').write_bytes(content)
        originals = bootstrap.SOURCE, bootstrap.TARGET
        bootstrap.SOURCE, bootstrap.TARGET = source, target
        self.addCleanup(lambda: setattr(bootstrap, 'SOURCE', originals[0]))
        self.addCleanup(lambda: setattr(bootstrap, 'TARGET', originals[1]))
        bootstrap.register_tools()


if __name__ == '__main__':
    unittest.main(verbosity=2)
