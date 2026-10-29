import os
from pathlib import Path
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[2]


class ReleaseChangelog(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.repo = Path(self.temporary.name)
        self.git('init', '-q')
        self.git('config', 'user.name', 'Release Test')
        self.git('config', 'user.email', 'release-test@example.invalid')
        self.git('remote', 'add', 'origin', 'https://github.com/UzuCore/ROCKNIXK.git')
        self.git('commit', '-q', '--allow-empty', '-m', 'baseline')
        self.base = self.git('rev-parse', 'HEAD').strip()
        for message in ('SDM845: adopt official OpenABL support',
                        'SDM845: restore LED GUI and fix settings persistence'):
            self.git('commit', '-q', '--allow-empty', '-m', message)
        self.head = self.git('rev-parse', 'HEAD').strip()

    def tearDown(self):
        self.temporary.cleanup()

    def git(self, *args):
        return subprocess.check_output(['git', '-C', str(self.repo), *args], text=True)

    def generate(self, repository):
        env = os.environ.copy()
        for name in ('GH_TOKEN', 'GITHUB_TOKEN', 'GITHUB_REPOSITORY'):
            env.pop(name, None)
        if repository:
            env['GITHUB_REPOSITORY'] = repository
        return subprocess.check_output(['bash', str(REPO / '.github/scripts/generate-changelog.sh'),
            self.base + '..' + self.head], cwd=self.repo, env=env, text=True)

    def test_sdm845_changes_are_device_updates_with_fork_links(self):
        result = self.generate('UzuCore/ROCKNIXK')
        self.assertIn('Device Support', result)
        section = result.split('Device Support', 1)[1].split('\n### ', 1)[0]
        self.assertIn('SDM845: adopt official OpenABL support', section)
        self.assertIn('SDM845: restore LED GUI and fix settings persistence', section)
        self.assertIn('https://github.com/UzuCore/ROCKNIXK/commit/' + self.head, section)

    def test_local_generation_uses_origin_repository(self):
        self.assertIn('https://github.com/UzuCore/ROCKNIXK/commit/' + self.head,
                      self.generate(None))

    def test_repository_override_is_respected(self):
        self.assertIn('https://github.com/ROCKNIX/distribution/commit/' + self.head,
                      self.generate('ROCKNIX/distribution'))
