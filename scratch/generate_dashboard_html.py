"""Generate an offline dashboard from FIFO estimates or native position audits."""
import argparse
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def generate_html(source=ROOT/'scratch/trade_history_complete.json',destination=ROOT/'DASHBOARD_HISTORICO_TRADES.html'):
    raw=json.loads(Path(source).read_text())
    if isinstance(raw,list):
        state='ESTIMACIÓN FIFO: fragmentos, sin conciliación de costes ni equity'
        rows=[dict(account=t.get('account',t.get('acc')),symbol=t['symbol'],entry=t['entry_time'],exit=t['exit_time'],pnl=float(t['pnl_usd']),currency='USD estimado',price=t['entry_price'],direction=t['direction']) for t in raw]
    else:
        state=raw['status']+' — posiciones cerradas; revisar registros incompletos en JSON'
        from datetime import datetime,timezone
        def stamp(ms):return datetime.fromtimestamp(ms/1000,tz=timezone.utc).strftime('%Y-%m-%d %H:%M:%S')+' [reloj exportado]'
        rows=[dict(account=t['server']+'/'+t['account'],symbol=t['symbol'],entry=stamp(t['entry_time_msc']),exit=stamp(t['exit_time_msc']),pnl=float(t['net']),currency=t['currency'],price=float(t['entry_price']),direction=t['direction']) for t in raw['positions']]
    payload=json.dumps(dict(state=state,rows=rows),ensure_ascii=False).replace('<','\\u003c')
    template=(ROOT/'tools/dashboard_template.html').read_text()
    Path(destination).write_text(template.replace('__AURUM_DATA__',payload),encoding='utf-8')
    print(destination)
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--input',type=Path,default=ROOT/'scratch/trade_history_complete.json');p.add_argument('--output',type=Path,default=ROOT/'DASHBOARD_HISTORICO_TRADES.html');a=p.parse_args();generate_html(a.input,a.output)
