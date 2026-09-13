"""Audita exportaciones FIFO existentes; no las convierte en historial conciliado.

Uso: python3 tools/review_export.py
Solo biblioteca estándar. Conserva duplicados y etiquetas originales como evidencia.
"""
import csv
import hashlib
import json
from collections import Counter, defaultdict
from datetime import datetime
from decimal import Decimal
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def metrics(rows):
    pnl = [Decimal(str(t['pnl_usd'])) for t in rows]
    positive = sum((p for p in pnl if p > 0), Decimal(0))
    negative = -sum((p for p in pnl if p < 0), Decimal(0))
    labels = Counter(t['outcome'] for t in rows)
    return {
        'fragments': len(rows),
        'estimated_pnl_usd': float(sum(pnl)),
        'gross_positive_usd': float(positive),
        'gross_negative_usd': float(negative),
        'pf_by_sign': float(positive / negative) if negative else None,
        'mean_estimated_pnl_usd': float(sum(pnl) / len(pnl)) if pnl else None,
        'original_labels': dict(labels),
        'win_rate_original_pct': 100 * labels['WIN'] / len(rows) if rows else None,
        'positive_fragments_pct': 100 * sum(p > 0 for p in pnl) / len(pnl) if pnl else None,
    }


def grouped(rows, key):
    groups = defaultdict(list)
    for row in rows:
        groups[str(key(row))].append(row)
    return {k: metrics(v) for k, v in sorted(groups.items())}


def main():
    source = ROOT / 'scratch/trade_history_complete.json'
    csv_source = ROOT / 'scratch/trade_history_complete.csv'
    rows = json.loads(source.read_text(encoding='utf-8'))
    if not rows:
        raise ValueError('Exportación vacía')
    with csv_source.open(newline='', encoding='utf-8') as handle:
        csv_rows = list(csv.DictReader(handle))
    numeric = ['volume', 'entry_price', 'exit_price', 'duration_min', 'pnl_usd']
    strings = ['symbol', 'direction', 'entry_time', 'exit_time', 'outcome']
    equal = len(rows) == len(csv_rows) and all(
        r['acc'] == c['account']
        and all(r[k] == c[k] for k in strings)
        and all(Decimal(str(r[k])) == Decimal(c[k]) for k in numeric)
        and Decimal(str(r['pts'])) == Decimal(c['points'])
        for r, c in zip(rows, csv_rows)
    )
    duplicates = defaultdict(list)
    entry_groups = set()
    issues = []
    for index, r in enumerate(rows, 1):
        duplicates[json.dumps(r, sort_keys=True)].append(index)
        entry_groups.add((r['acc'], r['symbol'], r['direction'], r['entry_time'], r['entry_price']))
        start, end = (datetime.fromisoformat(r[k]) for k in ['entry_time', 'exit_time'])
        if end < start or r['volume'] <= 0:
            issues.append(index)
    result = {
        'status': 'FIFO_ESTIMATE_NOT_RECONCILED',
        'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
        'csv_sha256': hashlib.sha256(csv_source.read_bytes()).hexdigest(),
        'csv_json_equal': equal,
        'earliest_entry': min(r['entry_time'] for r in rows),
        'latest_exit': max(r['exit_time'] for r in rows),
        'entry_days': len({r['entry_time'][:10] for r in rows}),
        'candidate_entry_groups_not_positions': len(entry_groups),
        'exact_duplicate_row_numbers_1_based': [v for v in duplicates.values() if len(v) > 1],
        'invalid_time_or_volume_rows': issues,
        'overall': metrics(rows),
        'by_account': grouped(rows, lambda r: r['acc']),
        'by_symbol': grouped(rows, lambda r: r['symbol']),
        'by_direction': grouped(rows, lambda r: r['direction']),
        'by_entry_month': grouped(rows, lambda r: r['entry_time'][:7]),
        'by_exit_month': grouped(rows, lambda r: r['exit_time'][:7]),
        'by_entry_hour_unverified_timezone': grouped(rows, lambda r: r['entry_time'][11:13]),
        'by_entry_weekday_unverified_timezone': grouped(rows, lambda r: datetime.fromisoformat(r['entry_time']).strftime('%A')),
        'by_duration_minutes': grouped(rows, lambda r: '<5' if r['duration_min'] < 5 else '5-30' if r['duration_min'] <= 30 else '30-120' if r['duration_min'] <= 120 else '>120'),
        'worst_fragments': sorted(rows, key=lambda r: r['pnl_usd'])[:10],
        'best_fragments': sorted(rows, key=lambda r: r['pnl_usd'], reverse=True)[:10],
        'sensitivity_remove_worst_one_not_a_backtest': metrics(sorted(rows, key=lambda r: r['pnl_usd'])[1:]),
    }
    destination = ROOT / 'auditoria'
    destination.mkdir(exist_ok=True)
    (destination / 'metricas_exportacion.json').write_text(json.dumps(result, indent=2, ensure_ascii=False, allow_nan=False) + '\n')
    lines = ['# Métricas recalculadas de la exportación FIFO', '',
             'Estimaciones sin conciliación con MT5. Las filas son fragmentos, no posiciones independientes.', '',
             f"Período: {result['earliest_entry']} → {result['latest_exit']}. Zona horaria desconocida.", '',
             f"CSV y JSON coinciden: {equal}. Grupos candidatos de entrada: {len(entry_groups)}.", '',
             'PF usa todos los P&L positivos y negativos, incluidos los etiquetados BE. WR conserva las etiquetas históricas.', '']
    for name in ['by_account', 'by_symbol', 'by_direction', 'by_entry_month', 'by_exit_month', 'by_duration_minutes', 'by_entry_hour_unverified_timezone', 'by_entry_weekday_unverified_timezone']:
        lines += [f'## {name}', '', '| Grupo | Fragmentos | P&L estimado USD | PF por signo | WR etiquetas |', '|---|---:|---:|---:|---:|']
        for key, values in result[name].items():
            pf = f"{values['pf_by_sign']:.3f}" if values['pf_by_sign'] is not None else 'N/D'
            lines.append(f"| {key} | {values['fragments']} | {values['estimated_pnl_usd']:.2f} | {pf} | {values['win_rate_original_pct']:.1f}% |")
        lines.append('')
    (destination / 'METRICAS_EXPORTACION.md').write_text('\n'.join(lines), encoding='utf-8')
    print(json.dumps({k: result[k] for k in ['status', 'csv_json_equal', 'candidate_entry_groups_not_positions', 'exact_duplicate_row_numbers_1_based', 'overall']}, indent=2))


if __name__ == '__main__':
    main()
