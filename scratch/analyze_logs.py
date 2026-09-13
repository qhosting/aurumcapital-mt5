import glob
import re
import os
import json
from collections import defaultdict
from datetime import datetime

TERMINAL_LOGS_DIR = r"C:\Users\AurumArch\AppData\Roaming\MetaQuotes\Terminal\656C351524AFFE300FAFE576FA4C7845\logs"
MQL5_LOGS_DIR = r"C:\Users\AurumArch\AppData\Roaming\MetaQuotes\Terminal\656C351524AFFE300FAFE576FA4C7845\MQL5\Logs"

def parse_mql5_closes():
    files = sorted(glob.glob(os.path.join(MQL5_LOGS_DIR, "*.log")))
    closes = []
    pattern = re.compile(r'(\d{2}:\d{2}:\d{2}\.\d{3})\s+.*\[CIERRE (GANANCIA|PERDIDA)\]\s+(\w+)\s+Vol:([\d\.]+)\s+@\s+([\d\.]+)\s+P&L:\s+\$([-\d\.]+)\s+Losses seguidos:\s+(\d+)')
    
    for fpath in files:
        date_str = os.path.basename(fpath).replace('.log', '')
        try:
            with open(fpath, 'r', encoding='utf-16', errors='ignore') as f:
                for line in f:
                    m = pattern.search(line)
                    if m:
                        t, outcome, sym, vol, px, pnl, lseq = m.groups()
                        closes.append({
                            'date': date_str,
                            'time': t,
                            'datetime': f"{date_str[:4]}-{date_str[4:6]}-{date_str[6:8]} {t}",
                            'outcome': outcome,
                            'symbol': sym,
                            'vol': float(vol),
                            'price': float(px),
                            'pnl': float(pnl),
                            'losses_seq': int(lseq)
                        })
        except Exception as e:
            pass
    return closes

def parse_all_deals():
    files = sorted(glob.glob(os.path.join(TERMINAL_LOGS_DIR, "*.log")))
    deals = []
    deal_pattern = re.compile(r'(\d{2}:\d{2}:\d{2}\.\d{3})\s+Trades\s+.*deal #(\d+)\s+(buy|sell)\s+([\d\.]+)\s+(\w+)\s+at\s+([\d\.]+)\s+done(?:\s+\(based on order #(\d+)\))?')
    
    for fpath in files:
        date_str = os.path.basename(fpath).replace('.log', '')
        try:
            with open(fpath, 'r', encoding='utf-16', errors='ignore') as f:
                for line in f:
                    m = deal_pattern.search(line)
                    if m:
                        t, deal_id, side, vol, sym, px, order_id = m.groups()
                        deals.append({
                            'date': date_str,
                            'time': t,
                            'datetime': f"{date_str[:4]}-{date_str[4:6]}-{date_str[6:8]} {t}",
                            'deal_id': deal_id,
                            'side': side,
                            'vol': float(vol),
                            'symbol': sym,
                            'price': float(px),
                            'order_id': order_id
                        })
        except Exception as e:
            pass
    return deals

def parse_mql5_xrays_and_signals():
    files = sorted(glob.glob(os.path.join(MQL5_LOGS_DIR, "*.log")))
    xrays = []
    signals = []
    trailing_events = []
    
    xray_pattern = re.compile(r'\[X-RAY (COMPRA|VENTA) OMITIDA\]\s+(\w+):\s+(.*)')
    sig_pattern = re.compile(r'\[DISPARO.*?\]|\[SENAL.*?\]|\[ENTRADA.*?\]|GATILLO')
    trail_pattern = re.compile(r'Fase \d|Micro-Lock|Break-Even|TRAIL|Candle-Trail', re.IGNORECASE)

    for fpath in files:
        date_str = os.path.basename(fpath).replace('.log', '')
        try:
            with open(fpath, 'r', encoding='utf-16', errors='ignore') as f:
                for line in f:
                    if '[X-RAY' in line:
                        m = xray_pattern.search(line)
                        if m:
                            side, sym, reasons = m.groups()
                            xrays.append({'date': date_str, 'side': side, 'symbol': sym, 'reasons': reasons})
                    if any(w in line for w in ['[BREAK-EVEN ACTIVADO]', '[MICRO-LOCK]', '[STEP TRAILING]', 'Fase 1', 'Fase 2', 'Fase 3']):
                        trailing_events.append({'date': date_str, 'line': line.strip()})
        except Exception as e:
            pass
            
    return xrays, trailing_events

if __name__ == '__main__':
    closes = parse_mql5_closes()
    deals = parse_all_deals()
    xrays, trails = parse_mql5_xrays_and_signals()
    
    print(f"=== RESULTADOS PARSEO HISTÓRICO ===")
    print(f"Total Terminal Deals: {len(deals)}")
    print(f"Total MQL5 Closes con P&L registrado: {len(closes)}")
    print(f"Total Omitidos por X-Ray (Filtros de Protección): {len(xrays)}")
    print(f"Total Eventos de Trailing/Gestión: {len(trails)}")
    
    if closes:
        wins = [c for c in closes if c['pnl'] > 0]
        losses = [c for c in closes if c['pnl'] < 0]
        be = [c for c in closes if c['pnl'] == 0]
        net_pnl = sum(c['pnl'] for c in closes)
        gross_win = sum(c['pnl'] for c in wins)
        gross_loss = sum(c['pnl'] for c in losses)
        pf = abs(gross_win / gross_loss) if gross_loss != 0 else 999.0
        
        print("\n--- PERFORMANCE GENERAL MQL5 ---")
        print(f"Total Trades cerrados por EA: {len(closes)}")
        print(f"Ganadoras (Wins): {len(wins)} ({len(wins)/len(closes)*100:.1f}%)")
        print(f"Perdedoras (Losses): {len(losses)} ({len(losses)/len(closes)*100:.1f}%)")
        print(f"Break-Even / Neutro: {len(be)}")
        print(f"Beneficio Neto Total: ${net_pnl:.2f}")
        print(f"Ganancia Bruta: ${gross_win:.2f} | Pérdida Bruta: ${gross_loss:.2f}")
        print(f"Profit Factor: {pf:.2f}")
        if wins:
            print(f"Ganancia Promedio por Win: ${gross_win/len(wins):.2f}")
        if losses:
            print(f"Pérdida Promedio por Loss: ${gross_loss/len(losses):.2f}")
        if wins and losses:
            print(f"Payoff Ratio (Win prom / Loss prom): {abs((gross_win/len(wins))/(gross_loss/len(losses))):.2f}")
        
        # Desglose por símbolo
        by_sym = defaultdict(lambda: {'wins': 0, 'losses': 0, 'be': 0, 'pnl': 0.0, 'win_pnl': 0.0, 'loss_pnl': 0.0})
        for c in closes:
            s = c['symbol']
            pnl = c['pnl']
            by_sym[s]['pnl'] += pnl
            if pnl > 0:
                by_sym[s]['wins'] += 1
                by_sym[s]['win_pnl'] += pnl
            elif pnl < 0:
                by_sym[s]['losses'] += 1
                by_sym[s]['loss_pnl'] += pnl
            else:
                by_sym[s]['be'] += 1
                
        print("\n--- RENDIMIENTO POR ACTIVO ---")
        for s, d in sorted(by_sym.items(), key=lambda x: -x[1]['pnl']):
            tot = d['wins'] + d['losses'] + d['be']
            wr = (d['wins'] / tot * 100) if tot > 0 else 0
            pf_s = abs(d['win_pnl'] / d['loss_pnl']) if d['loss_pnl'] != 0 else 999.0
            print(f"  {s:<12}: Trades={tot:<3} | W={d['wins']:<2} L={d['losses']:<2} BE={d['be']:<2} | WR={wr:5.1f}% | PF={pf_s:4.2f} | P&L: ${d['pnl']:+7.2f}")
