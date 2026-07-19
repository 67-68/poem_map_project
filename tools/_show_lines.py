#!/usr/bin/env python3
with open('data/1_core_rules/translations/_dynamic_events.csv') as f:
    lines = f.readlines()
print(f'Total physical lines: {len(lines)}')
print()
for i in range(2929, min(3010, len(lines))):
    print(f'{i+1}: {lines[i].rstrip()[:160]}')
