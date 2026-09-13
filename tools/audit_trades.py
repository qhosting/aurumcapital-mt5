"""
=============================================================================
AURUM CAPITAL - AUDITOR Y SEGUIMIENTO AUTOMÁTICO DE TRADES
Herramienta de análisis forense para logs de MetaTrader 5 y MQL5.
Reconstruye operaciones completas por FIFO, calcula métricas R:R, P&L,
duración, días, horarios y genera reportes para el Roadmap de Trading.
=============================================================================
"""

import os
import sys
import glob
import re
import json
import csv
import argparse
from collections import defaultdict
from datetime import datetime

DEFAULT_TERMINAL_DIR = r"C:\Users\AurumArch\AppData\Roaming\MetaQuotes\Terminal\656C351524AFFE300FAFE576FA4C7845"

def get_terminal_logs_dir(base_dir=DEFAULT_TERMINAL_DIR):
    return os.path.join(base_dir, "logs")

def get_mql5_logs_dir(base_dir=DEFAULT_TERMINAL_DIR):
    return os.path.join(base_dir, "MQL5", "Logs")

def parse_deals(terminal_logs_dir):
    files = sorted(glob.glob(os.path.join(terminal_logs_dir, "*.log")))
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
                            'side': side.lower(),
                            'vol': round(float(vol), 4),
                            'symbol': sym,
                            'price': float(px),
                            'order_id': order_id
                        })
        except:
            pass
            
    all_deals.sort(key=lambda x: x['dt'])
    return all_deals

def match_trades_fifo(all_deals):
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
                'account': d['acc'],
                'symbol': sym,
                'direction': 'BUY' if pos['side'] == 'buy' else 'SELL',
                'volume': round(matched_vol, 4),
                'entry_time': pos['entry_dt'].strftime("%Y-%m-%d %H:%M:%S"),
                'exit_time': d['dt'].strftime("%Y-%m-%d %H:%M:%S"),
                'entry_price': pos['entry_price'],
                'exit_price': d['price'],
                'duration_min': round((d['dt'] - pos['entry_dt']).total_seconds() / 60.0, 1),
                'points': round(pts, 4),
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
            
    return completed_trades

def print_kpis(trades):
    if not trades:
        print("No se encontraron trades para analizar.")
        return
        
    wins = [t for t in trades if t['outcome'] == 'WIN']
    losses = [t for t in trades if t['outcome'] == 'LOSS']
    be = [t for t in trades if t['outcome'] == 'BE']
    
    total_trades = len(trades)
    win_rate = len(wins) / total_trades * 100
    loss_rate = len(losses) / total_trades * 100
    be_rate = len(be) / total_trades * 100
    
    total_pnl = sum(t['pnl_usd'] for t in trades)
    gross_win = sum(t['pnl_usd'] for t in wins)
    gross_loss = sum(t['pnl_usd'] for t in losses)
    pf = abs(gross_win / gross_loss) if gross_loss != 0 else 999.0
    
    avg_win = gross_win / len(wins) if wins else 0
    avg_loss = gross_loss / len(losses) if losses else 0
    payoff = abs(avg_win / avg_loss) if avg_loss != 0 else 0
    
    print("\n" + "="*70)
    print("           AURUM CAPITAL - HISTORICAL PERFORMANCE DASHBOARD")
    print("="*70)
    print(f"  Total Trades Auditados  : {total_trades}")
    print(f"  Ganadoras (Wins)        : {len(wins):<4} ({win_rate:5.1f}%) | Total Ganado:  ${gross_win:8.2f}")
    print(f"  Perdedoras (Losses)     : {len(losses):<4} ({loss_rate:5.1f}%) | Total Perdido: ${gross_loss:8.2f}")
    print(f"  Break-Even (BE)         : {len(be):<4} ({be_rate:5.1f}%)")
    print(f"  Beneficio Neto (P&L)    : ${total_pnl:8.2f}")
    print(f"  Profit Factor (PF)      : {pf:8.2f}")
    print(f"  Ganancia Promedio / Win : ${avg_win:8.2f}")
    print(f"  Pérdida Promedio / Loss : ${avg_loss:8.2f}")
    print(f"  Payoff Ratio (W/L)      : {payoff:8.2f}")
    print("="*70)

def export_to_csv(trades, csv_path):
    keys = ['account', 'symbol', 'direction', 'volume', 'entry_time', 'exit_time', 'entry_price', 'exit_price', 'duration_min', 'points', 'pnl_usd', 'outcome']
    with open(csv_path, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=keys)
        writer.writeheader()
        writer.writerows(trades)
    print(f"[EXPORT] {len(trades)} trades exportados exitosamente a: {csv_path}")

def main():
    parser = argparse.ArgumentParser(description="Auditor de Trades Históricos AurumCapital MT5")
    parser.add_argument("--dir", default=DEFAULT_TERMINAL_DIR, help="Ruta de datos del terminal MT5")
    parser.add_argument("--symbol", help="Filtrar por símbolo específico (ej. GOLDmicro, EURUSD)")
    parser.add_argument("--limit", type=int, help="Mostrar los últimos N trades")
    parser.add_argument("--csv", help="Ruta para exportar archivo CSV")
    parser.add_argument("--json", help="Ruta para exportar archivo JSON")
    args = parser.parse_args()
    
    terminal_logs = get_terminal_logs_dir(args.dir)
    print(f"[INFO] Leyendo logs desde: {terminal_logs}")
    deals = parse_deals(terminal_logs)
    print(f"[INFO] {len(deals)} deals procesados en logs históricos.")
    
    trades = match_trades_fifo(deals)
    
    if args.symbol:
        trades = [t for t in trades if args.symbol.lower() in t['symbol'].lower()]
        print(f"[FILTRO] Mostrando únicamente símbolo '{args.symbol}': {len(trades)} trades")
        
    print_kpis(trades)
    
    if args.limit:
        print(f"\n--- ÚLTIMOS {args.limit} TRADES ---")
        for t in trades[-args.limit:]:
            print(f"  {t['entry_time']} -> {t['exit_time']} | {t['symbol']:<11} {t['direction']:<4} {t['volume']:4.2f} | In:{t['entry_price']:8.2f} Out:{t['exit_price']:8.2f} | Dur:{t['duration_min']:5.1f}m | PnL: ${t['pnl_usd']:+6.2f} [{t['outcome']}]")
            
    if args.csv:
        export_to_csv(trades, args.csv)
    if args.json:
        with open(args.json, 'w', encoding='utf-8') as f:
            json.dump(trades, f, indent=2)
        print(f"[EXPORT] Trades guardados en formato JSON en: {args.json}")

if __name__ == '__main__':
    main()
