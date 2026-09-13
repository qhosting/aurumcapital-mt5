import glob
import re
import os
import json
from collections import defaultdict
from datetime import datetime

TERMINAL_LOGS_DIR = r"C:\Users\AurumArch\AppData\Roaming\MetaQuotes\Terminal\656C351524AFFE300FAFE576FA4C7845\logs"
MQL5_LOGS_DIR = r"C:\Users\AurumArch\AppData\Roaming\MetaQuotes\Terminal\656C351524AFFE300FAFE576FA4C7845\MQL5\Logs"

def analyze_full_history():
    files = sorted(glob.glob(os.path.join(TERMINAL_LOGS_DIR, "*.log")))
    deal_pattern = re.compile(r"(\d{2}:\d{2}:\d{2}\.\d{3})\s+Trades\s+'(\d+)':\s+deal #(\d+)\s+(buy|sell)\s+([\d\.]+)\s+(\w+)\s+at\s+([\d\.]+)\s+done(?:\s+\(based on order #(\d+)\))?")
    
    all_deals = []
    for fpath in files:
        date_str = os.path.basename(fpath).replace('.log', '')
        try:
            with open(fpath, 'r', encoding='utf-16', errors='ignore') as f:
                for line in f:
                    m = deal_pattern.search(line)
                    if m:
                        t, acc, deal_id, side, vol, sym, px, order_id = m.groups()
                        dt_str = f"{date_str[:4]}-{date_str[4:6]}-{date_str[6:8]} {t}"
                        try:
                            dt = datetime.strptime(dt_str, "%Y-%m-%d %H:%M:%S.%f")
                        except:
                            dt = datetime.strptime(dt_str.split('.')[0], "%Y-%m-%d %H:%M:%S")
                        all_deals.append({
                            'dt': dt,
                            'date': date_str,
                            'time': t,
                            'acc': acc,
                            'deal_id': deal_id,
                            'side': side,
                            'vol': round(float(vol), 4),
                            'symbol': sym,
                            'price': float(px),
                            'order_id': order_id
                        })
        except:
            pass
            
    all_deals.sort(key=lambda x: x['dt'])
    
    open_positions = defaultdict(list)
    completed_trades = []
    
    for d in all_deals:
        key = (d['acc'], d['symbol'])
        opp_side = 'sell' if d['side'] == 'buy' else 'buy'
        needed_vol = d['vol']
        
        while needed_vol > 0.00001 and len(open_positions[key]) > 0 and open_positions[key][0]['side'] == opp_side:
            pos = open_positions[key][0]
            matched_vol = min(pos['vol'], needed_vol)
            
            if pos['side'] == 'buy':
                pts = d['price'] - pos['entry_price']
            else:
                pts = pos['entry_price'] - d['price']
                
            sym = d['symbol']
            if 'GOLDmicro' in sym:
                pnl_usd = pts * matched_vol
            elif sym == 'GOLD':
                pnl_usd = pts * matched_vol * 100
            elif 'JPY' in sym:
                contract = 1000 if 'micro' in sym else 100000
                pnl_usd = (pts / d['price']) * contract * matched_vol
            elif 'micro' in sym:
                pnl_usd = pts * 1000 * matched_vol
            elif sym in ['EURUSD', 'GBPUSD']:
                pnl_usd = pts * 100000 * matched_vol
            elif 'BTC' in sym:
                pnl_usd = pts * matched_vol
            else:
                pnl_usd = pts * matched_vol
                
            completed_trades.append({
                'acc': d['acc'],
                'symbol': sym,
                'direction': 'BUY' if pos['side'] == 'buy' else 'SELL',
                'volume': round(matched_vol, 4),
                'entry_time': pos['entry_dt'].strftime("%Y-%m-%d %H:%M:%S"),
                'exit_time': d['dt'].strftime("%Y-%m-%d %H:%M:%S"),
                'entry_dt': pos['entry_dt'],
                'exit_dt': d['dt'],
                'entry_price': pos['entry_price'],
                'exit_price': d['price'],
                'duration_min': round((d['dt'] - pos['entry_dt']).total_seconds() / 60.0, 1),
                'pts': round(pts, 4),
                'pnl_usd': round(pnl_usd, 2),
                'outcome': 'WIN' if pnl_usd > 0.05 else ('LOSS' if pnl_usd < -0.05 else 'BE')
            })
            
            pos['vol'] -= matched_vol
            needed_vol -= matched_vol
            if pos['vol'] <= 0.00001:
                open_positions[key].pop(0)
                
        if needed_vol > 0.00001:
            open_positions[key].append({
                'side': d['side'],
                'vol': needed_vol,
                'entry_price': d['price'],
                'entry_dt': d['dt'],
                'entry_deal': d['deal_id']
            })
            
    # Monthly analysis
    by_month = defaultdict(lambda: {'count': 0, 'wins': 0, 'losses': 0, 'be': 0, 'pnl': 0.0, 'win_usd': 0.0, 'loss_usd': 0.0})
    for t in completed_trades:
        m = t['entry_dt'].strftime("%Y-%m")
        by_month[m]['count'] += 1
        by_month[m]['pnl'] += t['pnl_usd']
        if t['outcome'] == 'WIN':
            by_month[m]['wins'] += 1
            by_month[m]['win_usd'] += t['pnl_usd']
        elif t['outcome'] == 'LOSS':
            by_month[m]['losses'] += 1
            by_month[m]['loss_usd'] += t['pnl_usd']
        else:
            by_month[m]['be'] += 1

    # Hourly analysis (Server hour)
    by_hour = defaultdict(lambda: {'count': 0, 'wins': 0, 'losses': 0, 'pnl': 0.0})
    for t in completed_trades:
        h = t['entry_dt'].hour
        by_hour[h]['count'] += 1
        by_hour[h]['pnl'] += t['pnl_usd']
        if t['outcome'] == 'WIN': by_hour[h]['wins'] += 1
        elif t['outcome'] == 'LOSS': by_hour[h]['losses'] += 1

    # Day of week
    by_dow = defaultdict(lambda: {'count': 0, 'wins': 0, 'losses': 0, 'pnl': 0.0})
    days = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo']
    for t in completed_trades:
        d_idx = t['entry_dt'].weekday()
        d_name = days[d_idx]
        by_dow[d_name]['count'] += 1
        by_dow[d_name]['pnl'] += t['pnl_usd']
        if t['outcome'] == 'WIN': by_dow[d_name]['wins'] += 1
        elif t['outcome'] == 'LOSS': by_dow[d_name]['losses'] += 1

    # Holding duration analysis
    by_duration = {
        '< 5 min (Scalp Ultra-Rápido)': {'count': 0, 'wins': 0, 'losses': 0, 'pnl': 0.0},
        '5 - 30 min (Scalp Estándar)': {'count': 0, 'wins': 0, 'losses': 0, 'pnl': 0.0},
        '30 - 120 min (Day Trade)': {'count': 0, 'wins': 0, 'losses': 0, 'pnl': 0.0},
        '> 2 horas (Swing / Atrapado)': {'count': 0, 'wins': 0, 'losses': 0, 'pnl': 0.0},
    }
    for t in completed_trades:
        dur = t['duration_min']
        if dur < 5: cat = '< 5 min (Scalp Ultra-Rápido)'
        elif dur <= 30: cat = '5 - 30 min (Scalp Estándar)'
        elif dur <= 120: cat = '30 - 120 min (Day Trade)'
        else: cat = '> 2 horas (Swing / Atrapado)'
        
        by_duration[cat]['count'] += 1
        by_duration[cat]['pnl'] += t['pnl_usd']
        if t['outcome'] == 'WIN': by_duration[cat]['wins'] += 1
        elif t['outcome'] == 'LOSS': by_duration[cat]['losses'] += 1

    # Direction analysis
    by_dir = defaultdict(lambda: {'count': 0, 'wins': 0, 'losses': 0, 'pnl': 0.0})
    for t in completed_trades:
        direction = t['direction']
        by_dir[direction]['count'] += 1
        by_dir[direction]['pnl'] += t['pnl_usd']
        if t['outcome'] == 'WIN': by_dir[direction]['wins'] += 1
        elif t['outcome'] == 'LOSS': by_dir[direction]['losses'] += 1

    stats = {
        'total_trades': len(completed_trades),
        'by_month': dict(by_month),
        'by_hour': dict(by_hour),
        'by_dow': dict(by_dow),
        'by_duration': dict(by_duration),
        'by_direction': dict(by_dir)
    }
    
    # Save trades to JSON for roadmap and future querying
    serializable_trades = []
    for t in completed_trades:
        tc = dict(t)
        del tc['entry_dt']
        del tc['exit_dt']
        serializable_trades.append(tc)
        
    with open(r"c:\Users\AurumArch\Documents\PROYECTOS\aurumcapital-mt5\scratch\trade_history_complete.json", 'w', encoding='utf-8') as f:
        json.dump(serializable_trades, f, indent=2)
        
    return stats, completed_trades

if __name__ == '__main__':
    stats, trades = analyze_full_history()
    print("=== ANÁLISIS MENSUAL ===")
    for m, d in sorted(stats['by_month'].items()):
        wr = d['wins']/d['count']*100 if d['count']>0 else 0
        pf = abs(d['win_usd']/d['loss_usd']) if d['loss_usd']!=0 else 999
        print(f"  {m}: Trades={d['count']:<3} | W={d['wins']:<2} L={d['losses']:<2} BE={d['be']:<2} | WR={wr:5.1f}% | PF={pf:4.2f} | PnL: ${d['pnl']:+7.2f}")

    print("\n=== ANÁLISIS POR DURACIÓN DE OPERACIÓN ===")
    for k, d in stats['by_duration'].items():
        wr = d['wins']/d['count']*100 if d['count']>0 else 0
        print(f"  {k:<32}: Trades={d['count']:<3} | WR={wr:5.1f}% | PnL: ${d['pnl']:+7.2f}")

    print("\n=== ANÁLISIS POR DIRECCIÓN ===")
    for k, d in stats['by_direction'].items():
        wr = d['wins']/d['count']*100 if d['count']>0 else 0
        print(f"  {k:<6}: Trades={d['count']:<3} | WR={wr:5.1f}% | PnL: ${d['pnl']:+7.2f}")

    print("\n=== ANÁLISIS POR DÍA DE LA SEMANA ===")
    for k, d in stats['by_dow'].items():
        wr = d['wins']/d['count']*100 if d['count']>0 else 0
        print(f"  {k:<10}: Trades={d['count']:<3} | WR={wr:5.1f}% | PnL: ${d['pnl']:+7.2f}")
