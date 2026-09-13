import json
from collections import defaultdict

with open(r"c:\Users\AurumArch\Documents\PROYECTOS\aurumcapital-mt5\scratch\trade_history_complete.json", 'r', encoding='utf-8') as f:
    trades = json.load(f)

by_hour = defaultdict(lambda: {'count': 0, 'wins': 0, 'losses': 0, 'be': 0, 'pnl': 0.0})
for t in trades:
    h = int(t['entry_time'][11:13])
    by_hour[h]['count'] += 1
    by_hour[h]['pnl'] += t['pnl_usd']
    if t['outcome'] == 'WIN': by_hour[h]['wins'] += 1
    elif t['outcome'] == 'LOSS': by_hour[h]['losses'] += 1
    else: by_hour[h]['be'] += 1

print("=== RENDIMIENTO POR HORA DE ENTRADA (HORA SERVIDOR MT5) ===")
for h in range(24):
    d = by_hour[h]
    cnt = d['count']
    wr = (d['wins']/cnt*100) if cnt > 0 else 0
    print(f"  Hora {h:02d}:00 | Trades={cnt:<3} | W={d['wins']:<2} L={d['losses']:<2} BE={d['be']:<2} | WR={wr:5.1f}% | PnL: ${d['pnl']:+7.2f}")
