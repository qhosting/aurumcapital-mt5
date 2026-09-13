import importlib.util
import unittest
from decimal import Decimal as D
from pathlib import Path
import tempfile
import subprocess
import sys
spec=importlib.util.spec_from_file_location('ledger',Path(__file__).parents[1]/'tools/reconcile_deals.py')
ledger=importlib.util.module_from_spec(spec);spec.loader.exec_module(ledger)
def deal(id,pos,side,entry,v,profit=0,commission=0,swap=0):
    return dict(server='broker',account='1',currency='USD',deal_id=str(id),order_id=str(id),position_id=str(pos),time_msc=1000000+id,type=side,entry=entry,symbol='XAUUSD',magic='7',volume=D(str(v)),price=D('100'),profit=D(str(profit)),commission=D(str(commission)),swap=D(str(swap)),fee=D('0'))
class LedgerTests(unittest.TestCase):
    def test_opposite_hedges_remain_open(self):
        r=ledger.reconcile([deal(1,10,0,0,1),deal(2,11,1,0,1)])
        self.assertEqual(r['positions'],[]);self.assertEqual(len(r['unresolved']),2)
    def test_partial_and_entry_costs(self):
        r=ledger.reconcile([deal(1,10,0,0,1,commission=-2),deal(2,10,1,1,.5,4,-1),deal(3,10,1,1,.5,3,-1,-.5)])
        self.assertEqual(len(r['positions']),1);self.assertEqual(r['positions'][0]['net'],D('2.5'))
    def test_duplicate(self):
        d=deal(1,1,0,0,1);r=ledger.reconcile([d,d.copy()]);self.assertEqual(len(r['duplicate_deals']),1)
        other=d.copy();other['profit']=D('1')
        with self.assertRaises(ValueError):ledger.reconcile([d,other])
    def test_reversal_split_preserves_costs(self):
        r=ledger.reconcile([deal(1,1,0,0,1,commission=-1),deal(2,1,1,2,2,10,-2),deal(3,1,0,1,1,5,-1)])
        self.assertEqual([p['net'] for p in r['positions']],[D(8),D(3)])
        self.assertTrue(r['allocation_check'])
    def test_inout_reversal_allocates_fees(self):
        r=ledger.reconcile([deal(1,70,0,0,0.5),deal(2,70,1,2,0.8,8,-.3),deal(3,70,0,1,0.3,3,-.1)])
        self.assertEqual([p['net'] for p in r['positions']],[D('7.8125'),D('2.7875')])
    def test_missing_entry(self):
        r=ledger.reconcile([deal(1,1,1,1,1,10)])
        self.assertEqual(r['positions'],[]);self.assertEqual(r['unresolved'][0]['status'],'MISSING_OR_INCONSISTENT_ENTRY')
    def test_overclose_rejected(self):
        with self.assertRaises(ValueError):ledger.reconcile([deal(1,1,0,0,1),deal(2,1,1,1,2)])
    def test_balance_and_fee_adjustment(self):
        a=deal(1,0,2,0,0,100);b=deal(2,0,7,0,0,-1)
        r=ledger.reconcile([a,b]);self.assertEqual(r['accounts'][0]['external_flows'],100)
        self.assertEqual(r['accounts'][0]['deal_net'],99)
    def test_accounts_do_not_cross(self):
        a=deal(1,1,0,0,1);b=deal(2,1,1,0,1);b['account']='2'
        self.assertEqual(len(ledger.reconcile([a,b])['unresolved']),2)
    def test_fifo_csv_rejected_without_output(self):
        with tempfile.TemporaryDirectory() as td:
            out=Path(td)/'audit.json'
            source=Path(__file__).parents[1]/'scratch/trade_history_complete.csv'
            result=subprocess.run([sys.executable,str(Path(ledger.__file__)),str(source),'--output',str(out)],capture_output=True)
            self.assertNotEqual(result.returncode,0);self.assertFalse(out.exists())
if __name__=='__main__': unittest.main()
