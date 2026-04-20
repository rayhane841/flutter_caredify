from pathlib import Path
path = Path('lib/screens/settings_screen.dart')
lines = path.read_text(encoding='utf-8').splitlines()
for i in range(169, 205):
    if i < len(lines):
        print(f'{i+1}: {lines[i]}')
