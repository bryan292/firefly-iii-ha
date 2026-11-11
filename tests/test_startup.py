"""Integration regressions against the real Firefly image (Docker required).

Run: docker build -t firefly-ha:test . && python3 -m unittest discover -s tests -v
"""
import json
import os
import re
from pathlib import Path
import subprocess
import tempfile
import time
import unittest
import uuid

IMAGE = os.environ.get('TEST_IMAGE', 'firefly-ha:test')


def docker(*args):
    return subprocess.check_output(['docker', *args], text=True, stderr=subprocess.STDOUT)


class StartupTests(unittest.TestCase):
    def setUp(self):
        self.data = tempfile.TemporaryDirectory()
        self.addCleanup(self.data.cleanup)
        # Containers write as root. Restore host ownership before tempfile cleanup
        # on native Linux (Docker Desktop masks this difference on macOS).
        self.addCleanup(lambda: self.data_command('chown', '-R',
                                                 f'{os.getuid()}:{os.getgid()}', '/data'))
        self.name = 'firefly-test-' + uuid.uuid4().hex[:12]
        self.addCleanup(lambda: docker('rm', '-f', self.name))

    def data_command(self, *args):
        return docker('run', '--rm', '--entrypoint', args[0],
                      '-v', self.data.name + ':/data', IMAGE, *args[1:])

    def start(self, options=None, env=None, expect_failure=False, mysql=False):
        Path(self.data.name, 'options.json').write_text(json.dumps(options or {}))
        if env is not None:
            root = Path(self.data.name, 'firefly')
            root.mkdir(exist_ok=True)
            (root / '.env').write_text(env)
        docker('run', '-d', '--name', self.name, '-v', self.data.name + ':/data', IMAGE)
        self.wait_ready(expect_failure, mysql)

    def wait_ready(self, expect_failure=False, mysql=False):
        for _ in range(90):
            logs = docker('logs', self.name)
            state = json.loads(docker('inspect', self.name))[0]['State']
            if not state['Running']:
                if expect_failure:
                    self.assertNotEqual(state['ExitCode'], 0)
                    return
                self.fail(logs)
            if mysql and 'Executing command: php artisan migrate' in logs:
                return  # Inspect real Laravel config before unavailable DB retries.
            if 'Startup sequence completed' in logs:
                self.assertFalse(expect_failure, logs)
                self.assertNotIn('Migrations failed', logs)
                self.assertNotIn('Command failed', logs)
                return
            time.sleep(1)
        self.fail(docker('logs', self.name))

    def php(self, script):
        return docker('exec', self.name, 'php', '-r', script).strip()

    def config(self):
        return json.loads(self.php('echo json_encode(require "bootstrap/cache/config.php");'))

    def test_sqlite_key_and_data_survive_restart(self):
        self.start({'generate_app_key': True})
        config = self.config()
        self.assertEqual(config['database']['default'], 'sqlite')
        self.assertEqual(config['database']['connections']['sqlite']['database'], '/data/firefly/database.sqlite')
        self.assertEqual(config['filesystems']['disks']['upload']['root'], '/data/firefly/storage/upload')
        # Check the web SAPI too: storagePath() bypasses the cached config and
        # must resolve the same directory as the CLI for Passport signing keys.
        self.php('file_put_contents("public/ha-storage.php", '
                 + json.dumps('<?php require "../vendor/autoload.php"; '
                              '$app=require "../bootstrap/app.php"; '
                              'echo $app->storagePath();').replace('$', '\\$') + ');')
        web_storage = docker('exec', self.name, 'curl', '-fsS',
                             'http://127.0.0.1:8080/ha-storage.php')
        self.assertEqual(web_storage.strip(), '/data/firefly/storage')
        self.php('file_put_contents("/data/firefly/storage/upload/upgrade-persistence.txt", "preserved");')
        oauth_key = self.php('echo hash_file("sha256", "/data/firefly/storage/oauth-private.key");')
        key = config['app']['key']
        self.assertTrue(key.startswith('base64:'))
        self.assertNotIn(key, docker('logs', self.name))
        self.php('$db=new PDO("sqlite:/data/firefly/database.sqlite");'
                 '$db->exec("CREATE TABLE regression (value TEXT)");'
                 '$db->exec("INSERT INTO regression VALUES (\'persisted\')");')
        # Recreate the container to exercise an upgrade, not just a process restart.
        docker('rm', '-f', self.name)
        self.start({'generate_app_key': False})
        self.assertEqual(self.config()['app']['key'], key)
        self.assertEqual(self.php('echo file_get_contents("/data/firefly/storage/upload/upgrade-persistence.txt");'), 'preserved')
        self.assertEqual(self.php('echo hash_file("sha256", "/data/firefly/storage/oauth-private.key");'), oauth_key)
        self.assertEqual(self.php('$db=new PDO("sqlite:/data/firefly/database.sqlite");'
                                  'echo $db->query("SELECT value FROM regression")->fetchColumn();'), 'persisted')
        self.assertIn('auto-generation enabled: false', docker('logs', self.name))
        self.assertIn('Preserving existing APP_KEY', docker('logs', self.name))

    def test_disabled_generation_with_missing_key_fails(self):
        self.start({'generate_app_key': False}, 'APP_KEY=""\n', expect_failure=True)
        self.assertIn('generate_app_key is false', docker('logs', self.name))
        self.assertNotIn('base64:', self.data_command('cat', '/data/firefly/.env'))

    def test_placeholder_is_replaced(self):
        self.start({'generate_app_key': True}, 'APP_KEY=SomeRandomStringOf32CharsExactly\n')
        self.assertTrue(self.config()['app']['key'].startswith('base64:'))

    def test_existing_quoted_key_preserved_with_generation_enabled(self):
        key = '0123456789abcdef0123456789abcdef'
        self.start({'generate_app_key': True}, 'APP_KEY="' + key + '"\n')
        self.assertEqual(self.config()['app']['key'], key)
        self.assertNotIn(key, docker('logs', self.name))

    def test_smtp_configuration_and_dotenv_roundtrip(self):
        password = 'test # "quoted" \\ ${NOT_AN_ENV} $value'
        self.start({'mail_mailer': 'smtp', 'mail_host': 'smtp.example.com',
                    'mail_port': 465, 'mail_username': 'test@example.com',
                    'mail_password': password, 'mail_encryption': 'ssl',
                    'mail_from': 'sender@example.com'})
        config = self.config()
        self.assertEqual(config['mail']['default'], 'smtp')
        smtp = config['mail']['mailers']['smtp']
        for key, value in {'host': 'smtp.example.com', 'port': 465,
                           'username': 'test@example.com', 'password': password,
                           'encryption': 'ssl', 'scheme': 'smtps'}.items():
            self.assertEqual(smtp[key], value)
        self.assertEqual(config['mail']['from']['address'], 'sender@example.com')
        parsed = json.loads(self.php('require "vendor/autoload.php";'
                                     'echo json_encode(Dotenv\\Dotenv::parse(file_get_contents("/data/firefly/.env")));'))
        self.assertEqual(parsed['MAIL_PASSWORD'], password)
        self.assertNotIn(password, docker('logs', self.name))

    def test_ingress_home_links_and_direct_access(self):
        self.start()
        docker('exec', self.name, 'php', 'artisan',
               'firefly-iii:set-latest-version', '--james-is-cool')
        root = 'http://ha.example:8123/api/hassio_ingress/regression'
        def page(*headers):
            return docker('exec', self.name, 'curl', '-fsS', *headers,
                          'http://127.0.0.1:8080/register')
        html = page('-H', 'X-Ingress-Path: /api/hassio_ingress/regression',
                    '-H', 'X-Forwarded-Host: ha.example:8123')
        hrefs = re.findall(r"href=[\"']([^\"']*)[\"']", html)
        self.assertNotIn(root, hrefs)
        self.assertIn('<base href="' + root + '/"', html)
        self.assertNotIn(root + '//', html)
        self.assertIn('href="' + root + '/login"', html)
        self.assertIn('href="' + root + '/build/assets/', html)
        direct = page()
        self.assertNotIn('/api/hassio_ingress/', direct)
        self.assertIn('<base href="http://127.0.0.1:8080/"', direct)

    def test_ingress_root_normalization(self):
        self.start()
        root = 'http://ha.example:8123/api/hassio_ingress/regression'
        prefix = '/api/hassio_ingress/regression'
        cases = [root, prefix, root + '?a=1&b=2', prefix + '#dashboard',
                 root + '/', root + '/login', root + '/build/assets/app.css',
                 root + '-another', 'https://other.example/', '/login']
        result = json.loads(self.php(
            'require "/usr/local/lib/firefly-ha-ingress.php";'
            '$urls=json_decode(' + json.dumps(json.dumps(cases)) + ', true);'
            'echo json_encode(array_map(fn($url) => ha_ingress_root_url($url, '
            + json.dumps(root) + ', ' + json.dumps(prefix) + '), $urls));'))
        self.assertEqual(result, [root + '/', prefix + '/', root + '/?a=1&b=2',
                                  prefix + '/#dashboard', *cases[4:]])
        # Exercise real PHP response headers and buffers, including redirect codes.
        fixture = """<?php
require '/usr/local/lib/firefly-ha-ingress.php';
$root = 'http://ha.example:8123/api/hassio_ingress/regression';
$prefix = '/api/hassio_ingress/regression';
ha_ingress_response($root, $prefix);
header_register_callback(fn() => ha_ingress_redirects($root, $prefix));
if (isset($_GET['redirect'])) {
    header('Location: ' . $root . '?from=home', true, (int) $_GET['redirect']);
} elseif (isset($_GET['json'])) {
    header('Content-Type: application/json');
    echo json_encode(['html' => '<a href="' . $root . '">Home</a>']);
} else {
    header('Content-Type: text/html');
    $body = '<a href="' . $root . '">Dashboard</a>';
    header('Content-Length: ' . strlen($body));
    echo $body;
}
"""
        self.php('file_put_contents("public/ha-regression.php", '
                 + json.dumps(fixture).replace('$', '\\$') + ');')
        def request(query):
            return docker('exec', self.name, 'curl', '-sS', '-i',
                          'http://127.0.0.1:8080/ha-regression.php' + query)
        for status in (302, 303, 307):
            response = request('?redirect=' + str(status))
            self.assertIn('HTTP/1.1 ' + str(status), response)
            self.assertIn('Location: ' + root + '/?from=home', response)
        response = request('')
        self.assertIn('href="' + root + '/"', response)
        self.assertNotIn('Content-Length:', response)
        response = request('?json=1')
        payload = json.loads(response.split('\n\n', 1)[1])
        self.assertEqual(payload['html'], '<a href="' + root + '">Home</a>')

    def test_mysql_settings_and_legacy_options(self):
        self.start({'db_connection': 'mysql', 'db_host': 'db.example.com',
                    'db_port': 3307, 'db_name': 'custom_db', 'db_user': 'custom_user',
                    'db_password': 'secret # with spaces'}, mysql=True)
        config = self.config()
        self.assertEqual(config['database']['default'], 'mysql')
        db = config['database']['connections']['mysql']
        for key, value in {'host': 'db.example.com', 'port': '3307', 'database': 'custom_db',
                           'username': 'custom_user', 'password': 'secret # with spaces'}.items():
            self.assertEqual(str(db[key]), value)
        self.assertEqual(config['mail']['default'], 'log')
        self.assertEqual(config['mail']['mailers']['smtp']['scheme'], 'smtp')
        self.assertFalse(Path(self.data.name, 'firefly/database.sqlite').exists())


if __name__ == '__main__':
    unittest.main()
