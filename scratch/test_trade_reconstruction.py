import glob
import re
import os
from collections import defaultdict
from datetime import datetime

TERMINAL_LOGS_DIR = r"C:\Users\AurumArch\AppData\Roaming\MetaQuotes\Terminal\656C351524AFFE300FAFE576FA4C7845\logs"

def reconstruct_trades():
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
                            'dt_str': dt_str,
                            'date': date_str,
                            'time': t,
                            'acc': acc,
                            'deal_id': deal_id,
                            'side': side, # buy or sell
                            'vol': round(float(vol), 4),
                            'symbol': sym,
                            'price': float(px),
                            'order_id': order_id
                        })
        except Exception as e:
            pass
            
    # Sort all deals chronologically
    all_deals.sort(key=lambda x: x['dt'])
    
    # FIFO trade matching per (acc, symbol)
    # Positions: list of open lots: {'side': buy/sell, 'vol': remaining_vol, 'entry_price': px, 'entry_dt': dt, 'entry_deal': id}
    open_positions = defaultdict(list)
    completed_trades = []
    
    for d in all_deals:
        key = (d['acc'], d['symbol'])
        opp_side = 'sell' if d['side'] == 'buy' else 'buy'
        
        needed_vol = d['vol']
        # check if there are open positions of opposite side
        while needed_vol > 0.00001 and len(open_positions[key]) > 0 and open_positions[key][0]['side'] == opp_side:
            pos = open_positions[key][0]
            matched_vol = min(pos['vol'], needed_vol)
            
            # calculate profit in points and estimate USD
            # Long: exit - entry, Short: entry - exit
            if pos['side'] == 'buy':
                pts = d['price'] - pos['entry_price']
            else:
                pts = pos['entry_price'] - d['price']
                
            # Point/contract value estimation
            sym = d['symbol']
            multiplier = 1.0
            pnl_usd = 0.0
            
            if 'GOLDmicro' in sym:
                # 1 oz contract. 0.1 lot = 0.1 oz. $1 price move = $0.10. So PnL = pts * matched_vol
                pnl_usd = pts * matched_vol
            elif sym == 'GOLD':
                # 100 oz contract. 0.01 lot = 1 oz. $1 move = $1.00. PnL = pts * matched_vol * 100
                pnl_usd = pts * matched_vol * 100
            elif 'JPY' in sym:
                # USDJPY: pip is 0.01. If micro (1000 contract): 0.1 lot = 100. PnL ~ (pts / price) * 1000 * matched_vol
                # or standard 100,000 contract: 0.02 lot = 2000. PnL ~ (pts / price) * 100000 * matched_vol
                is_micro = 'micro' in sym
                contract = 1000 if is_micro else 100000
                pnl_usd = (pts / d['price']) * contract * matched_vol
            elif 'micro' in sym: # EURUSDmicro, GBPUSDmicro
                contract = 1000
                pnl_usd = pts * contract * matched_vol
            elif sym in ['EURUSD', 'GBPUSD']:
                contract = 100000
                pnl_usd = pts * contract * matched_vol
            elif 'BTC' in sym:
                # 1 BTC contract. 0.01 lot = 0.01 BTC. PnL = pts * matched_vol
                pnl_usd = pts * matched_vol
            elif 'US30' in sym:
                pnl_usd = pts * matched_vol
            else:
                pnl_usd = pts * matched_vol
                
            completed_trades.append({
                'acc': d['acc'],
                'symbol': sym,
                'direction': 'BUY' if pos['side'] == 'buy' else 'SELL',
                'volume': round(matched_vol, 4),
                'entry_time': pos['entry_dt'],
                'entry_price': pos['entry_price'],
                'exit_time': d['dt'],
                'exit_price': d['price'],
                'duration_sec': (d['dt'] - pos['entry_dt']).total_seconds(),
                'pts': round(pts, 4),
                'pnl_usd': round(pnl_usd, 2),
                'is_win': (pnl_usd > 0.05),
                'is_loss': (pnl_usd < -0.05),
                'is_be': (-0.05 <= pnl_usd <= 0.05)
            })
            
            pos['vol'] -= matched_vol
            needed_vol -= matched_vol
            if pos['vol'] <= 0.00001:
                open_positions[key].pop(0)
                
        # If there is remaining volume, it becomes a new position of side d['side']
        if needed_vol > 0.00001:
            open_positions[key].append({
                'side': d['side'],
                'vol': needed_vol,
                'entry_price': d['price'],
                'entry_dt': d['dt'],
                'entry_deal': d['deal_id']
            })
            
    return completed_trades, open_positions

if __name__ == '__main__':
    trades, open_pos = reconstruct_trades()
    print(f"Total Completed Trades Reconstructed: {len(trades)}")
    
    wins = [t for t in trades if t['is_win']]
    losses = [t for t in trades if t['is_loss']]
    be = [t for t in trades if t['is_be']]
    total_pnl = sum(t['pnl_usd'] for t in trades)
    gross_win = sum(t['pnl_usd'] for t in wins)
    gross_loss = sum(t['pnl_usd'] for t in losses)
    pf = abs(gross_win / gross_loss) if gross_loss != 0 else 999
    
    print(f"Wins: {len(wins)} ({len(wins)/len(trades)*100:.1f}%)")
    print(f"Losses: {len(losses)} ({len(losses)/len(trades)*100:.1f}%)")
    print(f"Break-Even: {len(be)} ({len(be)/len(trades)*100:.1f}%)")
    print(f"Net PnL Reconstructed: ${total_pnl:.2f}")
    print(f"Gross Win: ${gross_win:.2f} | Gross Loss: ${gross_loss:.2f} | Profit Factor: {pf:.2f}")
    
    by_sym = defaultdict(lambda: {'count': 0, 'wins': 0, 'losses': 0, 'be': 0, 'pnl': 0.0, 'win_pnl': 0.0, 'loss_pnl': 0.0})
    for t in trades:
        s = t['symbol']
        by_sym[s]['count'] += 1
        by_sym[s]['pnl'] += t['pnl_usd']
        if t['is_win']:
            by_sym[s]['wins'] += 1
            by_sym[s]['win_pnl'] += t['pnl_usd']
        elif t['is_loss']:
            by_sym[s]['losses'] += 1
            by_sym[s]['loss_pnl'] += t['pnl_usd']
        else:
            by_sym[s]['be'] += 1
            
    print("\nTrades por Símbolo:")
    for s, d in sorted(by_sym.items(), key=lambda x: -x[1]['count']):
        wr = d['wins'] / d['count'] * 100
        pf_s = abs(d['win_pnl'] / d['loss_pnl']) if d['loss_pnl'] != 0 else 999.0
        print(f"  {s:<12}: Trades={d['count']:<4} | Win={d['wins']:<3} Loss={d['losses']:<3} BE={d['be']:<2} | WR={wr:5.1f}% | PF={pf_s:4.2f} | PnL: ${d['pnl']:+8.2f}")
