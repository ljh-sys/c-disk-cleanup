#!/usr/bin/env python3
"""Generate C Drive Cleanup Report - AnySearch-style, category-grouped, no checkboxes."""
import json
import os
from collections import OrderedDict

TEMPLATE = '''<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>C盘清理分析报告</title>
<style>
:root {
  --bg: #fff; --text: #101010; --text-secondary: #666;
  --border: #10101012; --hover-bg: #f5f7fa;
  --safe: #22c55e; --safe-bg: #f0fdf4;
  --confirm: #f59e0b; --confirm-bg: #fffbeb;
  --danger: #ef4444; --danger-bg: #fef2f2;
  --sidebar-w: 240px;
}
* { margin: 0; padding: 0; box-sizing: border-box; }
body { font-family: Inter, "Segoe UI", "PingFang SC", "Noto Sans SC", sans-serif; background: var(--bg); color: var(--text); line-height: 1.6; -webkit-font-smoothing: antialiased; }

/* Hero header */
.hero { position: sticky; top: 0; z-index: 100; background: rgba(255,255,255,0.88); backdrop-filter: blur(16px); border-bottom: 1px solid var(--border); }
.hero-inner { display: flex; align-items: center; gap: 24px; padding: 14px 24px; flex-wrap: wrap; }
.hero-brand { font-size: 16px; font-weight: 600; letter-spacing: -0.01em; white-space: nowrap; }
.hero-stat { font-size: 13px; color: var(--text-secondary); white-space: nowrap; }
.hero-stat b { color: var(--text); font-weight: 500; }
.hero-stat .dot { display: inline-block; width: 6px; height: 6px; border-radius: 50%; margin-right: 4px; vertical-align: middle; }
.dot.safe { background: var(--safe); } .dot.confirm { background: var(--confirm); } .dot.danger { background: var(--danger); }
.hero-bar-wrap { padding: 0 24px 10px; display: flex; align-items: center; gap: 12px; }
.hero-bar { flex: 1; height: 3px; background: #1010100d; border-radius: 2px; overflow: hidden; }
.hero-bar-fill { height: 100%; border-radius: 2px; background: #101010; transition: width .4s; }
.hero-bar-lbl { font-size: 11px; color: var(--text-secondary); white-space: nowrap; }

/* Lang switcher */
.lang-switch { display: inline-flex; align-items: center; gap: 4px; margin-left: auto; flex-shrink: 0; }
.lang-switch button { position: relative; z-index: 1; font-size: 12px; padding: 3px 10px; border: 1px solid var(--border); border-radius: 5px; background: var(--bg); color: var(--text-secondary); cursor: pointer; transition: all .15s; font-family: inherit; }
.lang-switch button:hover { color: var(--text); border-color: #10101040; }
.lang-switch button.active { background: #101010; color: #fff; border-color: #101010; pointer-events: none; }

/* Legend inline */
.hero-legend { display: flex; gap: 12px; font-size: 11px; color: var(--text-secondary); padding: 0 24px 10px; }
.hero-legend span { display: flex; align-items: center; gap: 4px; }
.hero-legend .dot { width: 7px; height: 7px; border-radius: 50%; }
.d-safe { background: var(--safe); } .d-confirm { background: var(--confirm); } .d-danger { background: var(--danger); }

/* Layout: sidebar + content */
.layout { display: flex; }
.sidebar { width: var(--sidebar-w); flex-shrink: 0; position: sticky; top: 110px; height: calc(100vh - 110px); overflow-y: auto; border-right: 1px solid var(--border); padding: 20px 0; background: var(--bg); }
.sidebar-title { font-size: 11px; font-weight: 500; color: var(--text-secondary); text-transform: uppercase; letter-spacing: .05em; padding: 0 20px 12px; }
.sidebar-nav { list-style: none; }
.sidebar-nav a { display: flex; align-items: center; gap: 8px; padding: 6px 20px; font-size: 13px; color: var(--text-secondary); text-decoration: none; transition: all .12s; border-left: 2px solid transparent; }
.sidebar-nav a:hover { color: var(--text); background: var(--hover-bg); }
.sidebar-nav a.active { color: var(--text); font-weight: 500; background: var(--hover-bg); border-left-color: #101010; }
.sidebar-nav .s-dot { width: 6px; height: 6px; border-radius: 50%; flex-shrink: 0; }
.sidebar-nav .s-size { font-size: 11px; color: var(--text-secondary); margin-left: auto; font-variant-numeric: tabular-nums; }
.sidebar-nav .s-count { font-size: 11px; color: var(--text-secondary); }

/* Main content */
.main { flex: 1; min-width: 0; padding: 0 36px 50vh; overflow-x: auto; }

/* Category section */
.cat-section { margin-top: 36px; scroll-margin-top: 120px; }
.cat-header { display: flex; align-items: baseline; gap: 12px; margin-bottom: 10px; }
.cat-header h2 { font-size: 18px; font-weight: 500; letter-spacing: -0.01em; }
.cat-header .cat-meta { font-size: 12px; color: var(--text-secondary); }
.cat-header .cat-meta b { color: var(--text); }

/* Table */
.table-wrap { border: 1px solid var(--border); border-radius: 10px; overflow: hidden; }
table { width: 100%; border-collapse: separate; border-spacing: 0; table-layout: fixed; }
th, td { padding: 10px 14px; text-align: left; border-bottom: 1px solid var(--border); font-size: 13px; overflow: hidden; text-overflow: ellipsis; }
th { background: #fafafa; font-weight: 500; font-size: 12px; color: var(--text-secondary); letter-spacing: .03em; }
tr:last-child td { border-bottom: none; }
tr:hover { background: var(--hover-bg); }

/* Column widths - all % to keep headers aligned */
.col-risk { width: 12%; min-width: 84px; }
.col-path { width: 32%; }
.col-size { width: 12%; min-width: 84px; }
.col-desc { width: 44%; }

/* Risk badge */
.badge { display: inline-flex; padding: 2px 8px; border-radius: 4px; font-size: 11px; font-weight: 500; }
.b-safe { background: var(--safe-bg); color: #16a34a; }
.b-confirm { background: var(--confirm-bg); color: #d97706; }
.b-danger { background: var(--danger-bg); color: #dc2626; }

.size { font-weight: 500; font-variant-numeric: tabular-nums; white-space: nowrap; }
.path-mono { font-family: "SF Mono", "Cascadia Code", "Consolas", monospace; font-size: 11px; color: var(--text-secondary); word-break: break-all; }
.path-name { font-size: 13px; }

.footer { padding: 20px 0; margin-top: 48px; border-top: 1px solid var(--border); text-align: center; font-size: 12px; color: var(--text-secondary); }

@media (max-width: 860px) {
  .layout { flex-direction: column; }
  .sidebar { position: static; width: 100%; height: auto; border-right: none; border-bottom: 1px solid var(--border); padding: 10px 0; }
  .sidebar-nav { display: flex; flex-wrap: wrap; gap: 4px; padding: 0 16px; }
  .sidebar-nav a { border-left: none; border-radius: 5px; padding: 5px 10px; font-size: 12px; }
  .sidebar-nav a.active { border-left: none; }
  .main { padding: 0 16px 35vh; }
  .hero-inner { gap: 12px; }
  .hero-brand { font-size: 14px; }
  .hero-stat { font-size: 11px; }
  .col-desc { width: 35%; }
}
</style>
</head>
<body>

<header class="hero">
  <div class="hero-inner">
    <div class="hero-brand" data-i18n="report_title">C盘清理分析报告</div>
    <div class="hero-stat">__SCAN_TIME__</div>
    <div class="hero-stat"><span data-i18n="total_disk">总</span> <b>__TOTAL_GB__ GB</b></div>
    <div class="hero-stat"><span data-i18n="used">已用</span> <b>__USED_GB__ GB</b></div>
    <div class="hero-stat" style="color:#22c55e"><span data-i18n="free">剩余</span> <b style="color:#22c55e">__FREE_GB__ GB</b></div>

    <div class="hero-stat"><span class="dot safe"></span><span data-i18n="safe">安全</span> <b>__SAFE_COUNT__</b> <span data-i18n="items">项</span> <span style="color:var(--text-secondary)">(__SAFE_TOTAL_GB__ GB)</span></div>
    <div class="hero-stat"><span class="dot confirm"></span><span data-i18n="need_confirm">需确认</span> <b>__CONFIRM_COUNT__</b> <span data-i18n="items">项</span> <span style="color:var(--text-secondary)">(__CONFIRM_TOTAL_GB__ GB)</span></div>
    <div class="hero-stat"><span class="dot danger"></span><span data-i18n="danger_note">危险勿删</span> <b>__DANGER_COUNT__</b> <span data-i18n="items">项</span> <span style="color:var(--text-secondary)">(__DANGER_TOTAL__ GB)</span></div>
    <div class="lang-switch"><button onclick="setLang('zh')" id="btn-zh" class="active">中</button><button onclick="setLang('en')" id="btn-en">EN</button></div>
  </div>
  <div class="hero-bar-wrap">
    <div class="hero-bar"><div class="hero-bar-fill" style="width:__USAGE_PCT__%"></div></div>
    <div class="hero-bar-lbl"><span data-i18n="scanned_items">扫描</span> __TOTAL_ITEMS__ <span data-i18n="items">项</span> · <span data-i18n="safe_delete">安全可删</span> __SAFE_TOTAL__ MB</div>
  </div>
  <div class="hero-legend">
    <span><span class="dot d-safe"></span><span data-i18n="safe_delete">安全可删</span></span>
    <span><span class="dot d-confirm"></span><span data-i18n="need_confirm">需确认</span></span>
    <span><span class="dot d-danger"></span><span data-i18n="danger_note">危险勿删</span></span>
  </div>
</header>

<div class="layout">

<aside class="sidebar">
  <div class="sidebar-title" data-i18n="categories_title">目录</div>
  <ul class="sidebar-nav" id="sidebar-nav">
    __SIDEBAR_ITEMS__
  </ul>
</aside>

<div class="main">

__CATEGORY_SECTIONS__


<div class="footer"><span data-i18n="footer_text">C盘清理分析报告 · 由 Claude Code 自动生成</span></div>

</div>
</div>
<script>
const I18N = {
  zh: {
    c_usage: 'C盘使用率', used_space: '已用空间', free_space: '剩余空间', scanned_items: '扫描项目',
    safe_delete: '安全可删', need_confirm: '需确认', danger_note: '危险勿删',
    risk: '风险', path: '路径', size: '大小', desc: '说明',
    safe: '安全', danger: '危险',
    items: '项', total: '共', used: '已用', free: '剩余', usage: '使用率',
    report_title: 'C盘清理分析报告', total_disk: '总', categories_title: '目录',
    footer_text: 'C盘清理分析报告 · 由 Claude Code 自动生成',
    danger_items_label: '危险勿删'
  },
  en: {
    c_usage: 'C Drive Usage', used_space: 'Used Space', free_space: 'Free Space', scanned_items: 'Scanned Items',
    safe_delete: 'Safe to Delete', need_confirm: 'Need Confirm', danger_note: 'Danger - Do NOT Delete',
    risk: 'Risk', path: 'Path', size: 'Size', desc: 'Description',
    safe: 'Safe', danger: 'Danger',
    items: 'items', total: 'total', used: 'Used', free: 'Free', usage: 'Usage',
    report_title: 'C Drive Cleanup Report', total_disk: 'Total', categories_title: 'Categories',
    footer_text: 'C Drive Cleanup Report · Generated by Claude Code',
    danger_items_label: 'Danger - Do NOT Delete'
  }
};

function setLang(lang) {
  document.documentElement.lang = lang === 'en' ? 'en' : 'zh-CN';
  document.querySelectorAll('#btn-zh, #btn-en').forEach(b => b.classList.remove('active'));
  const btn = document.getElementById('btn-' + lang);
  if (btn) btn.classList.add('active');
  localStorage.setItem('cleanup-report-lang', lang);
  document.querySelectorAll('[data-i18n]').forEach(el => {
    const key = el.getAttribute('data-i18n');
    if (I18N[lang] && I18N[lang][key]) el.textContent = I18N[lang][key];
  });
}

(function() {
  const saved = localStorage.getItem('cleanup-report-lang');
  if (saved) setLang(saved);
})();

// Scroll spy
(function() {
  const links = document.querySelectorAll('.sidebar-nav .s-link');
  const sections = [...links].map(a => document.querySelector(a.getAttribute('href')));
  const offset = 130;
  function onScroll() {
    let current = sections[0];
    for (const sec of sections) {
      if (!sec) continue;
      if (sec.getBoundingClientRect().top <= offset) current = sec;
    }
    links.forEach(a => a.classList.remove('active'));
    const activeLink = document.querySelector(`.sidebar-nav a[href="#${current.id}"]`);
    if (activeLink) activeLink.classList.add('active');
  }
  window.addEventListener('scroll', onScroll, {passive: true});
  onScroll();
})();
</script>
</body>
</html>'''


def ai_desc(real_path, name, cat, size_mb, ai_descriptions=None):
    """Get description and risk from AI cache; marks items needing AI if not cached."""
    if ai_descriptions and real_path in ai_descriptions:
        entry = ai_descriptions[real_path]
        desc = entry if isinstance(entry, str) else entry.get('description', '')
        risk = entry.get('risk', 'confirm') if isinstance(entry, dict) else 'confirm'
        return desc, risk, True

    # Not in cache — needs AI
    if size_mb > 1024:
        return f'大型目录（>{size_mb/1024:.1f}GB），建议检查后确认是否删除', 'confirm', False
    elif size_mb > 500:
        return '较大目录，建议确认内容后决定', 'confirm', False
    return '待 AI 分析', 'confirm', False



def main():
    up = os.environ['USERPROFILE']
    template_path = os.path.join(up, '.claude', 'skills', 'c-disk-cleanup', 'report-template.html')
    data_path = os.path.join(up, '.cleanup', 'data.json')
    report_path = os.path.join(up, 'Desktop', 'C盘清理分析报告.html')

    # Write template
    with open(template_path, 'w', encoding='utf-8') as f:
        f.write(TEMPLATE)
    print(f'Template written: {len(TEMPLATE)} chars')

    # Read data
    with open(data_path, 'r', encoding='utf-8-sig') as f:
        data = json.load(f)

    # Load AI descriptions cache
    ai_desc_path = os.path.join(up, '.cleanup', 'ai-descriptions.json')
    ai_descriptions = {}
    if os.path.exists(ai_desc_path):
        with open(ai_desc_path, 'r', encoding='utf-8') as f:
            ai_descriptions = json.load(f)

    cd = data['c_drive']
    summary = data['summary']
    items = data.get('items', [])

    # Recalculate summary from AI risk assignments
    if ai_descriptions:
        safe_c = confirm_c = danger_c = 0
        safe_mb = confirm_mb = danger_mb = 0.0
        for item in items:
            rp = item.get('real_path', '')
            risk = item.get('risk', 'confirm')
            if rp in ai_descriptions:
                entry = ai_descriptions[rp]
                if isinstance(entry, dict) and 'risk' in entry:
                    risk = entry['risk']
            mb = item.get('size_mb', 0)
            if risk == 'safe':
                safe_c += 1; safe_mb += mb
            elif risk == 'danger':
                danger_c += 1; danger_mb += mb
            else:
                confirm_c += 1; confirm_mb += mb
        summary = {
            'safe_items': safe_c, 'safe_total_mb': round(safe_mb),
            'confirm_items': confirm_c, 'confirm_total_mb': round(confirm_mb),
            'danger_items': danger_c, 'danger_total_mb': round(danger_mb),
            'total_items': len(items)
        }

    # Group items by category, preserving order of first occurrence
    cat_order = []
    cat_items = OrderedDict()
    for item in items:
        cat = item.get('category', 'Other')
        if cat not in cat_items:
            cat_items[cat] = []
            cat_order.append(cat)
        cat_items[cat].append(item)

    # Sort items within each category: risk (safe→confirm→danger), then size desc
    risk_sort = {'safe': 0, 'confirm': 1, 'danger': 2}
    for cat in cat_items:
        cat_items[cat].sort(key=lambda x: (
            risk_sort.get(
                ai_descriptions.get(x.get('real_path', ''), {}).get('risk', 'confirm') if isinstance(ai_descriptions.get(x.get('real_path', ''), {}), dict) else 'confirm',
                1
            ),
            -x.get('size_mb', 0)
        ))

    # Calculate totals per category
    cat_totals = {}
    for cat, lst in cat_items.items():
        cat_totals[cat] = sum(i.get('size_mb', 0) for i in lst)

    # Build sidebar nav items
    sidebar_items = []
    for cat in cat_order:
        total = cat_totals[cat]
        total_disp = f'{total/1024:.1f} GB' if total >= 1024 else f'{total:.0f} MB'
        cat_id = cat.replace(' ', '-').replace('/', '-')
        lst = cat_items[cat]
        # Determine dominant risk for dot color
        risks = [i.get('risk', 'confirm') for i in lst]
        has_danger = 'danger' in risks
        has_confirm = 'confirm' in risks
        dot_class = 'danger' if has_danger else ('confirm' if has_confirm else 'safe')
        sidebar_items.append(f'<li><a href="#cat-{cat_id}" class="s-link"><span class="s-dot d-{dot_class}"></span>{cat}<span class="s-count">{len(lst)} <span data-i18n="items">项</span></span><span class="s-size">{total_disp}</span></a></li>')
    sidebar_html = '\n'.join(sidebar_items)

    # Build category sections
    sections = []
    ai_needed = []
    for cat in cat_order:
        lst = cat_items[cat]
        total = cat_totals[cat]
        total_disp = f'{total/1024:.1f} GB' if total >= 1024 else f'{total:.0f} MB'
        cat_id = cat.replace(' ', '-').replace('/', '-')

        rows = []
        for item in lst:
            path_str = item.get('path', '')
            real_path = item.get('real_path', '')
            size_disp = item.get('size_display', '')
            size_mb = item.get('size_mb', 0)
            name = real_path.split('\\')[-1] if '\\' in real_path else real_path
            desc, risk, from_cache = ai_desc(real_path, name, cat, size_mb, ai_descriptions)
            if not from_cache:
                ai_needed.append({
                    'real_path': real_path,
                    'name': name,
                    'category': cat,
                    'size_mb': size_mb,
                    'size_display': size_disp,
                })
            risk_label = {'safe': '安全', 'confirm': '需确认', 'danger': '危险'}.get(risk, risk)
            risk_i18n = {'safe': 'safe', 'confirm': 'need_confirm', 'danger': 'danger'}.get(risk, risk)
            lm = item.get('last_modified', '')
            meta = f' <small style="color:var(--text-secondary)">({lm})</small>' if lm else ''

            rows.append(f'''    <tr>
      <td class="col-risk"><span class="badge b-{risk}" data-i18n="{risk_i18n}">{risk_label}</span></td>
      <td class="col-path"><span class="path-name">{path_str}</span><br><span class="path-mono">{real_path}</span></td>
      <td class="col-size size">{size_disp}</td>
      <td class="col-desc">{desc}{meta}</td>
    </tr>''')

        section_html = f'''<div class="cat-section" id="cat-{cat_id}">
  <div class="cat-header">
    <h2>{cat}</h2>
    <div class="cat-meta">{len(lst)} <span data-i18n="items">项</span> · <span data-i18n="total">共</span> <b>{total_disp}</b></div>
  </div>
  <div class="table-wrap">
    <table>
      <thead><tr><th class="col-risk" data-i18n="risk">风险</th><th class="col-path" data-i18n="path">路径</th><th class="col-size" data-i18n="size">大小</th><th class="col-desc" data-i18n="desc">说明</th></tr></thead>
      <tbody>
{chr(10).join(rows)}
      </tbody>
    </table>
  </div>
</div>'''
        sections.append(section_html)

    # Read template and replace
    with open(template_path, 'r', encoding='utf-8') as f:
        html = f.read()

    html = html.replace('__SCAN_TIME__', data.get('scan_time', ''))
    html = html.replace('__SCAN_DURATION__', str(data.get('scan_duration_seconds', '')))
    html = html.replace('__TOTAL_GB__', str(cd.get('total_gb', '')))
    html = html.replace('__USAGE_PCT__', str(cd.get('usage_percent', '')))
    html = html.replace('__USED_GB__', str(cd.get('used_gb', '')))
    html = html.replace('__FREE_GB__', str(cd.get('free_gb', '')))
    html = html.replace('__SAFE_COUNT__', str(summary.get('safe_items', 0)))
    html = html.replace('__SAFE_TOTAL__', str(summary.get('safe_total_mb', 0)))
    html = html.replace('__CONFIRM_COUNT__', str(summary.get('confirm_items', 0)))
    html = html.replace('__DANGER_COUNT__', str(summary.get('danger_items', 0)))
    safe_total_gb = round(summary.get('safe_total_mb', 0) / 1024, 1)
    html = html.replace('__SAFE_TOTAL_GB__', str(safe_total_gb))
    confirm_total_gb = round(summary.get('confirm_total_mb', 0) / 1024, 1)
    html = html.replace('__CONFIRM_TOTAL_GB__', str(confirm_total_gb))
    danger_total_gb = round(summary.get('danger_total_mb', 0) / 1024, 1)
    html = html.replace('__DANGER_TOTAL__', str(danger_total_gb))
    html = html.replace('__TOTAL_ITEMS__', str(summary.get('total_items', 0)))
    html = html.replace('__SIDEBAR_ITEMS__', sidebar_html)
    html = html.replace('__CATEGORY_SECTIONS__', '\n'.join(sections))

    with open(report_path, 'w', encoding='utf-8-sig') as f:
        f.write(html)
    print(f'Report saved: {report_path}')

    # Write AI-needed list
    if ai_needed:
        ai_needed_path = os.path.join(up, '.cleanup', 'ai-needed.json')
        with open(ai_needed_path, 'w', encoding='utf-8') as f:
            json.dump(ai_needed, f, ensure_ascii=False, indent=2)
        print(f'AI descriptions needed: {len(ai_needed)} items → {ai_needed_path}')
    else:
        print('All descriptions covered (lookup table + AI cache)')


if __name__ == '__main__':
    main()
