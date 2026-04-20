from pathlib import Path

files = [
    Path('lib/screens/settings_screen.dart'),
    Path('lib/screens/results_screen.dart'),
    Path('lib/screens/profile_screen.dart'),
    Path('lib/screens/map_screen.dart'),
    Path('lib/screens/dashboard_screen.dart'),
]

for file in files:
    text = file.read_text(encoding='utf-8')
    par = 0
    bra = 0
    brk = 0
    print(file)
    for i, line in enumerate(text.splitlines(), 1):
        par += line.count('(') - line.count(')')
        bra += line.count('{') - line.count('}')
        brk += line.count('[') - line.count(']')
        if par < 0 or bra < 0 or brk < 0:
            print(f'  negative at {i}: par={par}, bra={bra}, brk={brk}')
            break
        if i >= 140 and i <= 180 and file.name == 'settings_screen.dart':
            print(f'{i}: par={par}, bra={bra}, brk={brk} | {line}')
    print('  final:', par, bra, brk)
    print()