import json
import os

def generate_html():
    json_path = r"c:\Users\AurumArch\Documents\PROYECTOS\aurumcapital-mt5\scratch\trade_history_complete.json"
    html_path = r"c:\Users\AurumArch\Documents\PROYECTOS\aurumcapital-mt5\DASHBOARD_HISTORICO_TRADES.html"
    
    with open(json_path, 'r', encoding='utf-8') as f:
        trades = json.load(f)
        
    trades_json_str = json.dumps(trades)
    
    html_content = f"""<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Aurum Capital - Auditoría Forense y Dashboard de Trades</title>
    <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;600;700;800&family=JetBrains+Mono:wght@400;500;600&display=swap" rel="stylesheet">
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        :root {{
            --bg-primary: #0a0d14;
            --bg-card: rgba(18, 24, 38, 0.75);
            --bg-card-hover: rgba(26, 35, 56, 0.85);
            --border-color: rgba(255, 215, 0, 0.15);
            --border-glow: rgba(255, 215, 0, 0.35);
            --gold: #FFD700;
            --gold-gradient: linear-gradient(135deg, #FFD700 0%, #FFA500 100%);
            --green: #00E676;
            --red: #FF3D71;
            --cyan: #00E5FF;
            --purple: #B388FF;
            --text-main: #F0F4F8;
            --text-muted: #8E9CAE;
        }}

        * {{
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }}

        body {{
            font-family: 'Outfit', sans-serif;
            background: var(--bg-primary);
            color: var(--text-main);
            min-height: 100vh;
            padding: 2rem 1.5rem;
            background-image: 
                radial-gradient(circle at 10% 20%, rgba(255, 215, 0, 0.05) 0%, transparent 40%),
                radial-gradient(circle at 90% 80%, rgba(0, 229, 255, 0.04) 0%, transparent 40%);
            background-attachment: fixed;
        }}

        .container {{
            max-width: 1400px;
            margin: 0 auto;
        }}

        /* Header */
        header {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding-bottom: 2rem;
            border-bottom: 1px solid var(--border-color);
            margin-bottom: 2rem;
            flex-wrap: wrap;
            gap: 1.5rem;
        }}

        .logo-box {{
            display: flex;
            align-items: center;
            gap: 1rem;
        }}

        .logo-icon {{
            width: 48px;
            height: 48px;
            background: var(--gold-gradient);
            border-radius: 12px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-weight: 800;
            font-size: 1.5rem;
            color: #000;
            box-shadow: 0 0 20px rgba(255, 215, 0, 0.3);
        }}

        h1 {{
            font-size: 1.8rem;
            font-weight: 700;
            letter-spacing: -0.5px;
            background: linear-gradient(90deg, #FFFFFF, var(--gold));
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }}

        .subtitle {{
            font-size: 0.9rem;
            color: var(--text-muted);
            margin-top: 0.2rem;
        }}

        .badge-live {{
            background: rgba(0, 230, 118, 0.15);
            color: var(--green);
            border: 1px solid rgba(0, 230, 118, 0.3);
            padding: 0.4rem 0.9rem;
            border-radius: 20px;
            font-size: 0.8rem;
            font-weight: 600;
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }}

        .badge-live::before {{
            content: '';
            width: 8px;
            height: 8px;
            background: var(--green);
            border-radius: 50%;
            box-shadow: 0 0 8px var(--green);
        }}

        /* KPI Grid */
        .kpi-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
            gap: 1.25rem;
            margin-bottom: 2rem;
        }}

        .kpi-card {{
            background: var(--bg-card);
            backdrop-filter: blur(12px);
            border: 1px solid var(--border-color);
            border-radius: 16px;
            padding: 1.5rem;
            position: relative;
            overflow: hidden;
            transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
        }}

        .kpi-card:hover {{
            transform: translateY(-4px);
            border-color: var(--border-glow);
            box-shadow: 0 8px 24px rgba(0, 0, 0, 0.4);
        }}

        .kpi-card::before {{
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 3px;
            background: var(--gold-gradient);
            opacity: 0.7;
        }}

        .kpi-title {{
            font-size: 0.8rem;
            font-weight: 500;
            text-transform: uppercase;
            letter-spacing: 1px;
            color: var(--text-muted);
            margin-bottom: 0.5rem;
        }}

        .kpi-value {{
            font-size: 1.9rem;
            font-weight: 800;
            font-family: 'JetBrains Mono', monospace;
            color: #FFF;
        }}

        .kpi-sub {{
            font-size: 0.8rem;
            margin-top: 0.4rem;
            display: flex;
            align-items: center;
            gap: 0.4rem;
        }}

        .text-green {{ color: var(--green); }}
        .text-red {{ color: var(--red); }}
        .text-gold {{ color: var(--gold); }}
        .text-cyan {{ color: var(--cyan); }}

        /* Charts Grid */
        .charts-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(600px, 1fr));
            gap: 1.5rem;
            margin-bottom: 2rem;
        }}

        @media (max-width: 768px) {{
            .charts-grid {{ grid-template-columns: 1fr; }}
        }}

        .chart-card {{
            background: var(--bg-card);
            backdrop-filter: blur(12px);
            border: 1px solid var(--border-color);
            border-radius: 16px;
            padding: 1.5rem;
        }}

        .chart-header {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 1.25rem;
        }}

        .chart-title {{
            font-size: 1.1rem;
            font-weight: 600;
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }}

        .chart-container {{
            position: relative;
            height: 300px;
            width: 100%;
        }}

        /* Table Section */
        .table-section {{
            background: var(--bg-card);
            backdrop-filter: blur(12px);
            border: 1px solid var(--border-color);
            border-radius: 16px;
            padding: 1.5rem;
            margin-bottom: 2rem;
        }}

        .table-controls {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 1rem;
            flex-wrap: wrap;
            gap: 1rem;
        }}

        .search-box input, select {{
            background: rgba(255, 255, 255, 0.05);
            border: 1px solid var(--border-color);
            color: #FFF;
            padding: 0.5rem 1rem;
            border-radius: 8px;
            font-family: inherit;
            font-size: 0.9rem;
            outline: none;
        }}

        .search-box input:focus, select:focus {{
            border-color: var(--gold);
        }}

        .table-wrapper {{
            overflow-x: auto;
            max-height: 480px;
        }}

        table {{
            width: 100%;
            border-collapse: collapse;
            font-size: 0.85rem;
            text-align: left;
        }}

        th {{
            background: rgba(0, 0, 0, 0.3);
            color: var(--text-muted);
            font-weight: 600;
            padding: 0.75rem 1rem;
            text-transform: uppercase;
            font-size: 0.75rem;
            letter-spacing: 0.5px;
            position: sticky;
            top: 0;
            z-index: 10;
        }}

        td {{
            padding: 0.75rem 1rem;
            border-bottom: 1px solid rgba(255, 255, 255, 0.05);
            font-family: 'JetBrains Mono', monospace;
        }}

        tr:hover td {{
            background: var(--bg-card-hover);
        }}

        .badge-win {{
            background: rgba(0, 230, 118, 0.15);
            color: var(--green);
            padding: 0.2rem 0.5rem;
            border-radius: 4px;
            font-weight: 600;
        }}

        .badge-loss {{
            background: rgba(255, 61, 113, 0.15);
            color: var(--red);
            padding: 0.2rem 0.5rem;
            border-radius: 4px;
            font-weight: 600;
        }}

        .badge-be {{
            background: rgba(255, 215, 0, 0.15);
            color: var(--gold);
            padding: 0.2rem 0.5rem;
            border-radius: 4px;
            font-weight: 600;
        }}

        /* Key Findings Callout */
        .findings-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 1.25rem;
            margin-bottom: 2rem;
        }}

        .finding-box {{
            background: rgba(18, 24, 38, 0.6);
            border-left: 4px solid var(--gold);
            padding: 1.2rem;
            border-radius: 0 12px 12px 0;
        }}

        .finding-title {{
            font-weight: 700;
            margin-bottom: 0.4rem;
            color: var(--gold);
        }}

        .finding-desc {{
            font-size: 0.85rem;
            line-height: 1.5;
            color: var(--text-muted);
        }}
    </style>
</head>
<body>
    <div class="container">
        <header>
            <div class="logo-box">
                <div class="logo-icon">A</div>
                <div>
                    <h1>AURUM CAPITAL AI TRADING DESK</h1>
                    <div class="subtitle">Auditoría Forense Histórica de Logs MT5 & Roadmap de Seguimiento (893 Trades Reconstruidos)</div>
                </div>
            </div>
            <div class="badge-live">MOTOR DE AUDITORÍA SINCRONIZADO</div>
        </header>

        <!-- KPI Summary Cards -->
        <div class="kpi-grid">
            <div class="kpi-card">
                <div class="kpi-title">Total Operaciones</div>
                <div class="kpi-value" id="kpi-total">893</div>
                <div class="kpi-sub"><span class="text-gold">Ene - Sep 2026</span> (1,284 deals)</div>
            </div>
            <div class="kpi-card">
                <div class="kpi-title">Win Rate Global</div>
                <div class="kpi-value text-green" id="kpi-wr">41.3%</div>
                <div class="kpi-sub"><span class="text-green">369 Wins</span> / <span class="text-red">418 Loss</span> / 106 BE</div>
            </div>
            <div class="kpi-card">
                <div class="kpi-title">Beneficio Bruto Ganado</div>
                <div class="kpi-value text-cyan" id="kpi-gross-win">+$1,019.16</div>
                <div class="kpi-sub">Ganancia media: <span class="text-green">+$2.76 / win</span></div>
            </div>
            <div class="kpi-card">
                <div class="kpi-title">Pérdida Bruta Sufrida</div>
                <div class="kpi-value text-red" id="kpi-gross-loss">-$1,349.89</div>
                <div class="kpi-sub">Pérdida media: <span class="text-red">-$3.23 / loss</span></div>
            </div>
            <div class="kpi-card">
                <div class="kpi-title">Profit Factor</div>
                <div class="kpi-value text-gold" id="kpi-pf">0.75</div>
                <div class="kpi-sub">Payoff Ratio: <span class="text-gold">0.86</span></div>
            </div>
        </div>

        <!-- Key Findings -->
        <div class="findings-grid">
            <div class="finding-box" style="border-left-color: var(--green);">
                <div class="finding-title" style="color: var(--green);">⚡ Duración Óptima (5 - 30 min)</div>
                <div class="finding-desc">Los scalps cerrados entre 5 y 30 min acumulan <strong>+$38.80 USD</strong> netos. En contraste, las posiciones retenidas > 2 horas perdieron <strong>-$250.82 USD</strong>. Solución V14: <em>Candle-Trailing Stop a 4 velas</em>.</div>
            </div>
            <div class="finding-box" style="border-left-color: var(--cyan);">
                <div class="finding-title" style="color: var(--cyan);">🏆 Activo Estrella: EURUSD Estándar</div>
                <div class="finding-desc">EURUSD estándar logró un <strong>70.6% de Win Rate</strong> y <strong>Profit Factor de 4.80</strong> (+44.23 USD). Los pares micro de Forex sufrieron fricción de spread.</div>
            </div>
            <div class="finding-box" style="border-left-color: var(--gold);">
                <div class="finding-title" style="color: var(--gold);">📅 Ventana Semanal Crítica</div>
                <div class="finding-desc">El <strong>Martes fue el día más rentable (+115.18 USD)</strong>, mientras que el <strong>Viernes acumuló -$231.20 USD</strong> de pérdidas. Validación total del <em>Filtro de Viernes (V12.96+)</em>.</div>
            </div>
            <div class="finding-box" style="border-left-color: var(--red);">
                <div class="finding-title" style="color: var(--red);">⏰ Zonas Rojas Horarias</div>
                <div class="finding-desc">Las horas de noticias de EE.UU. (12:00-14:00 Servidor) sufrieron <strong>-$357.08 USD</strong> de drawdown. Las mejores entradas ocurrieron en aperturas de Londres (06-07:00) y NY (10-11:00).</div>
            </div>
        </div>

        <!-- Charts Row 1 -->
        <div class="charts-grid">
            <div class="chart-card">
                <div class="chart-header">
                    <div class="chart-title">Curva de Equidad Acumulada (893 Trades)</div>
                </div>
                <div class="chart-container">
                    <canvas id="equityChart"></canvas>
                </div>
            </div>
            <div class="chart-card">
                <div class="chart-header">
                    <div class="chart-title">P&L Neto por Instrumento (USD)</div>
                </div>
                <div class="chart-container">
                    <canvas id="symbolChart"></canvas>
                </div>
            </div>
        </div>

        <!-- Charts Row 2 -->
        <div class="charts-grid">
            <div class="chart-card">
                <div class="chart-header">
                    <div class="chart-title">P&L según Duración de la Posición</div>
                </div>
                <div class="chart-container">
                    <canvas id="durationChart"></canvas>
                </div>
            </div>
            <div class="chart-card">
                <div class="chart-header">
                    <div class="chart-title">P&L por Día de la Semana</div>
                </div>
                <div class="chart-container">
                    <canvas id="dowChart"></canvas>
                </div>
            </div>
        </div>

        <!-- Table of Trades -->
        <div class="table-section">
            <div class="table-controls">
                <div class="chart-title">Historial Completo de Operaciones Auditadas</div>
                <div style="display: flex; gap: 0.75rem; align-items: center;">
                    <select id="filter-symbol" onchange="filterTable()">
                        <option value="ALL">Todos los Símbolos</option>
                        <option value="GOLDmicro">GOLDmicro</option>
                        <option value="GOLD">GOLD</option>
                        <option value="EURUSD">EURUSD</option>
                        <option value="EURUSDmicro">EURUSDmicro</option>
                        <option value="USDJPYmicro">USDJPYmicro</option>
                        <option value="USDJPY">USDJPY</option>
                        <option value="GBPUSD">GBPUSD</option>
                        <option value="BTCUSD">BTCUSD</option>
                    </select>
                    <select id="filter-outcome" onchange="filterTable()">
                        <option value="ALL">Todos los Resultados</option>
                        <option value="WIN">Solo Ganadoras (WIN)</option>
                        <option value="LOSS">Solo Perdedoras (LOSS)</option>
                        <option value="BE">Solo Break-Even (BE)</option>
                    </select>
                    <div class="search-box">
                        <input type="text" id="search-input" placeholder="Buscar fecha, ticket, precio..." oninput="filterTable()">
                    </div>
                </div>
            </div>
            <div class="table-wrapper">
                <table id="trades-table">
                    <thead>
                        <tr>
                            <th>#</th>
                            <th>Entrada</th>
                            <th>Salida</th>
                            <th>Símbolo</th>
                            <th>Tipo</th>
                            <th>Vol</th>
                            <th>Precio In</th>
                            <th>Precio Out</th>
                            <th>Duración</th>
                            <th>P&L (USD)</th>
                            <th>Estado</th>
                        </tr>
                    </thead>
                    <tbody id="table-body">
                        <!-- Populated by JS -->
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    <script>
        const allTrades = {trades_json_str};

        // Populate Table
        function renderTable(tradesToRender) {{
            const tbody = document.getElementById('table-body');
            tbody.innerHTML = '';
            
            // Limit render to first 100 for performance if list is long
            const displayList = tradesToRender.slice(-150).reverse();
            displayList.forEach((t, i) => {{
                const tr = document.createElement('tr');
                const badgeClass = t.outcome === 'WIN' ? 'badge-win' : (t.outcome === 'LOSS' ? 'badge-loss' : 'badge-be');
                const pnlClass = t.pnl_usd > 0 ? 'text-green' : (t.pnl_usd < 0 ? 'text-red' : 'text-gold');
                
                tr.innerHTML = `
                    <td>${{tradesToRender.length - i}}</td>
                    <td>${{t.entry_time}}</td>
                    <td>${{t.exit_time}}</td>
                    <td><strong>${{t.symbol}}</strong></td>
                    <td style="color: ${{t.direction === 'BUY' ? 'var(--green)' : 'var(--cyan)'}}">${{t.direction}}</td>
                    <td>${{t.volume.toFixed(2)}}</td>
                    <td>${{t.entry_price.toFixed(2)}}</td>
                    <td>${{t.exit_price.toFixed(2)}}</td>
                    <td>${{t.duration_min}} min</td>
                    <td class="${{pnlClass}}" style="font-weight: 700;">${{t.pnl_usd > 0 ? '+' : ''}}${{t.pnl_usd.toFixed(2)}}</td>
                    <td><span class="${{badgeClass}}">${{t.outcome}}</span></td>
                `;
                tbody.appendChild(tr);
            }});
        }}

        function filterTable() {{
            const sym = document.getElementById('filter-symbol').value;
            const out = document.getElementById('filter-outcome').value;
            const q = document.getElementById('search-input').value.toLowerCase();
            
            const filtered = allTrades.filter(t => {{
                if (sym !== 'ALL' && t.symbol !== sym) return false;
                if (out !== 'ALL' && t.outcome !== out) return false;
                if (q) {{
                    const rowText = `${{t.entry_time}} ${{t.symbol}} ${{t.direction}} ${{t.entry_price}} ${{t.exit_price}} ${{t.pnl_usd}}`.toLowerCase();
                    if (!rowText.includes(q)) return false;
                }}
                return true;
            }});
            
            renderTable(filtered);
        }}

        // Initialize Charts
        window.addEventListener('load', () => {{
            renderTable(allTrades);

            // 1. Equity Curve
            let cumPnl = 0;
            const equityPoints = [];
            const labelsEquity = [];
            allTrades.forEach((t, idx) => {{
                cumPnl += t.pnl_usd;
                if (idx % 3 === 0 || idx === allTrades.length - 1) {{
                    equityPoints.push(parseFloat(cumPnl.toFixed(2)));
                    labelsEquity.push(t.entry_time.split(' ')[0]);
                }}
            }});

            new Chart(document.getElementById('equityChart'), {{
                type: 'line',
                data: {{
                    labels: labelsEquity,
                    datasets: [{{
                        label: 'P&L Acumulado (USD)',
                        data: equityPoints,
                        borderColor: '#FFD700',
                        backgroundColor: 'rgba(255, 215, 0, 0.08)',
                        borderWidth: 2,
                        fill: true,
                        tension: 0.2,
                        pointRadius: 0
                    }}]
                }},
                options: {{
                    responsive: true,
                    maintainAspectRatio: false,
                    scales: {{
                        x: {{ grid: {{ color: 'rgba(255,255,255,0.05)' }}, ticks: {{ color: '#8E9CAE', maxTicksLimit: 10 }} }},
                        y: {{ grid: {{ color: 'rgba(255,255,255,0.05)' }}, ticks: {{ color: '#8E9CAE' }} }}
                    }},
                    plugins: {{ legend: {{ display: false }} }}
                }}
            }});

            // 2. Symbol Chart
            const symMap = {{}};
            allTrades.forEach(t => {{
                symMap[t.symbol] = (symMap[t.symbol] || 0) + t.pnl_usd;
            }});
            const sortedSyms = Object.keys(symMap).sort((a,b) => symMap[b] - symMap[a]);
            const symValues = sortedSyms.map(s => parseFloat(symMap[s].toFixed(2)));

            new Chart(document.getElementById('symbolChart'), {{
                type: 'bar',
                data: {{
                    labels: sortedSyms,
                    datasets: [{{
                        data: symValues,
                        backgroundColor: symValues.map(v => v >= 0 ? '#00E676' : '#FF3D71'),
                        borderRadius: 6
                    }}]
                }},
                options: {{
                    responsive: true,
                    maintainAspectRatio: false,
                    scales: {{
                        x: {{ grid: {{ display: false }}, ticks: {{ color: '#8E9CAE' }} }},
                        y: {{ grid: {{ color: 'rgba(255,255,255,0.05)' }}, ticks: {{ color: '#8E9CAE' }} }}
                    }},
                    plugins: {{ legend: {{ display: false }} }}
                }}
            }});

            // 3. Duration Chart
            const durData = [
                {{ label: '< 5 min (Scalp Rápido)', pnl: -2.81 }},
                {{ label: '5-30 min (Scalp Óptimo)', pnl: 38.80 }},
                {{ label: '30-120 min (Day Trade)', pnl: -116.62 }},
                {{ label: '> 2h (Atrapado)', pnl: -250.82 }}
            ];

            new Chart(document.getElementById('durationChart'), {{
                type: 'bar',
                data: {{
                    labels: durData.map(d => d.label),
                    datasets: [{{
                        data: durData.map(d => d.pnl),
                        backgroundColor: durData.map(d => d.pnl >= 0 ? '#00E676' : '#FF3D71'),
                        borderRadius: 6
                    }}]
                }},
                options: {{
                    responsive: true,
                    maintainAspectRatio: false,
                    scales: {{
                        x: {{ grid: {{ display: false }}, ticks: {{ color: '#8E9CAE' }} }},
                        y: {{ grid: {{ color: 'rgba(255,255,255,0.05)' }}, ticks: {{ color: '#8E9CAE' }} }}
                    }},
                    plugins: {{ legend: {{ display: false }} }}
                }}
            }});

            // 4. Day of Week Chart
            const dowData = [
                {{ day: 'Lunes', pnl: -49.05 }},
                {{ day: 'Martes', pnl: 115.18 }},
                {{ day: 'Miércoles', pnl: -145.40 }},
                {{ day: 'Jueves', pnl: 2.21 }},
                {{ day: 'Viernes', pnl: -231.20 }},
                {{ day: 'Domingo', pnl: -23.19 }}
            ];

            new Chart(document.getElementById('dowChart'), {{
                type: 'bar',
                data: {{
                    labels: dowData.map(d => d.day),
                    datasets: [{{
                        data: dowData.map(d => d.pnl),
                        backgroundColor: dowData.map(d => d.pnl >= 0 ? '#FFD700' : '#FF3D71'),
                        borderRadius: 6
                    }}]
                }},
                options: {{
                    responsive: true,
                    maintainAspectRatio: false,
                    scales: {{
                        x: {{ grid: {{ display: false }}, ticks: {{ color: '#8E9CAE' }} }},
                        y: {{ grid: {{ color: 'rgba(255,255,255,0.05)' }}, ticks: {{ color: '#8E9CAE' }} }}
                    }},
                    plugins: {{ legend: {{ display: false }} }}
                }}
            }});
        }});
    </script>
</body>
</html>
"""
    with open(html_path, 'w', encoding='utf-8') as f:
        f.write(html_content)
    print(f"[EXITO] Dashboard interactivo HTML generado en: {html_path}")

if __name__ == '__main__':
    generate_html()
