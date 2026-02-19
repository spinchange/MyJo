# Generate-Dashboard.ps1
# Generates a self-contained HTML dashboard from MyJo journal files.
# Usage: .\Generate-Dashboard.ps1 [-OutputPath path\to\dashboard.html]

param(
    [string]$OutputPath = "$PSScriptRoot\dashboard.html",
    [string]$ConfigPath = "$env:USERPROFILE\.myjo\config.txt"
)

Set-StrictMode -Off

# ---- Parse config -----------------------------------------------------------
$notebooks = @{}
Get-Content $ConfigPath | ForEach-Object {
    if ($_ -match '^notebook:(.+)=(.+)$') {
        $notebooks[$Matches[1]] = $Matches[2].Trim()
    }
}

# ---- Helpers ----------------------------------------------------------------
function Esc([string]$s) {
    return $s -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;' -replace '"','&quot;'
}
function Preview([string]$s, [int]$len = 280) {
    $s = $s -replace '\r?\n', ' ' -replace '\s+', ' '
    if ($s.Length -gt $len) { return (Esc($s.Substring(0, $len))) + '&hellip;' }
    return Esc($s)
}
function Fmt([long]$n) { return $n.ToString('N0') }

# ---- Notebook metadata (ASCII-safe; icons are HTML entities in output) ------
$nbOrder  = @('default','work','personal','projects','devlog','research','trading','health','learning','watchlist','commonplace')
$nbLabels = @{ default='Default'; work='Work'; personal='Personal'; projects='Projects'; devlog='Dev Log';
               research='Research'; trading='Trading'; health='Health'; learning='Learning';
               watchlist='Watchlist'; commonplace='Commonplace' }

# Icons as HTML numeric character references (no literal emoji in the .ps1 source)
$nbIcons  = @{
    default     = '&#x1F4D3;'
    work        = '&#x1F4BC;'
    personal    = '&#x1F9CD;'
    projects    = '&#x1F5C2;&#xFE0F;'
    devlog      = '&#x1F4BB;'
    research    = '&#x1F52C;'
    trading     = '&#x1F4C8;'
    health      = '&#x2764;&#xFE0F;'
    learning    = '&#x1F4DA;'
    watchlist   = '&#x1F441;&#xFE0F;'
    commonplace = '&#x1F4A1;'
}
$nbColors = @{
    default='#6b8cba'; work='#5b8dd9'; personal='#b87cde'; projects='#7ec8c8';
    devlog='#7cb87e'; research='#c8a87e'; trading='#d4b44a'; health='#d46a6a';
    learning='#5cb8a0'; watchlist='#a0a8d4'; commonplace='#c89060'
}

# ---- Collect data -----------------------------------------------------------
$allEntries     = [System.Collections.Generic.List[hashtable]]::new()
$notebookStats  = @{}
$activityByDate = @{}

foreach ($nbName in $nbOrder) {
    if (-not $notebooks.ContainsKey($nbName)) { continue }
    $nbPath = $notebooks[$nbName]

    $files = Get-ChildItem $nbPath -Filter 'Journal_*.txt' -File -ErrorAction SilentlyContinue

    $nbEntryCount = 0
    $nbWordCount  = 0
    $nbDateList   = @()

    foreach ($f in $files) {
        if ($f.Name -notmatch 'Journal_(\d{4}-\d{2}-\d{2})\.txt') { continue }
        $fileDate = $Matches[1]
        $nbDateList += $fileDate

        $raw = Get-Content $f.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        if (-not $raw) { continue }

        $pattern = '\[(\d{2}:\d{2}:\d{2}) @([^\]]+)\]([\s\S]*?)(?=\n\[|\z)'
        $rxmatches = [regex]::Matches($raw, $pattern)

        foreach ($m in $rxmatches) {
            $time    = $m.Groups[1].Value
            $machine = $m.Groups[2].Value.Trim()
            $text    = $m.Groups[3].Value.Trim()
            $words   = if ($text) { ($text -split '\s+' | Where-Object { $_ -ne '' }).Count } else { 0 }

            $nbEntryCount++
            $nbWordCount  += $words

            $allEntries.Add(@{
                Date     = $fileDate
                Time     = $time
                Machine  = $machine
                Text     = $text
                Notebook = $nbName
                Words    = $words
            })

            if ($activityByDate.ContainsKey($fileDate)) { $activityByDate[$fileDate]++ }
            else { $activityByDate[$fileDate] = 1 }
        }
    }

    $sorted = $nbDateList | Sort-Object
    $notebookStats[$nbName] = @{
        Entries   = $nbEntryCount
        Words     = $nbWordCount
        Files     = $files.Count
        Dates     = $sorted
        FirstDate = if ($sorted.Count -gt 0) { $sorted[0]  } else { $null }
        LastDate  = if ($sorted.Count -gt 0) { $sorted[-1] } else { $null }
    }
}

# ---- Overall stats ----------------------------------------------------------
$totalEntries    = [long](($notebookStats.Values | ForEach-Object { $_.Entries }) | Measure-Object -Sum).Sum
$totalWords      = [long](($notebookStats.Values | ForEach-Object { $_.Words   }) | Measure-Object -Sum).Sum
$activeNotebooks = ($notebookStats.Values | Where-Object { $_.Entries -gt 0 }).Count
$allDates        = $activityByDate.Keys | Sort-Object

# Longest streak
$longestStreak = 0; $streak = 0; $prevDt = $null
foreach ($d in $allDates) {
    $dt = [datetime]::ParseExact($d, 'yyyy-MM-dd', $null)
    if ($prevDt -and ($dt - $prevDt).Days -eq 1) { $streak++ } else { $streak = 1 }
    if ($streak -gt $longestStreak) { $longestStreak = $streak }
    $prevDt = $dt
}

# Current streak (count back from today)
$today = [datetime]::Today
$currentStreak = 0
$checkDate = $today
while ($activityByDate.ContainsKey($checkDate.ToString('yyyy-MM-dd'))) {
    $currentStreak++
    $checkDate = $checkDate.AddDays(-1)
}

$lastActiveDate  = if ($allDates.Count -gt 0) { $allDates[-1]  } else { 'never' }
$firstActiveDate = if ($allDates.Count -gt 0) { $allDates[0]   } else { 'never' }
$totalDaysActive = $allDates.Count

$recentEntries = $allEntries |
    Sort-Object { "$($_.Date)T$($_.Time)" } -Descending |
    Select-Object -First 20

# ---- Heatmap ----------------------------------------------------------------
$heatStart = $today.AddDays(-364)
while ($heatStart.DayOfWeek -ne [System.DayOfWeek]::Sunday) { $heatStart = $heatStart.AddDays(-1) }

$heatSb = [System.Text.StringBuilder]::new()
[void]$heatSb.AppendLine('<div class="heatmap-scroll"><div class="heatmap-weeks">')

$cur = $heatStart
while ($cur -le $today.AddDays(6 - [int]$today.DayOfWeek)) {
    [void]$heatSb.AppendLine('<div class="heatmap-week">')
    for ($dow = 0; $dow -lt 7; $dow++) {
        $d  = $cur.AddDays($dow)
        $ds = $d.ToString('yyyy-MM-dd')
        $cnt = if ($activityByDate.ContainsKey($ds)) { $activityByDate[$ds] } else { 0 }
        $lvl = if ($cnt -eq 0) { 0 } elseif ($cnt -le 2) { 1 } elseif ($cnt -le 5) { 2 } elseif ($cnt -le 10) { 3 } else { 4 }
        $future = if ($d -gt $today) { ' future' } else { '' }
        $plural = if ($cnt -eq 1) { 'entry' } else { 'entries' }
        $tip = if ($d -gt $today) { '' } elseif ($cnt -eq 0) { "No entries - $ds" } else { "$cnt $plural - $ds" }
        [void]$heatSb.AppendLine("<div class=""hc level-$lvl$future"" title=""$tip""></div>")
    }
    [void]$heatSb.AppendLine('</div>')
    $cur = $cur.AddDays(7)
}
[void]$heatSb.AppendLine('</div></div>')

# ---- Notebook cards ---------------------------------------------------------
$cardsSb = [System.Text.StringBuilder]::new()
foreach ($nb in $nbOrder) {
    if (-not $notebookStats.ContainsKey($nb)) { continue }
    $st  = $notebookStats[$nb]
    $cls = if ($st.Entries -eq 0) { ' empty' } else { '' }
    $clr = $nbColors[$nb]
    $ico = $nbIcons[$nb]

    [void]$cardsSb.AppendLine("<div class=""nb-card$cls"" style=""--accent:$clr"">")
    [void]$cardsSb.AppendLine("  <div class=""nb-head"">$ico $($nbLabels[$nb])</div>")
    [void]$cardsSb.AppendLine("  <div class=""nb-nums"">")
    [void]$cardsSb.AppendLine("    <div class=""nb-num""><b>$(Fmt $st.Entries)</b><small>entries</small></div>")
    [void]$cardsSb.AppendLine("    <div class=""nb-num""><b>$(Fmt $st.Words)</b><small>words</small></div>")
    [void]$cardsSb.AppendLine("    <div class=""nb-num""><b>$($st.Files)</b><small>days</small></div>")
    [void]$cardsSb.AppendLine("  </div>")
    $lastTxt = if ($st.LastDate) { $st.LastDate } else { '&mdash;' }
    [void]$cardsSb.AppendLine("  <div class=""nb-last"">Last active: $lastTxt</div>")
    [void]$cardsSb.AppendLine("</div>")
}

# ---- TOC -------------------------------------------------------------------
$tocSb = [System.Text.StringBuilder]::new()
foreach ($nb in $nbOrder) {
    if (-not $notebookStats.ContainsKey($nb)) { continue }
    $st = $notebookStats[$nb]
    if ($st.Files -eq 0) { continue }
    $clr = $nbColors[$nb]
    $ico = $nbIcons[$nb]

    [void]$tocSb.AppendLine("<details class=""toc-nb"" style=""--accent:$clr"">")
    [void]$tocSb.AppendLine("  <summary><span>$ico $($nbLabels[$nb])</span><span class=""toc-meta"">$($st.Entries) entries &middot; $($st.Files) days</span></summary>")
    [void]$tocSb.AppendLine("  <div class=""toc-dates"">")

    foreach ($ds in ($st.Dates | Sort-Object -Descending)) {
        $dayCount = @($allEntries | Where-Object { $_.Notebook -eq $nb -and $_.Date -eq $ds }).Count
        $dt       = [datetime]::ParseExact($ds, 'yyyy-MM-dd', $null)
        $label    = $dt.ToString('ddd, MMM d, yyyy')
        $plural   = if ($dayCount -eq 1) { 'entry' } else { 'entries' }
        [void]$tocSb.AppendLine("    <div class=""toc-row""><span>$label</span><span class=""toc-cnt"">$dayCount $plural</span></div>")
    }

    [void]$tocSb.AppendLine("  </div>")
    [void]$tocSb.AppendLine("</details>")
}

# ---- Recent entries ---------------------------------------------------------
$recentSb = [System.Text.StringBuilder]::new()
foreach ($e in $recentEntries) {
    $clr  = $nbColors[$e.Notebook]
    $lbl  = $nbLabels[$e.Notebook]
    $ico  = $nbIcons[$e.Notebook]
    $prev = Preview $e.Text 300

    [void]$recentSb.AppendLine("<div class=""entry"">")
    [void]$recentSb.AppendLine("  <div class=""entry-meta"">")
    [void]$recentSb.AppendLine("    <span class=""entry-nb"" style=""color:$clr"">$ico $lbl</span>")
    [void]$recentSb.AppendLine("    <span class=""entry-dt"">$($e.Date) &nbsp;$($e.Time)</span>")
    [void]$recentSb.AppendLine("    <span class=""entry-machine"">@$($e.Machine)</span>")
    [void]$recentSb.AppendLine("  </div>")
    [void]$recentSb.AppendLine("  <div class=""entry-text"">$prev</div>")
    [void]$recentSb.AppendLine("</div>")
}

# ---- Assemble HTML ----------------------------------------------------------
$genTime = [datetime]::Now.ToString('ddd, MMM d yyyy  h:mm tt')

$css = @'
*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
:root{
  --bg:#0d1117;--surface:#161b22;--border:#30363d;--text:#e6edf3;--muted:#8b949e;
  --h0:#21262d;--h1:#0e4429;--h2:#006d32;--h3:#26a641;--h4:#39d353;
  --radius:8px
}
body{background:var(--bg);color:var(--text);
     font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;
     font-size:14px;line-height:1.6;padding:24px 28px;max-width:1100px;margin:0 auto}
h2{font-size:12px;font-weight:600;color:var(--muted);text-transform:uppercase;
   letter-spacing:.1em;margin-bottom:12px}
section{margin-bottom:44px}

/* Header */
.hdr{display:flex;flex-direction:column;gap:14px;margin-bottom:36px}
.hdr h1{font-size:24px;font-weight:700}
.gen{color:var(--muted);font-size:12px;margin-top:2px}
.sbar{display:flex;flex-wrap:wrap;gap:10px}
.ss{background:var(--surface);border:1px solid var(--border);border-radius:var(--radius);
    padding:11px 18px;display:flex;flex-direction:column;align-items:center;min-width:105px}
.ss b{font-size:20px;font-weight:700;line-height:1.15}
.ss small{color:var(--muted);font-size:10px;text-transform:uppercase;letter-spacing:.07em;margin-top:1px}

/* Notebook cards */
.nb-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(160px,1fr));gap:14px}
.nb-card{background:var(--surface);border:1px solid var(--border);
         border-top:3px solid var(--accent);border-radius:var(--radius);
         padding:13px;display:flex;flex-direction:column;gap:8px;transition:opacity .2s}
.nb-card.empty{opacity:.38}
.nb-head{font-size:14px;font-weight:600}
.nb-nums{display:flex;gap:14px;margin-top:2px}
.nb-num{display:flex;flex-direction:column;align-items:center}
.nb-num b{font-size:17px;font-weight:700;color:var(--accent)}
.nb-num small{font-size:10px;color:var(--muted);text-transform:uppercase;letter-spacing:.04em}
.nb-last{font-size:11px;color:var(--muted)}

/* Heatmap */
.heatmap-scroll{overflow-x:auto;padding-bottom:6px}
.heatmap-weeks{display:flex;gap:3px;width:max-content}
.heatmap-week{display:flex;flex-direction:column;gap:3px}
.hc{width:13px;height:13px;border-radius:2px;cursor:default}
.hc.future{opacity:.1}
.level-0{background:var(--h0)}
.level-1{background:var(--h1)}
.level-2{background:var(--h2)}
.level-3{background:var(--h3)}
.level-4{background:var(--h4)}
.hm-legend{display:flex;align-items:center;gap:5px;margin-top:8px;
           font-size:11px;color:var(--muted)}

/* TOC */
.toc{display:flex;flex-direction:column;gap:8px}
.toc-nb{background:var(--surface);border:1px solid var(--border);
        border-left:3px solid var(--accent);border-radius:var(--radius)}
.toc-nb>summary{display:flex;justify-content:space-between;align-items:center;
                padding:10px 14px;cursor:pointer;list-style:none;
                font-weight:600;font-size:14px;user-select:none}
.toc-nb>summary::-webkit-details-marker{display:none}
.toc-nb>summary::before{content:'>';margin-right:8px;font-size:10px;
                         color:var(--muted);transition:transform .15s;display:inline-block}
.toc-nb[open]>summary::before{transform:rotate(90deg)}
.toc-meta{color:var(--muted);font-size:12px;font-weight:400}
.toc-dates{padding:0 14px 10px 32px}
.toc-row{display:flex;justify-content:space-between;padding:5px 0;
         border-bottom:1px solid var(--border);font-size:13px}
.toc-row:last-child{border-bottom:none}
.toc-cnt{color:var(--muted);font-size:12px}

/* Recent entries */
.entries{display:flex;flex-direction:column;gap:10px}
.entry{background:var(--surface);border:1px solid var(--border);
       border-radius:var(--radius);padding:12px 16px}
.entry-meta{display:flex;flex-wrap:wrap;align-items:center;gap:10px;
            margin-bottom:6px;font-size:12px}
.entry-nb{font-weight:600;font-size:13px}
.entry-dt,.entry-machine{color:var(--muted)}
.entry-text{color:#c9d1d9;font-size:13px;line-height:1.55;word-break:break-word}

/* Footer */
footer{margin-top:36px;padding-top:14px;border-top:1px solid var(--border);
       color:var(--muted);font-size:11px;text-align:center}
'@

$heatmapCards = $heatSb.ToString().TrimEnd()
$notebookCards = $cardsSb.ToString().TrimEnd()
$tocContent = $tocSb.ToString().TrimEnd()
$recentContent = $recentSb.ToString().TrimEnd()

$html = "<!DOCTYPE html>`n<html lang=""en"">`n<head>`n<meta charset=""UTF-8"">`n<meta name=""viewport"" content=""width=device-width,initial-scale=1"">`n<title>MyJo Dashboard</title>`n<style>`n$css`n</style>`n</head>`n<body>`n`n<header class=""hdr"">`n  <div>`n    <h1>&#x1F4D3; MyJo Dashboard</h1>`n    <p class=""gen"">Generated $genTime</p>`n  </div>`n  <div class=""sbar"">`n    <div class=""ss""><b>$(Fmt $totalEntries)</b><small>Total Entries</small></div>`n    <div class=""ss""><b>$(Fmt $totalWords)</b><small>Total Words</small></div>`n    <div class=""ss""><b>$activeNotebooks</b><small>Active Notebooks</small></div>`n    <div class=""ss""><b>$totalDaysActive</b><small>Days Active</small></div>`n    <div class=""ss""><b>$currentStreak</b><small>Day Streak</small></div>`n    <div class=""ss""><b>$longestStreak</b><small>Best Streak</small></div>`n    <div class=""ss""><b>$firstActiveDate</b><small>Since</small></div>`n    <div class=""ss""><b>$lastActiveDate</b><small>Last Active</small></div>`n  </div>`n</header>`n`n<main>`n`n<section>`n  <h2>Notebooks</h2>`n  <div class=""nb-grid"">`n$notebookCards`n  </div>`n</section>`n`n<section>`n  <h2>Activity &mdash; Past Year</h2>`n  $heatmapCards`n  <div class=""hm-legend""><span>Less</span><div class=""hc level-0"" title=""No entries""></div><div class=""hc level-1"" title=""1-2 entries""></div><div class=""hc level-2"" title=""3-5 entries""></div><div class=""hc level-3"" title=""6-10 entries""></div><div class=""hc level-4"" title=""11+ entries""></div><span>More</span></div>`n</section>`n`n<section>`n  <h2>Recent Entries</h2>`n  <div class=""entries"">`n$recentContent`n  </div>`n</section>`n`n<section>`n  <h2>Index</h2>`n  <div class=""toc"">`n$tocContent`n  </div>`n</section>`n`n</main>`n`n<footer>MyJo Dashboard &mdash; $genTime</footer>`n</body>`n</html>"

[System.IO.File]::WriteAllText($OutputPath, $html, [System.Text.Encoding]::UTF8)
Write-Host "Dashboard written to: $OutputPath"
Invoke-Item $OutputPath
