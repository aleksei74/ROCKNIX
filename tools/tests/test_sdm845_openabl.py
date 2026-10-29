"""Host-side checks for the SDM845 standard boot metadata."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import xml.etree.ElementTree as ET

REPO = Path(os.environ.get('ROCKNIX_SOURCE', Path(__file__).resolve().parents[2]))


class OpenABLBLS(unittest.TestCase):
    def test_standard_make_target_has_no_overridden_recipe(self):
        result = subprocess.run(['make', '-n', 'SDM845'], cwd=REPO,
            capture_output=True, text=True, check=True)
        self.assertNotIn('overriding recipe', result.stderr)
        self.assertEqual(result.stdout.count('DEVICE=SDM845 ARCH=arm '), 1)
        self.assertEqual(result.stdout.count('DEVICE=SDM845 ARCH=aarch64 '), 1)

    def test_device_has_one_standard_boot_definition(self):
        config = ET.parse(REPO / 'projects/ROCKNIX/config.xml').getroot()
        definitions = config.findall('SDM845')
        self.assertEqual(len(definitions), 1, 'ambiguous SDM845 boot definitions')
        self.assertEqual(definitions[0].get('mkimage_options'), 'abl,bls,dtb')
        self.assertEqual([node.text for node in definitions[0].findall('file')],
            ['sdm845-ayn-odin-m0', 'sdm845-ayn-odin-m2'])

    def test_kernel_recipe_selects_the_official_sdm845_version(self):
        package = REPO / 'projects/ROCKNIX/packages/linux/package.mk'
        script = '''
get_pkg_directory() { :; }
get_pkg_variable() { :; }
kernel_config_path() { echo /dev/null; }
source "$1"
printf '%s' "$PKG_VERSION"
'''
        for device, expected in (('SDM845', '7.1.2'), ('SM8250', '7.2')):
            with self.subTest(device=device):
                result = subprocess.check_output(['bash', '-e', '-c', script,
                    'test', str(package)], env=os.environ | {'DEVICE': device,
                    'TARGET_ARCH': 'aarch64', 'PROJECT_DIR': str(REPO / 'projects'),
                    'PROJECT': 'ROCKNIX'}, text=True)
                self.assertEqual(result, expected)

    def test_bls_entry_boots_kernel_from_standard_labels(self):
        package = REPO / 'projects/ROCKNIX/packages/virtual/arm-efi/package.mk'
        for device in ('SDM845', 'SM8250'):
            with self.subTest(device=device), tempfile.TemporaryDirectory() as install:
                env = os.environ | {'DEVICE': device, 'INSTALL': install,
                    'DISTRONAME': 'ROCKNIX', 'OS_VERSION': '20261029',
                    'KERNEL_NAME': 'KERNEL', 'DISTRO_BOOTLABEL': 'ROCKNIX',
                    'DISTRO_DISKLABEL': 'STORAGE',
                    'EXTRA_CMDLINE': 'quiet rootwait console=tty0'}
                subprocess.run(['bash', '-eu', '-c', 'source "$1"; post_install',
                    'test', str(package)], env=env, check=True)
                entry = Path(install) / 'usr/share/bootloader/loader/entries/rocknix.conf'
                self.assertTrue(entry.is_file(), f'{device}: BLS entry was not installed')
                fields = dict(line.split(None, 1) for line in entry.read_text().splitlines())
                self.assertEqual(fields['linux'], '/KERNEL')
                self.assertEqual(fields['options'],
                    'boot=LABEL=ROCKNIX disk=LABEL=STORAGE quiet rootwait console=tty0')

    def test_sdm845_selects_openabl_without_carrier_packages(self):
        options = REPO / 'projects/ROCKNIX/devices/SDM845/options'
        script = 'get_kernel_make_extracmd() { :; }; source "$1"; printf "%s\\n" "$ADDITIONAL_PACKAGES"'
        packages = subprocess.check_output(['bash', '-eu', '-c', script,
            'test', str(options)], env=os.environ | {'TARGET_ARCH': 'aarch64'}, text=True).split()
        self.assertIn('openabl', packages)
        self.assertNotIn('u-boot', packages)
        self.assertNotIn('qbootctl', packages)


if __name__ == '__main__':
    unittest.main()
