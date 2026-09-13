"""Reconstruct MT5 positions by identifiers, with costs and reversals.

Prices never substitute broker profit. CSV schema: ExportAurumHistory.mq5.
Balance reconciliation is optional and explicit; FIFO exports are rejected.
"""
import argparse
import csv
import hashlib
import json
from collections import defaultdict
from decimal import Decimal
from pathlib import Path

D = Decimal
ZERO = D('0')
REQUIRED = {'server','account','currency','deal_id','order_id','position_id','time_msc',
            'type','entry','symbol','magic','volume','price','profit','commission','swap','fee'}
NUMBERS = ('volume','price','profit','commission','swap','fee')


def read_deals(path):
    with Path(path).open(encoding='utf-8-sig', newline='') as f:
        reader = csv.DictReader(f)
        if not REQUIRED <= set(reader.fieldnames or []):
            raise ValueError('Native MT5 deal schema required; FIFO CSV is not a position ledger')
        rows = list(reader)
    if not rows:
        raise ValueError('Empty history; refusing to produce a successful audit')
    for i, r in enumerate(rows, 2):
        try:
            for k in NUMBERS:
                r[k] = D(r[k])
                if not r[k].is_finite():
                    raise ValueError('Nonfinite number')
            for k in ('time_msc','type','entry'):
                r[k] = int(r[k])
            if r['volume'] < 0 or r['time_msc'] <= 0:
                raise ValueError('Invalid volume/time')
            for k in ('server','account','currency','deal_id','order_id','position_id'):
                if not r[k]:
                    raise ValueError(f'Missing {k}')
            for k in ('account','deal_id','order_id','position_id'):
                if not r[k].isdigit():
                    raise ValueError(f'Invalid identifier {k}')
        except (ValueError, ArithmeticError, TypeError) as exc:
            raise ValueError(f'Invalid CSV row {i}: {exc}') from exc
    return rows


def reconcile(rows):
    seen, active, cycle = {}, {}, defaultdict(int)
    completed, incomplete, adjustments, duplicates = [], [], [], []
    account_totals = defaultdict(lambda: {'deal_net':ZERO,'external_flows':ZERO,'adjustments':ZERO})
    def fresh(r, key):
        cycle[key] += 1
        return dict(server=r['server'],account=r['account'],currency=r['currency'],position_id=r['position_id'],
                    cycle=cycle[key],symbol=r['symbol'],direction='BUY' if r['type']==0 else 'SELL',
                    volume=ZERO,entry_volume=ZERO,entry_value=ZERO,net=ZERO,
                    entry_time_msc=r['time_msc'],exit_time_msc=None,deal_ids=[],status='OPEN',
                    magic=r['magic'],initial_sl=r.get('initial_sl',''))
    def add(p, r, volume, net):
        p['volume'] += volume
        p['net'] += net
        if r['deal_id'] not in p['deal_ids']:
            p['deal_ids'].append(r['deal_id'])
        p['exit_time_msc'] = r['time_msc']
    for r in sorted(rows, key=lambda x:(x['time_msc'],int(x['deal_id']))):
        deal_key=(r['server'],r['account'],r['deal_id'])
        if deal_key in seen:
            if seen[deal_key]!=r:
                raise ValueError(f'Conflicting duplicate deal: {deal_key}')
            duplicates.append(deal_key)
            continue
        seen[deal_key]=r
        total=sum((r[k] for k in ('profit','commission','swap','fee')), ZERO)
        acc=(r['server'],r['account'],r['currency'])
        account_totals[acc]['deal_net']+=total
        if r['type'] not in (0,1):
            external=r['type'] in (2,3,6)
            account_totals[acc]['external_flows' if external else 'adjustments']+=total
            adjustments.append(dict(server=r['server'],account=r['account'],deal_id=r['deal_id'],net=total,type=r['type'],external_flow=external))
            continue
        if r['position_id']=='0' or r['volume']<=0:
            raise ValueError('Trading deal requires positive volume and position ID')
        key=(r['server'],r['account'],r['position_id'])
        p=active.get(key)
        side='BUY' if r['type']==0 else 'SELL'
        if p and (p['symbol']!=r['symbol'] or p['currency']!=r['currency']):
            raise ValueError(f'Position metadata conflict: {key}')
        if r['entry']==0:
            if p is None:
                p=fresh(r,key);active[key]=p
            if p['direction']!=side:
                raise ValueError('Opposite IN on same position ID; invalid history')
            add(p,r,r['volume'],total)
            p['entry_volume']+=r['volume'];p['entry_value']+=r['price']*r['volume']
        elif r['entry'] in (1,2,3):
            if p is None or p['direction']==side:
                incomplete.append(dict(server=r['server'],account=r['account'],position_id=r['position_id'],deal_id=r['deal_id'],net=total,status='MISSING_OR_INCONSISTENT_ENTRY'))
                continue
            if r['entry']!=2 and r['volume']>p['volume']:
                raise ValueError(f'Exit volume exceeds position {key}')
            close_volume=min(p['volume'],r['volume'])
            opening=r['volume']-close_volume
            # DEAL_ENTRY_INOUT (2) closes the old side and opens the residual
            # reverse side in the same deal. OUT_BY (3) is a pure close.
            if r['entry']==2 and opening<=0:
                raise ValueError('INOUT without opening residual')
            fees=r['commission']+r['fee']
            close_net=r['profit']+r['swap']+fees*close_volume/r['volume']
            add(p,r,-close_volume,close_net)
            if p['volume']==0:
                p['status']='CLOSED';p['entry_price']=p['entry_value']/p['entry_volume']
                completed.append(p);del active[key]
            if opening>0:
                new=fresh(r,key)
                add(new,r,opening,total-close_net)
                new['entry_volume']=opening;new['entry_value']=opening*r['price']
                active[key]=new
        else:
            raise ValueError(f'Unknown entry type {r["entry"]}')
    # Any unmatched exit makes later inference on that account provisional.
    unresolved=list(active.values())+incomplete
    stats=[]
    for acc, totals in account_totals.items():
        closed=[p for p in completed if (p['server'],p['account'],p['currency'])==acc]
        positive=sum((p['net'] for p in closed if p['net']>0),ZERO)
        negative=-sum((p['net'] for p in closed if p['net']<0),ZERO)
        stats.append(dict(server=acc[0],account=acc[1],currency=acc[2],**totals,
                          closed_positions=len(closed),closed_net=sum((p['net'] for p in closed),ZERO),
                          profit_factor=positive/negative if negative else None,
                          mean_net=sum((p['net'] for p in closed),ZERO)/len(closed) if closed else None))
    allocated=sum((p['net'] for p in completed+unresolved+adjustments),ZERO)
    ledger=sum((v['deal_net'] for v in account_totals.values()),ZERO)
    if allocated!=ledger:
        raise ValueError(f'Internal allocation mismatch: {allocated} != {ledger}')
    return dict(status='UNRECONCILED_BALANCES',positions=completed,unresolved=unresolved,adjustments=adjustments,
                duplicate_deals=duplicates,accounts=stats,allocation_check=True)


def json_value(obj):
    if isinstance(obj, Decimal):
        return str(obj)
    raise TypeError(type(obj).__name__)


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('deals',type=Path)
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--opening-book-value',type=Decimal,help='Balance + credit immediately BEFORE first exported deal; single account only')
    p.add_argument('--closing-book-value',type=Decimal,help='Balance + credit immediately AFTER last exported deal')
    args=p.parse_args()
    try:
        if args.output.exists():
            raise ValueError('Output already exists; choose a new audit filename')
        result=reconcile(read_deals(args.deals))
        if (args.opening_book_value is None)!=(args.closing_book_value is None):
            raise ValueError('Supply both opening and closing book values')
        if args.opening_book_value is not None:
            if len(result['accounts'])!=1:
                raise ValueError('Balance reconciliation requires a single account')
            delta=args.opening_book_value+result['accounts'][0]['deal_net']-args.closing_book_value
            result['balance_difference']=delta
            result['status']='BALANCE_MATCH_POSITIONS_REVIEW_REQUIRED' if abs(delta)<=D('0.01') else 'BALANCE_MISMATCH'
        result['source_sha256']=hashlib.sha256(args.deals.read_bytes()).hexdigest()
        args.output.parent.mkdir(parents=True,exist_ok=True)
        with args.output.open('x',encoding='utf-8') as f:
            json.dump(result,f,default=json_value,indent=2,ensure_ascii=False)
            f.write('\n')
        print(result['status'])
    except (ValueError,OSError) as exc:
        p.error(str(exc))

if __name__=='__main__':
    main()
