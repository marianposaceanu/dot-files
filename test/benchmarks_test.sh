#!/usr/bin/env bash
# Safe regression checks: isolated files and simulated processes, no package changes.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec python3 - "$REPO_ROOT" <<'PYTHON'
import ast
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

REPO = Path(sys.argv.pop(1))

FAKE_CHROME = r'''#!/usr/bin/env python3
import base64, hashlib, json, os, socket, struct, sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
profile = Path(next(arg.split('=', 1)[1] for arg in sys.argv if arg.startswith('--user-data-dir=')))
mode = os.environ.get('FAKE_CDP', 'success')
def read_exact(connection, length):
    result = b''
    while len(result) < length:
        data = connection.recv(length - len(result))
        if not data:
            raise EOFError()
        result += data
    return result
class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args): pass
    def do_PUT(self): self.do_GET()
    def do_GET(self):
        if self.headers.get('Upgrade', '').lower() != 'websocket':
            result = {'Browser': 'Fixture Chrome'} if self.path == '/json/version' else {'webSocketDebuggerUrl': f'ws://127.0.0.1:{self.server.server_port}/devtools'}
            data = json.dumps(result).encode()
            self.send_response(200); self.send_header('Content-Length', str(len(data))); self.end_headers(); self.wfile.write(data)
            return
        key = self.headers['Sec-WebSocket-Key'] + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'
        self.send_response(101); self.send_header('Upgrade', 'websocket'); self.send_header('Connection', 'Upgrade')
        self.send_header('Sec-WebSocket-Accept', base64.b64encode(hashlib.sha1(key.encode()).digest()).decode()); self.end_headers()
        while True:
            try:
                first, second = read_exact(self.connection, 2)
                if first & 15 == 8: return
                length = second & 127
                if length == 126: length = struct.unpack('!H', read_exact(self.connection, 2))[0]
                elif length == 127: length = struct.unpack('!Q', read_exact(self.connection, 8))[0]
                mask = read_exact(self.connection, 4)
                data = read_exact(self.connection, length)
                message = json.loads(bytes(value ^ mask[i % 4] for i, value in enumerate(data)))
                if mode == 'disconnect': return
                if mode == 'stall': continue
                result = {}
                if message['method'] == 'Runtime.evaluate':
                    state = {'hash': '#summary', 'score': '42', 'valid': mode != 'invalid', 'viewport': [1200, 900]}
                    result = {'result': {'value': json.dumps(state)}}
                response = json.dumps({'id': message['id'], 'result': result}).encode()
                header = bytes([129, len(response)]) if len(response) < 126 else bytes([129, 126]) + struct.pack('!H', len(response))
                self.connection.sendall(header + response)
            except (EOFError, ConnectionError): return
server = HTTPServer(('127.0.0.1', 0), Handler)
if mode != 'startup-stall':
    (profile / 'DevToolsActivePort').write_text(f'{server.server_port}\n/devtools\n')
print('Ordinary Chrome diagnostic on stderr', file=sys.stderr, flush=True)
server.serve_forever()
'''

class BenchmarksTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='benchmarks-test-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.bench = self.root / 'benchmarks'
        shutil.copytree(REPO / 'benchmarks', self.bench)
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.env = dict(os.environ, PATH=f'{self.bin}:{os.environ["PATH"]}', TMPDIR=str(self.root))

    def executable(self, name, body, shebang='#!/usr/bin/env bash\n'):
        path = self.bin / name
        path.write_text(shebang + body)
        path.chmod(0o755)
        return path

    def run_script(self, script, *args, **env):
        return subprocess.run(['bash', str(self.bench / script), *args], env=dict(self.env, **env), capture_output=True, text=True, timeout=15)

    def vim_fixture(self):
        corpus = self.bench / 'corpus'
        corpus.mkdir(exist_ok=True)
        (corpus / 'words_100k.txt').write_text('abcdef benchmark word\n' * 20)
        (corpus / 'code_4k.rb').write_text('class Example\n  def hello; 123; end\nend\n')
        return self.executable('vim', '''if [[ "$1" == --version ]]; then printf 'VIM fixture\nCompiled by fixture\n'; exit 0; fi
if [[ "${FAKE_VIM_EXIT:-0}" != 0 ]]; then exit "$FAKE_VIM_EXIT"; fi
printf '%s\n' "${FAKE_VIM_DATA:-1.0}" > "$VIM_BENCH_TIMINGS"
''')

    def test_vim_failure_does_not_publish_results(self):
        vim = self.vim_fixture()
        result = self.run_script('vim_bench.sh', '--bench-only', '--runs', '1', VIM_BIN=str(vim), FAKE_VIM_EXIT='17')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Vim workload failed', result.stderr)
        self.assertFalse(list((self.bench / 'results').glob('*.txt')))

    def test_vim_rejects_incomplete_timings(self):
        vim = self.vim_fixture()
        result = self.run_script('vim_bench.sh', '--bench-only', '--runs', '2', VIM_BIN=str(vim))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Invalid or incomplete timings', result.stderr)

    def test_vim_even_median(self):
        vim = self.vim_fixture()
        result = self.run_script('vim_bench.sh', '--bench-only', '--label', 'fixture', '--runs', '2', VIM_BIN=str(vim), FAKE_VIM_DATA='1.0\n3.0')
        self.assertEqual(result.returncode, 0, result.stderr)
        report = next((self.bench / 'results').glob('fixture_*.txt')).read_text()
        self.assertIn('regex_scan: 2.0000', report)

    def test_vim_comparison_rejects_zero_and_corrupt_samples(self):
        metadata = 'compiled_by: fixture\ncflags: unknown\ntimestamp: fixture\n'
        keys = ['regex_scan', 'regex_replace', 'sort', 'vimscript_loop', 'regex_ruby']
        baseline = self.root / 'baseline.txt'
        baseline.write_text(metadata + ''.join(f'{key}: 1.0\n' for key in keys))
        candidate = self.root / 'candidate.txt'
        for invalid in ('0', 'ERR', 'invalid'):
            candidate.write_text(baseline.read_text().replace('regex_scan: 1.0', f'regex_scan: {invalid}'))
            result = self.run_script('vim_bench.sh', '--compare', str(baseline), str(candidate))
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Some benchmark results are invalid', result.stdout + result.stderr)

    def test_real_vim_workloads(self):
        vim = shutil.which('vim')
        if not vim: self.skipTest('Vim unavailable')
        self.vim_fixture()
        result = self.run_script('vim_bench.sh', '--bench-only', '--label', 'smoke', '--runs', '1', VIM_BIN=vim)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(list((self.bench / 'results').glob('smoke_*.txt')))

    def test_startup_profiles_use_self_time(self):
        vimrc = self.root / '.vimrc'; vimrc.write_text('')
        vim = self.executable('profile-vim', '''while [[ $# -gt 0 ]]; do
if [[ "$1" == --startuptime ]]; then
printf '001.000 10.000 2.000: sourcing /fixture/.vim/pack/bundles/start/example/plugin/a.vim\n002.000 20.000 3.000: sourcing /fixture/.vim/pack/bundles/start/example/autoload/b.vim\n042.000 001.000: finished\n' > "$2"
fi
shift
done
''')
        result = self.run_script('profile_vim_plugins.sh', VIM_BIN=str(vim), VIMRC_PATH=str(vimrc))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertRegex(result.stdout, r'5\.000\s+2 files\s+example')
        result = self.run_script('profile_vim_plugins_median.sh', VIM_BIN=str(vim), VIMRC_PATH=str(vimrc), RUNS='2')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('plugin_start_total_ms=5.000', result.stdout)
        self.assertIn('total_startup_ms=42.000', result.stdout)

    def rg_corpus(self):
        root = self.root / 'rg-corpus'; (root / 'large').mkdir(parents=True); (root / 'small').mkdir()
        (root / '.complete').write_text('fixture\n')
        (root / 'large' / 'sample.log').write_text('NEEDLE_native_rg_7d3f91a2 error_code=ERR2048 path=/api/v3/search-index request_id=0123456789abcdef; résumé naïve\n')
        (root / 'small' / 'sample.txt').write_text('ordinary content\n')
        return root

    def test_ripgrep_rejects_empty_success_and_no_matches(self):
        corpus = self.rg_corpus()
        for status in (0, 1):
            fake = self.executable('rg', f'if [[ "$1" == --version ]]; then echo fixture; exit 0; fi\nexit {status}\n')
            result = self.run_script('benchmark_ripgrep_native.sh', str(fake), RG_BENCH_CORPUS=str(corpus), RG_BENCH_REPETITIONS='1')
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Incorrect benchmark output', result.stderr)
            self.assertNotIn('| Workload |', result.stdout)

    def test_real_ripgrep_same_binary_comparison(self):
        rg = '/opt/homebrew/bin/rg' if Path('/opt/homebrew/bin/rg').exists() else shutil.which('rg')
        if not rg: self.skipTest('ripgrep unavailable')
        result = self.run_script('benchmark_ripgrep_native.sh', rg, 'one', rg, 'two', RG_BENCH_CORPUS=str(self.rg_corpus()), RG_BENCH_REPETITIONS='1')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('| PCRE2 lookaround, one thread |', result.stdout)
        self.assertEqual(result.stdout.count(' ms |'), 18)

    def test_ctags_same_path_keeps_independent_samples(self):
        counter = self.root / 'ctags-counter'
        fake = self.executable('ctags', f'''if [[ "$1" == --version ]]; then echo fixture; exit 0; fi
if [[ "$*" == *--sort=no* ]]; then
  count=0
  [[ ! -f "{counter}" ]] || read -r count < "{counter}"
  count=$((count + 1))
  printf '%s\\n' "$count" > "{counter}"
  if (( count % 2 )); then sleep 0.15; fi
fi
''')
        result = self.run_script('benchmark_ctags_native.sh', str(fake), 'one', str(fake), 'two', CTAGS_BENCH_REPETITIONS='1', CTAGS_BENCH_WARMUPS='0')
        self.assertEqual(result.returncode, 0, result.stderr)
        rows = [line.split('|') for line in result.stdout.splitlines() if ' ms |' in line]
        self.assertEqual(len(rows), 4)
        for row in rows:
            first, second = (float(value.split()[0]) for value in row[2:4])
            self.assertGreater(first - second, 50)

    def test_power_mode_rejects_ac_and_accepts_battery(self):
        self.executable('pmset', '''case "$*" in
'-g custom') printf 'Battery Power:\n lowpowermode 1\nAC Power:\n lowpowermode 0\n';;
'-g batt') printf "Now drawing from '%s Power'\\n" "${FAKE_POWER:-AC}";;
'-g therm') echo normal;;
esac
''')
        self.executable('openssl', 'if [[ "$1" == version ]]; then echo fixture; else echo "sha256 1 2 3 4 5 6"; fi\n')
        self.executable('node', 'echo "{}"\n')
        self.executable('system_profiler', 'echo "Chip: fixture"\n')
        self.executable('sw_vers', 'echo fixture\n')
        chrome = self.executable('chrome', 'echo fixture\n')
        result = self.run_script('m4_low_power_benchmark.sh', 'low', '1', CHROME_BIN=str(chrome))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('disconnect AC power', result.stderr)
        result = self.run_script('m4_low_power_benchmark.sh', 'low', '1', CHROME_BIN=str(chrome), FAKE_POWER='Battery')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('battery_lowpowermode=1', result.stdout)
        self.assertIn('finished=', result.stdout)

    def test_telemetry_rejects_changed_state_and_stopped_workload(self):
        body = (self.bench / 'm4_power_benchmark.sh').read_text().split("<<'PYTHON'\n", 1)[1].rsplit('\nPYTHON', 1)[0]
        namespace = {'__name__': 'fixture'}
        argv = sys.argv[:]
        try:
            sys.argv = ['fixture', str(self.bench)]
            exec(compile(body, 'm4_power_benchmark.sh', 'exec'), namespace)
        finally: sys.argv = argv
        namespace['battery_state'] = lambda: {'current_mA': 1}
        namespace['battery_low_power_mode'] = lambda: 0
        with self.assertRaisesRegex(SystemExit, 'changed during measurement'):
            namespace['sample_phase'](1, 1, 0)
        namespace['battery_state'] = lambda: {'current_mA': -1}
        class Stopped:
            def poll(self): return 17
        with self.assertRaisesRegex(SystemExit, 'OpenSSL exited'):
            namespace['sample_phase'](1, 1, 0, Stopped())

    def test_browser_success_disconnect_timeout_and_invalid_score(self):
        if not shutil.which('node'): self.skipTest('Node.js unavailable')
        chrome = self.executable('chrome', FAKE_CHROME, shebang='')
        for mode, message in [('success', None), ('disconnect', 'connection closed'), ('stall', 'request timed out'), ('invalid', 'Invalid Speedometer result'), ('startup-stall', 'Speedometer timed out')]:
            with self.subTest(mode=mode):
                result = self.run_script('speedometer_runner.sh', '1', CHROME_BIN=str(chrome), FAKE_CDP=mode, SPEEDOMETER_TIMEOUT_MS='500' if mode == 'startup-stall' else '3000', SPEEDOMETER_REQUEST_TIMEOUT_MS='500')
                if message:
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn(message, result.stderr)
                else:
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(json.loads(result.stdout)['score'], '42')
                self.assertFalse(list(self.root.glob('speedometer-profile-*')))

    def test_embedded_runtime_syntax(self):
        for path in self.bench.glob('*.sh'):
            lines = path.read_text().splitlines()
            for index, line in enumerate(lines):
                if "<<'PY'" in line or "<<'PYTHON'" in line:
                    delimiter = 'PYTHON' if "<<'PYTHON'" in line else 'PY'
                    end = lines.index(delimiter, index + 1)
                    ast.parse('\n'.join(lines[index + 1:end]), filename=str(path))
                elif "<<'JAVASCRIPT'" in line:
                    end = lines.index('JAVASCRIPT', index + 1)
                    result = subprocess.run(['node', '--input-type=module', '--check'], input='\n'.join(lines[index + 1:end]), text=True, capture_output=True)
                    self.assertEqual(result.returncode, 0, result.stderr)

unittest.main(verbosity=2)
PYTHON
