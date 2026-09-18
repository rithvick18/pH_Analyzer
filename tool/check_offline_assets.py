"""Guard against accidentally bundling client credentials or restoring network access."""
import sys
import zipfile
from pathlib import Path
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
manifest = ET.parse(root / 'android/app/src/main/AndroidManifest.xml')
permissions = [p.get('{http://schemas.android.com/apk/res/android}name') for p in manifest.findall('uses-permission') if p.get('{http://schemas.android.com/tools}node') != 'remove']
assert 'android.permission.INTERNET' not in permissions, 'Offline release must not request Internet access'
assert 'android.permission.RECORD_AUDIO' not in permissions, 'Still capture does not need microphone permission'
assert '- .env' not in (root / 'pubspec.yaml').read_text(), '.env must not be bundled'
for source in (root / 'lib').rglob('*.dart'):
    text = source.read_text()
    assert 'GEMINI_API_KEY' not in text and 'google_generative_ai' not in text, f'Cloud credentials restored in {source}'
if len(sys.argv) > 1:
    merged = root / 'build/app/intermediates/merged_manifest/release/processReleaseMainManifest/AndroidManifest.xml'
    assert merged.exists(), 'Build the release before checking its merged permissions'
    names = [p.get('{http://schemas.android.com/apk/res/android}name') for p in ET.parse(merged).findall('uses-permission')]
    assert 'android.permission.INTERNET' not in names, 'Dependency restored Internet permission'
    assert 'android.permission.RECORD_AUDIO' not in names, 'Dependency restored microphone permission'
    with zipfile.ZipFile(sys.argv[1]) as bundle:
        assert not any(Path(n).name == '.env' for n in bundle.namelist()), 'Secret asset in release bundle'
print('Offline asset checks passed')
