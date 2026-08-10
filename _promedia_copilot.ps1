param([string]$WorkDir = "")

$ErrorActionPreference = "Stop"

$AppDir = $PSScriptRoot
if (-not $WorkDir) { $WorkDir = Split-Path $AppDir -Parent }
if (-not $WorkDir) { $WorkDir = $AppDir }
try { $WorkDir = (Resolve-Path -LiteralPath $WorkDir).Path } catch { }
$WorkDir = $WorkDir.TrimEnd('\')
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
try { [Console]::InputEncoding = [System.Text.Encoding]::UTF8 } catch { }
Add-Type -AssemblyName System.IO.Compression | Out-Null

$latin = [System.Text.Encoding]::GetEncoding(28591)
$streamRx = [regex]::new('stream\r?\n(.*?)\r?\nendstream', [System.Text.RegularExpressions.RegexOptions]::Singleline)

$BannerStyles = @(
    @{ N = 'Original'; D = 'IF9fX18gIF9fX18gICBfX18gIF9fICBfXyBfX19fXyBfX19fIF9fXyAgICBfICAgIAp8ICBfIFx8ICBfIFwgLyBfIFx8ICBcLyAgfCBfX19ffCAgXyBcXyBffCAgLyBcICAgCnwgfF8pIHwgfF8pIHwgfCB8IHwgfFwvfCB8ICBffCB8IHwgfCB8IHwgIC8gXyBcICAKfCAgX18vfCAgXyA8fCB8X3wgfCB8ICB8IHwgfF9fX3wgfF98IHwgfCAvIF9fXyBcIAp8X3wgICB8X3wgXF9cXF9fXy98X3wgIHxffF9fX19ffF9fX18vX19fL18vICAgXF9c'; W = 'ICBfX19fIF9fXyAgX19fXyBfX18gXyAgICAgX19fIF9fX19fIAogLyBfX18vIF8gXHwgIF8gXF8gX3wgfCAgIC8gXyBcXyAgIF98CnwgfCAgfCB8IHwgfCB8XykgfCB8fCB8ICB8IHwgfCB8fCB8ICAKfCB8X198IHxffCB8ICBfXy98IHx8IHxfX3wgfF98IHx8IHwgIAogXF9fX19cX19fL3xffCAgfF9fX3xfX19fX1xfX18vIHxffCAg' }
    @{ N = 'Plain'; D = 'UFJPTUVESUE='; W = 'Q09QSUxPVA==' }
)

$script:BannerCache = $null

function Get-BannerArt {
    if ($script:BannerCache) { return $script:BannerCache }
    $idx = 0
    $v = Get-Setting 'BANNER'
    if ($v -match '^\d+$') { $idx = [int]$v }
    if ($idx -lt 0 -or $idx -ge $BannerStyles.Count) { $idx = 0 }
    $st = $BannerStyles[$idx]
    $doc = ([System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($st.D)) -split "`n")
    $wiz = ([System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($st.W)) -split "`n")
    $script:BannerCache = @{ Doc = $doc; Wiz = $wiz; Name = $st.N }
    return $script:BannerCache
}

function Get-EffectiveBannerArt {
    $art = Get-BannerArt
    if ($art.Name -eq 'Plain') { return $art }
    $w = 78
    try { $cw = [Console]::WindowWidth; if ($cw -gt 0) { $w = $cw } } catch { }
    $maxDoc = ($art.Doc | Measure-Object -Property Length -Maximum).Maximum
    $maxWiz = ($art.Wiz | Measure-Object -Property Length -Maximum).Maximum
    $needed = 2 + $maxDoc + 3 + $maxWiz
    if ($w -lt $needed) {
        return @{ Doc = @(); Wiz = @(); Name = 'Plain' }
    }
    return $art
}

function Get-FullWidthBar {
    param([char]$Char = [char]0x2550)
    $w = 78
    try { $cw = [Console]::WindowWidth; if ($cw -gt 0) { $w = $cw } } catch { }
    $n = $w - 3
    if ($n -lt 10) { $n = 10 }
    return "  " + ([string]$Char * $n)
}

$light = "  " + ([string][char]0x2500 * 68)

$FuPrefix = "F" + [char]0x00DC

$MonthsDE = @('Januar', 'Februar', ("M" + [char]0x00E4 + "rz"), 'April', 'Mai', 'Juni', 'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember')
$MonthsEN = @('January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December')
$MonthAbbrDE = @('Jan', 'Feb', 'Mrz', 'Apr', 'Mai', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez')
$MonthAbbrEN = @('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec')
$MonthPat = @(
    'jan(uar|uary)?',
    'feb(ruar|ruary)?',
    ('m(ae|' + [char]0x00E4 + '|a)?rz|mrz|march|mar'),
    'apr(il)?',
    'mai|may',
    'jun(i|e)?',
    'jul(i|y)?',
    'aug(ust)?',
    'sept(ember)?|sep',
    'okt(ober)?|oct(ober)?',
    'nov(ember)?',
    'dez(ember)?|dec(ember)?'
)

$CountryNames = @{
    'DE' = @('deutschland', 'germany', 'allemagne')
    'FR' = @('frankreich', 'france')
    'BE' = @('belgien', 'belgium', 'belgique')
    'NL' = @('niederlande', 'netherlands', 'holland')
    'CZ' = @('tschechien', 'czech', 'czechia', 'thech')
    'AT' = @('osterreich', 'austria')
    'CH' = @('schweiz', 'switzerland', 'suisse')
    'IT' = @('italien', 'italy', 'italia')
    'ES' = @('spanien', 'spain', 'espana')
    'PL' = @('polen', 'poland', 'polska')
    'DK' = @('danemark', 'denmark', 'danmark')
    'SE' = @('schweden', 'sweden', 'sverige')
    'NO' = @('norwegen', 'norway', 'norge')
    'FI' = @('finnland', 'finland', 'suomi')
    'PT' = @('portugal')
    'GB' = @('grossbritannien', 'united kingdom', 'england', 'britain')
    'IE' = @('irland', 'ireland')
    'HU' = @('ungarn', 'hungary')
    'SK' = @('slowakei', 'slovakia')
    'RO' = @('rumanien', 'romania')
    'LU' = @('luxemburg', 'luxembourg')
    'MT' = @('malta')
    'CY' = @('zypern', 'cyprus')
    'GR' = @('griechenland', 'greece')
    'TR' = @('turkei', 'turkey')
    'SI' = @('slowenien', 'slovenia')
    'HR' = @('kroatien', 'croatia')
    'RS' = @('serbien', 'serbia')
    'BG' = @('bulgarien', 'bulgaria')
    'LT' = @('litauen', 'lithuania')
    'LV' = @('lettland', 'latvia')
    'EE' = @('estland', 'estonia')
    'IS' = @('island', 'iceland')
    'US' = @('usa', 'united states', 'vereinigte staaten')
    'CA' = @('kanada', 'canada')
    'MX' = @('mexiko', 'mexico')
    'BR' = @('brasilien', 'brazil')
    'AE' = @('uae', 'dubai', 'emirate', 'vereinigte arabische emirate')
    'SA' = @('saudi arabien', 'saudi arabia', 'saudi')
    'QA' = @('katar', 'qatar')
    'IL' = @('israel')
    'EG' = @('agypten', 'egypt')
    'MA' = @('marokko', 'morocco')
    'TN' = @('tunesien', 'tunisia')
    'ZA' = @('sudafrika', 'south africa')
    'SG' = @('singapur', 'singapore')
    'VN' = @('vietnam', 'viertnam')
    'JP' = @('japan')
    'CN' = @('china')
    'IN' = @('indien', 'india')
    'AU' = @('australien', 'australia')
    'NZ' = @('neuseeland', 'new zealand')
    'RU' = @('russland', 'russia')
    'UA' = @('ukraine')
}

$IsoCountry = @{
    'AD'='Andorra'; 'AE'='United Arab Emirates'; 'AF'='Afghanistan'; 'AG'='Antigua and Barbuda'
    'AI'='Anguilla'; 'AL'='Albania'; 'AM'='Armenia'; 'AO'='Angola'
    'AQ'='Antarctica'; 'AR'='Argentina'; 'AS'='American Samoa'; 'AT'='Austria'
    'AU'='Australia'; 'AW'='Aruba'; 'AX'='Aland Islands'; 'AZ'='Azerbaijan'
    'BA'='Bosnia and Herzegovina'; 'BB'='Barbados'; 'BD'='Bangladesh'; 'BE'='Belgium'
    'BF'='Burkina Faso'; 'BG'='Bulgaria'; 'BH'='Bahrain'; 'BI'='Burundi'
    'BJ'='Benin'; 'BL'='Saint Barthelemy'; 'BM'='Bermuda'; 'BN'='Brunei'
    'BO'='Bolivia'; 'BQ'='Bonaire'; 'BR'='Brazil'; 'BS'='Bahamas'
    'BT'='Bhutan'; 'BV'='Bouvet Island'; 'BW'='Botswana'; 'BY'='Belarus'
    'BZ'='Belize'; 'CA'='Canada'; 'CC'='Cocos Islands'; 'CD'='Congo (DRC)'
    'CF'='Central African Republic'; 'CG'='Congo'; 'CH'='Switzerland'; 'CI'='Cote d Ivoire'
    'CK'='Cook Islands'; 'CL'='Chile'; 'CM'='Cameroon'; 'CN'='China'
    'CO'='Colombia'; 'CR'='Costa Rica'; 'CU'='Cuba'; 'CV'='Cabo Verde'
    'CW'='Curacao'; 'CX'='Christmas Island'; 'CY'='Cyprus'; 'CZ'='Czechia'
    'DE'='Germany'; 'DJ'='Djibouti'; 'DK'='Denmark'; 'DM'='Dominica'
    'DO'='Dominican Republic'; 'DZ'='Algeria'; 'EC'='Ecuador'; 'EE'='Estonia'
    'EG'='Egypt'; 'EH'='Western Sahara'; 'ER'='Eritrea'; 'ES'='Spain'
    'ET'='Ethiopia'; 'FI'='Finland'; 'FJ'='Fiji'; 'FK'='Falkland Islands'
    'FM'='Micronesia'; 'FO'='Faroe Islands'; 'FR'='France'; 'GA'='Gabon'
    'GB'='United Kingdom'; 'GD'='Grenada'; 'GE'='Georgia'; 'GF'='French Guiana'
    'GG'='Guernsey'; 'GH'='Ghana'; 'GI'='Gibraltar'; 'GL'='Greenland'
    'GM'='Gambia'; 'GN'='Guinea'; 'GP'='Guadeloupe'; 'GQ'='Equatorial Guinea'
    'GR'='Greece'; 'GS'='South Georgia'; 'GT'='Guatemala'; 'GU'='Guam'
    'GW'='Guinea-Bissau'; 'GY'='Guyana'; 'HK'='Hong Kong'; 'HM'='Heard Island'
    'HN'='Honduras'; 'HR'='Croatia'; 'HT'='Haiti'; 'HU'='Hungary'
    'ID'='Indonesia'; 'IE'='Ireland'; 'IL'='Israel'; 'IM'='Isle of Man'
    'IN'='India'; 'IO'='British Indian Ocean Territory'; 'IQ'='Iraq'; 'IR'='Iran'
    'IS'='Iceland'; 'IT'='Italy'; 'JE'='Jersey'; 'JM'='Jamaica'
    'JO'='Jordan'; 'JP'='Japan'; 'KE'='Kenya'; 'KG'='Kyrgyzstan'
    'KH'='Cambodia'; 'KI'='Kiribati'; 'KM'='Comoros'; 'KN'='Saint Kitts and Nevis'
    'KP'='North Korea'; 'KR'='South Korea'; 'KW'='Kuwait'; 'KY'='Cayman Islands'
    'KZ'='Kazakhstan'; 'LA'='Laos'; 'LB'='Lebanon'; 'LC'='Saint Lucia'
    'LI'='Liechtenstein'; 'LK'='Sri Lanka'; 'LR'='Liberia'; 'LS'='Lesotho'
    'LT'='Lithuania'; 'LU'='Luxembourg'; 'LV'='Latvia'; 'LY'='Libya'
    'MA'='Morocco'; 'MC'='Monaco'; 'MD'='Moldova'; 'ME'='Montenegro'
    'MF'='Saint Martin'; 'MG'='Madagascar'; 'MH'='Marshall Islands'; 'MK'='North Macedonia'
    'ML'='Mali'; 'MM'='Myanmar'; 'MN'='Mongolia'; 'MO'='Macao'
    'MP'='Northern Mariana Islands'; 'MQ'='Martinique'; 'MR'='Mauritania'; 'MS'='Montserrat'
    'MT'='Malta'; 'MU'='Mauritius'; 'MV'='Maldives'; 'MW'='Malawi'
    'MX'='Mexico'; 'MY'='Malaysia'; 'MZ'='Mozambique'; 'NA'='Namibia'
    'NC'='New Caledonia'; 'NE'='Niger'; 'NF'='Norfolk Island'; 'NG'='Nigeria'
    'NI'='Nicaragua'; 'NL'='Netherlands'; 'NO'='Norway'; 'NP'='Nepal'
    'NR'='Nauru'; 'NU'='Niue'; 'NZ'='New Zealand'; 'OM'='Oman'
    'PA'='Panama'; 'PE'='Peru'; 'PF'='French Polynesia'; 'PG'='Papua New Guinea'
    'PH'='Philippines'; 'PK'='Pakistan'; 'PL'='Poland'; 'PM'='Saint Pierre and Miquelon'
    'PN'='Pitcairn'; 'PR'='Puerto Rico'; 'PS'='Palestine'; 'PT'='Portugal'
    'PW'='Palau'; 'PY'='Paraguay'; 'QA'='Qatar'; 'RE'='Reunion'
    'RO'='Romania'; 'RS'='Serbia'; 'RU'='Russia'; 'RW'='Rwanda'
    'SA'='Saudi Arabia'; 'SB'='Solomon Islands'; 'SC'='Seychelles'; 'SD'='Sudan'
    'SE'='Sweden'; 'SG'='Singapore'; 'SH'='Saint Helena'; 'SI'='Slovenia'
    'SJ'='Svalbard'; 'SK'='Slovakia'; 'SL'='Sierra Leone'; 'SM'='San Marino'
    'SN'='Senegal'; 'SO'='Somalia'; 'SR'='Suriname'; 'SS'='South Sudan'
    'ST'='Sao Tome and Principe'; 'SV'='El Salvador'; 'SX'='Sint Maarten'; 'SY'='Syria'
    'SZ'='Eswatini'; 'TC'='Turks and Caicos'; 'TD'='Chad'; 'TF'='French Southern Territories'
    'TG'='Togo'; 'TH'='Thailand'; 'TJ'='Tajikistan'; 'TK'='Tokelau'
    'TL'='Timor-Leste'; 'TM'='Turkmenistan'; 'TN'='Tunisia'; 'TO'='Tonga'
    'TR'='Turkey'; 'TT'='Trinidad and Tobago'; 'TV'='Tuvalu'; 'TW'='Taiwan'
    'TZ'='Tanzania'; 'UA'='Ukraine'; 'UG'='Uganda'; 'UM'='US Minor Outlying Islands'
    'US'='United States'; 'UY'='Uruguay'; 'UZ'='Uzbekistan'; 'VA'='Vatican City'
    'VC'='Saint Vincent'; 'VE'='Venezuela'; 'VG'='British Virgin Islands'; 'VI'='US Virgin Islands'
    'VN'='Vietnam'; 'VU'='Vanuatu'; 'WF'='Wallis and Futuna'; 'WS'='Samoa'
    'XK'='Kosovo'; 'YE'='Yemen'; 'YT'='Mayotte'; 'ZA'='South Africa'
    'ZM'='Zambia'; 'ZW'='Zimbabwe'
}

function Show-Header {
    $art = Get-EffectiveBannerArt
    $bar = Get-FullWidthBar
    if ($art.Name -eq 'Plain') {
        Write-Host ""
        Write-Host $bar -ForegroundColor Red
        Write-Host -NoNewline "  PROMEDIA" -ForegroundColor White
        Write-Host -NoNewline "   COPILOT" -ForegroundColor White
        Write-Host ("   Version " + $script:AppVersion + "  |  by Engin Sarak") -ForegroundColor Blue
        Write-Host $bar -ForegroundColor Red
        return
    }
    Write-Host ""
    Write-Host $bar -ForegroundColor Red
    Write-Host ""
    for ($i = 0; $i -lt $art.Doc.Count; $i++) {
        Write-Host -NoNewline ("  " + $art.Doc[$i]) -ForegroundColor White
        Write-Host ("   " + $art.Wiz[$i]) -ForegroundColor White
    }
    Write-Host ""
    Write-Host ("         Version " + $script:AppVersion + "  |  by Engin Sarak") -ForegroundColor Blue
    Write-Host $bar -ForegroundColor Red
}

$script:CanPosition = $false
try {
    $__orig = [Console]::CursorTop
    [Console]::SetCursorPosition(0, 0)
    if ([Console]::CursorTop -eq 0) { $script:CanPosition = $true }
    [Console]::SetCursorPosition(0, $__orig)
} catch { $script:CanPosition = $false }

function Get-HeaderRows {
    $rows = New-Object System.Collections.Generic.List[object]
    $art = Get-EffectiveBannerArt
    $bar = Get-FullWidthBar
    if ($art.Name -eq 'Plain') {
        $rows.Add(@(@{ T = ""; F = "Gray" }))
        $rows.Add(@(@{ T = $bar; F = "Red" }))
        $rows.Add(@(@{ T = "  PROMEDIA"; F = "White" }, @{ T = "   COPILOT"; F = "White" }, @{ T = ("   Version " + $script:AppVersion + "  |  by Engin Sarak"); F = "Blue" }))
        $rows.Add(@(@{ T = $bar; F = "Red" }))
        return ,$rows
    }
    $rows.Add(@(@{ T = ""; F = "Gray" }))
    $rows.Add(@(@{ T = $bar; F = "Red" }))
    $rows.Add(@(@{ T = ""; F = "Gray" }))
    for ($i = 0; $i -lt $art.Doc.Count; $i++) {
        $rows.Add(@(@{ T = ("  " + $art.Doc[$i]); F = "White" }, @{ T = ("   " + $art.Wiz[$i]); F = "White" }))
    }
    $rows.Add(@(@{ T = ""; F = "Gray" }))
    $rows.Add(@(@{ T = ("         Version " + $script:AppVersion + "  |  by Engin Sarak"); F = "Blue" }))
    $rows.Add(@(@{ T = $bar; F = "Red" }))
    return ,$rows
}

function Render-FrameSimple($rows) {
    Clear-Host
    foreach ($row in $rows) {
        foreach ($seg in $row) {
            $txt = [string]$seg.T
            if ($txt.Length -gt 0) {
                if ($seg.B) { Write-Host -NoNewline $txt -ForegroundColor $seg.F -BackgroundColor $seg.B }
                else { Write-Host -NoNewline $txt -ForegroundColor $seg.F }
            }
        }
        Write-Host ""
    }
}

function Test-SnowSeason {
    $v = Get-Setting 'SNOW'
    if ($v -ieq 'on') { return $true }
    if ($v -ieq 'off') { return $false }
    $now = Get-Date
    return (($now.Month -eq 12) -and ($now.Day -le 25))
}

function New-SnowFlakes($grid) {
    $flakes = New-Object System.Collections.Generic.List[object]
    $h = $grid.Count
    if ($h -lt 6) { return ,$flakes }
    $w = 80
    try { $w = [Console]::WindowWidth - 1 } catch { }
    $chars = @('*', '.', '+')
    $count = [math]::Min(28, [int]($w / 4))
    for ($i = 0; $i -lt $count; $i++) {
        $flakes.Add(@{
            X = (Get-Random -Minimum 0 -Maximum $w)
            Y = (Get-Random -Minimum 0 -Maximum $h)
            C = $chars[(Get-Random -Minimum 0 -Maximum $chars.Count)]
            S = (Get-Random -Minimum 1 -Maximum 3)
            T = 0
        })
    }
    return ,$flakes
}

function Show-Snow($grid, $flakes, $erase) {
    $h = $grid.Count
    $w = 80
    try { $w = [Console]::WindowWidth - 1 } catch { }
    foreach ($f in $flakes) {
        $y = [int]$f.Y
        $x = [int]$f.X
        if ($y -lt 0 -or $y -ge $h -or $x -lt 0 -or $x -ge $w) { continue }
        $line = [string]$grid[$y]
        if ($x -ge $line.Length) { continue }
        if ($line[$x] -ne ' ') { continue }
        try {
            [Console]::SetCursorPosition($x, $y)
            if ($erase) { Write-Host -NoNewline " " }
            else { Write-Host -NoNewline $f.C -ForegroundColor White }
        } catch { }
    }
}

function Step-Snow($grid, $flakes) {
    $h = $grid.Count
    $w = 80
    try { $w = [Console]::WindowWidth - 1 } catch { }
    foreach ($f in $flakes) {
        $f.T = $f.T + 1
        if (($f.T % $f.S) -eq 0) {
            $f.Y = [int]$f.Y + 1
            if ((Get-Random -Minimum 0 -Maximum 3) -eq 0) { $f.X = [int]$f.X + (Get-Random -Minimum -1 -Maximum 2) }
        }
        if ([int]$f.Y -ge $h -or [int]$f.X -lt 0 -or [int]$f.X -ge $w) {
            $f.Y = 0
            $f.X = (Get-Random -Minimum 0 -Maximum $w)
        }
    }
}

function Wait-KeyWithSnow($grid) {
    # Console apps get no OS resize event, so we poll window size here and
    # bail out with $null to force the caller to re-render at the new size
    # instead of leaving the stale wide banner for the terminal to reflow.
    $snow = $script:CanPosition -and (Test-SnowSeason)
    $flakes = $null
    if ($snow) { $flakes = New-SnowFlakes $grid }
    $w0 = 0; $h0 = 0
    try { $w0 = [Console]::WindowWidth; $h0 = [Console]::WindowHeight } catch { }
    try {
        while (-not [Console]::KeyAvailable) {
            if ($snow) { Show-Snow $grid $flakes $false }
            Start-Sleep -Milliseconds 150
            if ($snow) { Show-Snow $grid $flakes $true; Step-Snow $grid $flakes }
            try {
                $w1 = [Console]::WindowWidth
                $h1 = [Console]::WindowHeight
                if ($w1 -ne $w0 -or $h1 -ne $h0) {
                    if ($script:CanPosition) { try { Clear-Host } catch { } }
                    return $null
                }
            } catch { }
        }
    } catch {
        return [Console]::ReadKey($true)
    }
    return [Console]::ReadKey($true)
}

function Render-Frame($rows) {
    $grid = New-Object System.Collections.Generic.List[string]
    if (-not $script:CanPosition) {
        Render-FrameSimple $rows
        return ,$grid
    }
    try {
        $w = [Console]::WindowWidth
        $h = [Console]::WindowHeight
        $maxw = $w - 1
        [Console]::SetCursorPosition(0, 0)
        $total = $h - 1
        for ($i = 0; $i -lt $total; $i++) {
            $used = 0
            $lineText = ""
            if ($i -lt $rows.Count) {
                foreach ($seg in $rows[$i]) {
                    $txt = [string]$seg.T
                    if ($used + $txt.Length -gt $maxw) { $txt = $txt.Substring(0, [math]::Max(0, $maxw - $used)) }
                    if ($txt.Length -gt 0) {
                        if ($seg.B) { Write-Host -NoNewline $txt -ForegroundColor $seg.F -BackgroundColor $seg.B }
                        else { Write-Host -NoNewline $txt -ForegroundColor $seg.F }
                        $used += $txt.Length
                        $lineText += $txt
                    }
                }
            }
            if ($used -lt $maxw) { Write-Host -NoNewline (" " * ($maxw - $used)) }
            $grid.Add($lineText.PadRight($maxw))
            if ($i -lt $total - 1) { Write-Host "" }
        }
    } catch {
        $script:CanPosition = $false
        Render-FrameSimple $rows
    }
    return ,$grid
}

function Get-ViewRows {
    $h = 24
    try { $h = [Console]::WindowHeight } catch { }
    $bannerLines = 6
    $extra = 6
    try {
        $art = Get-EffectiveBannerArt
        $bannerLines = $art.Doc.Count
        if ($art.Name -eq 'Plain') { $extra = 3 }
    } catch { }
    $rows = $h - 1 - ($bannerLines + $extra) - 5
    if ($rows -lt 5) { $rows = 5 }
    return $rows
}

function Show-Menu {
    param([string]$Title, [string[]]$Items)
    $selectable = @()
    for ($i = 0; $i -lt $Items.Count; $i++) { if ($Items[$i] -ne "") { $selectable += $i } }
    if ($selectable.Count -eq 0) { return -1 }
    $pos = 0
    $top = 0
    try { [Console]::CursorVisible = $false } catch { }
    while ($true) {
        $rows = Get-ViewRows
        $cur = $selectable[$pos]
        if ($cur -lt $top) { $top = $cur }
        if ($cur -ge $top + $rows) { $top = $cur - $rows + 1 }
        if ($top -gt $Items.Count - $rows) { $top = $Items.Count - $rows }
        if ($top -lt 0) { $top = 0 }
        $end = [math]::Min($top + $rows - 1, $Items.Count - 1)

        $frame = Get-HeaderRows
        $frame.Add(@(@{ T = ""; F = "Gray" }))
        $frame.Add(@(@{ T = ("   " + $Title); F = "Cyan" }))
        $frame.Add(@(@{ T = ""; F = "Gray" }))
        for ($i = $top; $i -le $end; $i++) {
            if ($Items[$i] -eq "") {
                $frame.Add(@(@{ T = ""; F = "Gray" }))
            } elseif ($i -eq $cur) {
                $frame.Add(@(@{ T = ("   > " + $Items[$i].PadRight(58)); F = "Black"; B = "Cyan" }))
            } else {
                $frame.Add(@(@{ T = ("     " + $Items[$i]); F = "Gray" }))
            }
        }
        $frame.Add(@(@{ T = ""; F = "Gray" }))
        $hint = "   Up/Down = move     Enter = select     Esc / Backspace = back"
        if ($top -gt 0 -or $end -lt $Items.Count - 1) {
            $hint = $hint + "     " + ($pos + 1) + "/" + $selectable.Count
        }
        $frame.Add(@(@{ T = $hint; F = "DarkGray" }))
        $grid = Render-Frame $frame

        $key = Wait-KeyWithSnow $grid
        if ($null -eq $key) { continue }
        switch ($key.Key) {
            'UpArrow'   { $pos = ($pos - 1 + $selectable.Count) % $selectable.Count }
            'DownArrow' { $pos = ($pos + 1) % $selectable.Count }
            'Home'      { $pos = 0 }
            'End'       { $pos = $selectable.Count - 1 }
            'PageUp'    { $pos = [math]::Max(0, $pos - 10) }
            'PageDown'  { $pos = [math]::Min($selectable.Count - 1, $pos + 10) }
            'Enter'     { try { [Console]::CursorVisible = $true } catch { }; Clear-Host; return $selectable[$pos] }
            'Escape'    { try { [Console]::CursorVisible = $true } catch { }; Clear-Host; return -1 }
            'Backspace' { try { [Console]::CursorVisible = $true } catch { }; Clear-Host; return -1 }
            'Delete'    { try { [Console]::CursorVisible = $true } catch { }; Clear-Host; return -1 }
        }
    }
}

function Inflate([byte[]]$bytes) {
    foreach ($skip in 2,0) {
        try {
            $ms = New-Object System.IO.MemoryStream
            $ms.Write($bytes, $skip, $bytes.Length - $skip)
            $ms.Position = 0
            $ds = New-Object System.IO.Compression.DeflateStream($ms, [System.IO.Compression.CompressionMode]::Decompress)
            $out = New-Object System.IO.MemoryStream
            $ds.CopyTo($out)
            $ds.Dispose()
            $r = $out.ToArray()
            if ($r.Length -gt 0) { return $r }
        } catch { }
    }
    return $null
}

$pdfOpRx = [regex]::new('/([A-Za-z0-9]+)\s+[\d.]+\s+Tf|\(((?:[^()\\]|\\.)*)\)\s*Tj|<([0-9A-Fa-f\s]+)>\s*Tj|\[((?:[^\[\]]|\\.)*)\]\s*TJ', [System.Text.RegularExpressions.RegexOptions]::Singleline)
$pdfPieceRx = [regex]::new('\(((?:[^()\\]|\\.)*)\)|<([0-9A-Fa-f\s]+)>', [System.Text.RegularExpressions.RegexOptions]::Singleline)

function Escape-PdfLit([string]$s) {
    if (-not $s) { return '' }
    $s = $s.Replace('\', '\\')
    $s = $s.Replace('(', '\(')
    $s = $s.Replace(')', '\)')
    return $s
}

$pdfHexRx = [regex]::new('<[0-9A-Fa-f]{6,}>\s*T[jJ]', [System.Text.RegularExpressions.RegexOptions]::None)

function Get-PdfText([string]$path) {
    $bytes = [System.IO.File]::ReadAllBytes($path)
    $s = $latin.GetString($bytes)
    $contents = New-Object System.Collections.Generic.List[string]
    $needDecode = $false
    foreach ($m in $streamRx.Matches($s)) {
        $dec = Inflate ($latin.GetBytes($m.Groups[1].Value))
        if (-not $dec) { continue }
        $c = $latin.GetString($dec)
        $contents.Add($c)
        if (-not $needDecode -and ($c.IndexOf('Tj') -ge 0 -or $c.IndexOf('TJ') -ge 0) -and $pdfHexRx.IsMatch($c)) { $needDecode = $true }
    }
    $sb = New-Object System.Text.StringBuilder
    if (-not $needDecode) {
        foreach ($c in $contents) { [void]$sb.Append($c) }
        [void]$sb.Append($s)
        return $sb.ToString()
    }
    $page = Get-PageBody $s
    $fontCache = @{}
    foreach ($content in $contents) {
        if ($content.IndexOf('Tj') -lt 0 -and $content.IndexOf('TJ') -lt 0) { continue }
        $curFont = ''
        foreach ($op in $pdfOpRx.Matches($content)) {
            if ($op.Groups[1].Success) { $curFont = $op.Groups[1].Value; continue }
            if ($op.Groups[2].Success) {
                [void]$sb.Append('('); [void]$sb.Append($op.Groups[2].Value); [void]$sb.Append(")Tj`n")
                continue
            }
            if ($op.Groups[3].Success) {
                $map = Get-FontMap $s $page $curFont $fontCache
                [void]$sb.Append('('); [void]$sb.Append((Escape-PdfLit (Convert-Hex $op.Groups[3].Value $map))); [void]$sb.Append(")Tj`n")
                continue
            }
            if ($op.Groups[4].Success) {
                $inner = New-Object System.Text.StringBuilder
                foreach ($pc in $pdfPieceRx.Matches($op.Groups[4].Value)) {
                    if ($pc.Groups[1].Success) { [void]$inner.Append($pc.Groups[1].Value) }
                    elseif ($pc.Groups[2].Success) {
                        $map = Get-FontMap $s $page $curFont $fontCache
                        [void]$inner.Append((Escape-PdfLit (Convert-Hex $pc.Groups[2].Value $map)))
                    }
                }
                [void]$sb.Append('('); [void]$sb.Append($inner.ToString()); [void]$sb.Append(")Tj`n")
                continue
            }
        }
    }
    [void]$sb.Append($s)
    return $sb.ToString()
}

function First([string]$text, [string]$pattern) {
    $m = [regex]::Match($text, $pattern)
    if ($m.Success) { return $m.Value } else { return $null }
}

function Get-Sord([string]$text) {
    $m = [regex]::Match($text, '(?:SORD\d+-\d+|TRN-ORD-\d+)')
    if ($m.Success) { return $m.Value }
    $sb = New-Object System.Text.StringBuilder
    foreach ($mm in [regex]::Matches($text, '\(((?:[^()\\]|\\.)*)\)\s*Tj')) {
        [void]$sb.Append(' ')
        [void]$sb.Append($mm.Groups[1].Value)
    }
    $m2 = [regex]::Match($sb.ToString(), '(?:SORD\d+-\s*\d+|TRN-\s*ORD-\s*\d+)')
    if ($m2.Success) { return ($m2.Value -replace '\s', '') }
    return $null
}

function Get-AllSords([string]$text) {
    $sb = New-Object System.Text.StringBuilder
    foreach ($mm in [regex]::Matches($text, '\(((?:[^()\\]|\\.)*)\)\s*Tj')) {
        [void]$sb.Append(' ')
        [void]$sb.Append($mm.Groups[1].Value)
    }
    $seen = New-Object System.Collections.Generic.List[string]
    foreach ($m in [regex]::Matches($sb.ToString(), '(?:SORD\d+-\s*\d+|TRN-\s*ORD-\s*\d+)')) {
        $v = $m.Value -replace '\s', ''
        if (-not $seen.Contains($v)) { $seen.Add($v) }
    }
    if ($seen.Count -eq 0) { return $null }
    $out = $seen[0]
    for ($i = 1; $i -lt $seen.Count; $i++) {
        $dm = [regex]::Match($seen[$i], '(\d+)\s*$')
        $suf = $dm.Groups[1].Value
        if ($suf.Length -gt 4) { $suf = $suf.Substring($suf.Length - 4) }
        $out = $out + '_' + $suf
    }
    return $out
}

function Format-SordDisplay([string]$name) {
    $m = [regex]::Match($name, '(?:SORD\d+-\d+|TRN-ORD-\d+)(?:_\d+)*')
    if (-not $m.Success) { return "" }
    $parts = $m.Value -split '_'
    $out = $parts[0]
    for ($i = 1; $i -lt $parts.Count; $i++) {
        $p = $parts[$i]
        if ($p.Length -gt 4) { $p = $p.Substring($p.Length - 4) }
        $out = $out + ', ' + $p
    }
    return $out
}

function Test-IsName([string]$s) {
    if (-not $s) { return $false }
    if ($s -notmatch '[A-Za-z]') { return $false }
    if ($s -match '^\d') { return $false }
    if ($s -match '^[A-Za-z]{2}-\d') { return $false }
    if ($s -match "^'?s\s") { return $false }
    if ($s -match '^(Code|Description|Package|appearance|Delivery Note|Packing List|Page|Truck|Destination|Customer|Sold To|Ship To|Deliver To|Source|Document|Planned|Release|Date|Action Type|Item|Bin|Lot|Serial|Notes|Carrier|STORAGE|U\.M\.|Q\.ty|UoM\.)$') { return $false }
    return $true
}

function Get-DestName([string]$text) {
    $toks = New-Object System.Collections.Generic.List[string]
    foreach ($m in [regex]::Matches($text, '\(((?:[^()\\]|\\.)*)\)\s*Tj')) {
        $toks.Add(($m.Groups[1].Value -replace '\\\(', '(' -replace '\\\)', ')').Trim())
    }
    for ($i = 0; $i -lt $toks.Count - 1; $i++) {
        if ($toks[$i] -eq 'Customer' -and (Test-IsName $toks[$i + 1])) { return (($toks[$i + 1] -split ',')[0]).Trim() }
    }
    for ($i = 0; $i -lt $toks.Count; $i++) {
        if ($toks[$i] -eq 'Destination') {
            for ($j = $i + 1; $j -lt $toks.Count -and $j -lt $i + 12; $j++) {
                if (Test-IsName $toks[$j]) { return (($toks[$j] -split ',')[0]).Trim() }
            }
            break
        }
    }
    return ""
}

function Get-Kunde([string]$text) {
    $v = Get-DestName $text
    if (-not $v) { return $null }
    $v = $v -replace '[\\/:*?"<>|]', ' '
    $parts = @($v -split '\s+' | Where-Object { $_ -ne '' -and $_ -notmatch '^[&+]+$' -and $_ -notmatch '^(and|und)$' })
    if ($parts.Count -eq 0) { return $null }
    if ($parts.Count -gt 2) { $parts = $parts[0..1] }
    return ($parts -join '_')
}

function Get-PwsFromPdf([string]$path) {
    try { $t = Get-PdfText $path } catch { return $null }
    return (First $t 'PWS\d+')
}

function Test-WorkFileExists([string]$nameOrPrefix) {
    if (-not $nameOrPrefix) { return $false }
    if ($nameOrPrefix -match '^GROUPAGE_(.+)$') {
        $key = $matches[1]
        $n = @(Get-ChildItem -LiteralPath $WorkDir -Filter ('WP*_' + $key + '_*.pdf') -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match ('^WP\d+_' + [regex]::Escape($key) + '_(?:SORD\d+-\d+|TRN-ORD-\d+)(?:_\d+)*\.pdf$') }).Count
        return ($n -ge 2)
    }
    if ($nameOrPrefix -match '^(PAC|PWS|WP)\d+$') {
        return (@(Get-ChildItem -LiteralPath $WorkDir -Filter ($nameOrPrefix + '*.pdf') -ErrorAction SilentlyContinue).Count -gt 0)
    }
    return (Test-Path -LiteralPath (Join-Path $WorkDir $nameOrPrefix))
}

function Invoke-Housekeeping {
    $pf = Get-PairsFile
    if (Test-Path -LiteralPath $pf) {
        $keep = New-Object System.Collections.Generic.List[string]
        foreach ($l in (Get-Content -LiteralPath $pf)) {
            if ($l -match '^(PAC\d+)=(PWS\d+)$') {
                if (Test-WorkFileExists $matches[1]) { $keep.Add($l) }
            }
        }
        try { Set-Content -LiteralPath $pf -Value $keep } catch { }
    }

    $prf = Get-PrintedFile
    if (Test-Path -LiteralPath $prf) {
        $keep = New-Object System.Collections.Generic.List[string]
        foreach ($l in (Get-Content -LiteralPath $prf)) {
            $t = $l.Trim()
            if (-not $t) { continue }
            if (Test-WorkFileExists $t) { $keep.Add($t) }
        }
        try { Set-Content -LiteralPath $prf -Value $keep } catch { }
    }
}



function Get-GroupageXlsx([string]$key) {
    $cand = @(Get-ChildItem -LiteralPath $WorkDir -Filter ("*Groupage_" + $key + ".xls*") -ErrorAction SilentlyContinue)
    if ($cand.Count -eq 0) {
        $nk = Normalize-Name $key
        $cand = @(Get-ChildItem -LiteralPath $WorkDir -Filter "*roupage*.xls*" -ErrorAction SilentlyContinue | Where-Object { (Normalize-Name $_.Name) -match [regex]::Escape($nk) })
    }
    if ($cand.Count -gt 0) { return $cand[$cand.Count - 1].FullName }
    return ""
}

function Get-ActiveGroupages {
    $result = New-Object System.Collections.Generic.List[object]
    $wpFiles = @(Get-ChildItem -LiteralPath $WorkDir -Filter 'WP*.pdf' -ErrorAction SilentlyContinue | Sort-Object Name)

    $byCustomer = @{}
    foreach ($f in $wpFiles) {
        if ($f.Name -match '^WP\d+_(.+)_(?:SORD\d+-\d+|TRN-ORD-\d+)(?:_\d+)*\.pdf$') {
            $key = $matches[1]
            if (-not $byCustomer.ContainsKey($key)) { $byCustomer[$key] = New-Object System.Collections.Generic.List[object] }
            $byCustomer[$key].Add($f)
        }
    }

    foreach ($key in ($byCustomer.Keys | Sort-Object)) {
        $list = $byCustomer[$key]
        if ($list.Count -lt 2) { continue }

        $stamped = New-Object System.Collections.Generic.List[object]
        foreach ($f in $list) {
            try { if ((Get-PdfText $f.FullName) -match 'GROUPAGE') { $stamped.Add($f) } } catch { }
        }
        if ($stamped.Count -lt 2) { continue }

        $xlsx = Get-GroupageXlsx $key
        $result.Add(@{
            Customer = $key
            Label    = (($key -replace '_', ' ') + " Groupage   (" + $stamped.Count + " pick lists)")
            Names    = @($stamped | ForEach-Object { $_.Name })
            Paths    = @($stamped | ForEach-Object { $_.FullName })
            Xlsx     = $xlsx
            HasXlsx  = ($xlsx -ne "")
            Id       = ("GROUPAGE_" + $key)
        })
    }
    return ,$result
}

function Set-GroupageData([string]$path, [string]$customer, [string[]]$wpNums) {
    $spin = Start-Spin ("filling " + [System.IO.Path]::GetFileName($path) + " in Excel...")
    $xl = $null
    $wb = $null
    try {
        try { $xl = New-Object -ComObject Excel.Application } catch {
            throw "Microsoft Excel could not be started (COM). Is Excel installed?"
        }
        $xl.Visible = $false
        $xl.DisplayAlerts = $false
        $xl.ScreenUpdating = $false

        $wb = $xl.Workbooks.Open($path)
        $ws = $wb.Worksheets.Item(1)

        $labelRow = 0
        $tableRow = 0
        for ($r = 1; $r -le 40; $r++) {
            $v = $ws.Cells($r, 1).Value2
            if (-not $v) { continue }
            $t = ([string]$v).Trim()
            if ($t -eq 'Kunde') { $labelRow = $r }
            if ($t -eq 'Picknummer') { $tableRow = $r }
        }
        if ($labelRow -gt 0) { $ws.Cells($labelRow, 2).Value2 = $customer }

        $n = $wpNums.Count
        if ($tableRow -gt 0 -and $n -gt 0) {
            $firstRow = $tableRow + 1
            $lastRow = $tableRow + $n
            try {
                if ($ws.ListObjects.Count -gt 0) {
                    $lo = $ws.ListObjects.Item(1)
                    $curLast = $lo.Range.Row + $lo.Range.Rows.Count - 1
                    if ($lastRow -gt $curLast) {
                        $lo.Resize($ws.Range($ws.Cells($tableRow, 1), $ws.Cells($lastRow, 3))) | Out-Null
                    }
                }
            } catch { }
            for ($i = 0; $i -lt $n; $i++) {
                $ws.Cells($firstRow + $i, 1).Value2 = $wpNums[$i]
            }
        }

        $wb.Save()
        $wb.Close($true)
        $xl.Quit()
        Stop-Spin $spin
        return $true
    } catch {
        Stop-Spin $spin
        try { if ($wb) { $wb.Close($false) } } catch { }
        try { if ($xl) { $xl.Quit() } } catch { }
        Write-Host ("     WARNING: could not prefill the groupage file: " + $_.Exception.Message) -ForegroundColor DarkYellow
        return $false
    } finally {
        foreach ($o in @($wb, $xl)) {
            try { if ($o) { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($o) } } catch { }
        }
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
    }
}

function Invoke-GroupageCheck {
    $wpFiles = @(Get-ChildItem -LiteralPath $WorkDir -Filter 'WP*.pdf' -ErrorAction SilentlyContinue)
    if ($wpFiles.Count -lt 2) { return }

    $groups = @{}
    foreach ($f in $wpFiles) {
        if ($f.Name -match '^WP\d+_(.+)_(?:SORD\d+-\d+|TRN-ORD-\d+)(?:_\d+)*\.pdf$') {
            $key = $matches[1]
            if (-not $groups.ContainsKey($key)) { $groups[$key] = New-Object System.Collections.Generic.List[object] }
            $groups[$key].Add($f)
        }
    }

    foreach ($key in ($groups.Keys | Sort-Object)) {
        $list = $groups[$key]
        if ($list.Count -lt 2) { continue }
        $display = $key -replace '_', ' '

        $ext = ".xlsx"
        $tpl = @(Get-ChildItem -LiteralPath $AppDir -Filter 'groupage_template.xls*' -ErrorAction SilentlyContinue)
        if ($tpl.Count -eq 0) { $tpl = @(Get-ChildItem -LiteralPath $AppDir -Filter '*Groupage TEMPLATE.xls*' -ErrorAction SilentlyContinue) }
        if ($tpl.Count -gt 0) { $ext = [System.IO.Path]::GetExtension($tpl[0].Name) }
        $newName = (Get-Date -Format 'yyyy-MM-dd') + "_Groupage_" + $key + $ext
        $newPath = Join-Path $WorkDir $newName

        $existing = @(Get-ChildItem -LiteralPath $WorkDir -Filter ('*_Groupage_' + $key + '.xls*') -ErrorAction SilentlyContinue)
        if ($existing.Count -gt 0) {
            Write-Host ("   Groupage " + $display + " already created: " + $existing[0].Name) -ForegroundColor DarkGray
            continue
        }

        Write-Host ""
        Write-Host $light -ForegroundColor DarkCyan
        Write-Host ("   GROUPAGE detected:  " + $display + "   (" + $list.Count + " pick lists)") -ForegroundColor Yellow
        foreach ($f in $list) { Write-Host ("     " + $f.Name) -ForegroundColor DarkGray }
        Write-Host ""
        $ans = Read-Host "   Create groupage? (Y/N)"
        if (-not ($ans -match '^\s*[yj]')) {
            Write-Host "   Skipped." -ForegroundColor DarkGray
            continue
        }

        foreach ($f in $list) {
            try {
                if ((Get-PdfText $f.FullName) -match 'GROUPAGE') {
                    Write-Host ("     already marked : " + $f.Name) -ForegroundColor DarkGray
                } else {
                    Add-Stamp $f.FullName @("GROUPAGE")
                    Write-Host ("     marked GROUPAGE: " + $f.Name) -ForegroundColor Green
                }
            } catch {
                Write-Host ("     ERROR marking " + $f.Name + ": " + $_.Exception.Message) -ForegroundColor Red
            }
        }

        if ($tpl.Count -eq 0) {
            Write-Host "     Template not found in the PROMEDIA COPILOT folder." -ForegroundColor Yellow
            Write-Host "     Put 'groupage_template.xlsx' there, then run again." -ForegroundColor DarkGray
            continue
        }

        try {
            if (Test-Path -LiteralPath $newPath) {
                Write-Host ("     exists already : " + $newName) -ForegroundColor DarkYellow
            } else {
                Copy-Item -LiteralPath $tpl[0].FullName -Destination $newPath
                try { Unblock-File -LiteralPath $newPath -ErrorAction SilentlyContinue } catch { }
                Write-Host ("     created        : " + $newName) -ForegroundColor Green

                $wpNums = New-Object System.Collections.Generic.List[string]
                foreach ($f in ($list | Sort-Object Name)) {
                    if ($f.Name -match '^(WP\d+)') {
                        if (-not $wpNums.Contains($matches[1])) { $wpNums.Add($matches[1]) }
                    }
                }
                if (Set-GroupageData $newPath $display $wpNums.ToArray()) {
                    Write-Host ("     prefilled      : customer + " + $wpNums.Count + " pick number(s)") -ForegroundColor Green
                    Write-Host "     please fill in the remaining fields" -ForegroundColor Yellow
                }
            }
            Start-Process -FilePath $newPath
        } catch {
            Write-Host ("     ERROR creating groupage file: " + $_.Exception.Message) -ForegroundColor Red
        }
    }
}

function Start-Spin([string]$text) {
    try {
        $sync = [hashtable]::Synchronized(@{ Stop = $false; Text = $text })
        $rs = [runspacefactory]::CreateRunspace()
        $rs.Open()
        $rs.SessionStateProxy.SetVariable('sync', $sync)
        $ps = [powershell]::Create()
        $ps.Runspace = $rs
        [void]$ps.AddScript({
            $frames = @('|', '/', '-', '\')
            $i = 0
            while (-not $sync.Stop) {
                try {
                    [Console]::Write("`r   " + $frames[$i % 4] + "  " + $sync.Text + "        ")
                } catch { }
                Start-Sleep -Milliseconds 110
                $i++
            }
        })
        $handle = $ps.BeginInvoke()
        return @{ Sync = $sync; Ps = $ps; Rs = $rs; Handle = $handle }
    } catch {
        try { Write-Host ("   " + $text) -ForegroundColor DarkCyan } catch { }
        return $null
    }
}

function Stop-Spin($spin) {
    if (-not $spin) { return }
    try { $spin.Sync.Stop = $true } catch { }
    try { [void]$spin.Ps.EndInvoke($spin.Handle) } catch { }
    try { $spin.Ps.Dispose() } catch { }
    try { $spin.Rs.Close(); $spin.Rs.Dispose() } catch { }
    try { [Console]::Write("`r" + (' ' * 78) + "`r") } catch { }
}

$script:AppVersion = '1.0.0'

function Get-PdfTjTokens([string]$path) {
    $bytes = [System.IO.File]::ReadAllBytes($path)
    $raw = $latin.GetString($bytes)
    $sb = New-Object System.Text.StringBuilder
    foreach ($m in $streamRx.Matches($raw)) {
        $dec = Inflate ($latin.GetBytes($m.Groups[1].Value))
        if ($dec) { [void]$sb.Append($latin.GetString($dec)) }
    }
    $txt = $sb.ToString()
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($m in [regex]::Matches($txt, '\(((?:[^()\\]|\\.)*)\)\s*Tj')) {
        $v = $m.Groups[1].Value
        $v = $v -replace '\\\(', '(' -replace '\\\)', ')' -replace '\\\\', '\'
        $out.Add($v.Trim())
    }
    return $out
}

function Get-PumpDataFromPdf([string]$path) {
    $toks = Get-PdfTjTokens $path
    if ($toks.Count -eq 0) { return $null }

    $res = @{ Wp = ''; Kunde = ''; Rows = (New-Object System.Collections.Generic.List[object]) }
    $seen = @{}
    $curBin = ''
    $isPick = $false

    for ($i = 0; $i -lt $toks.Count; $i++) {
        $v = $toks[$i]
        if (-not $v) { continue }

        if ($v -match 'Warehouse Activity Header') { $isPick = $true }
        if (-not $res.Wp -and $v -match '(WP\d+)') { $res.Wp = $matches[1] }
        if (-not $res.Kunde -and $v -eq 'Destination') {
            $nx = $i + 1
            if ($nx -lt $toks.Count) { $res.Kunde = $toks[$nx].Trim() }
        }

        if ($v -match '^(PICKING|[A-Z][A-Z0-9]{0,6}\d\.\d+)$') { $curBin = $v; continue }

        if ($v -match '^N\d{8,}$') {
            if ($curBin -and $curBin -ne 'PICKING' -and -not $seen.ContainsKey($v)) {
                $seen[$v] = $true
                $res.Rows.Add(@{ Serial = $v; Bin = $curBin })
            }
        }
    }

    if (-not $isPick) { return $null }
    return $res
}

function Format-KundeName([string]$v) {
    if (-not $v) { return '' }
    $v = $v -replace '[\\/:*?"<>|]', ' '
    $parts = @($v -split '\s+' | Where-Object { $_ -ne '' -and $_ -notmatch '^[&+]+$' -and $_ -notmatch '^(?i)(and|und)$' })
    if ($parts.Count -eq 0) { return '' }
    if ($parts.Count -gt 2) { $parts = $parts[0..1] }
    return ($parts -join '_')
}

function Set-SheetArray($ws, [int]$startRow, [int]$startCol, $arr) {
    $rows = $arr.GetLength(0)
    $cols = $arr.GetLength(1)
    $r2 = $startRow + $rows - 1
    $c2 = $startCol + $cols - 1
    try {
        $rng = $ws.Range($ws.Cells($startRow, $startCol), $ws.Cells($r2, $c2))
        $rng.Value2 = $arr
        $probe = $ws.Cells($startRow, $startCol).Value2
        if ($rows -gt 0 -and $cols -gt 0 -and $null -eq $probe -and $null -ne $arr[0, 0]) {
            throw "range write did not take"
        }
        return
    } catch {
        for ($i = 0; $i -lt $rows; $i++) {
            for ($j = 0; $j -lt $cols; $j++) {
                $ws.Cells($startRow + $i, $startCol + $j).Value2 = $arr[$i, $j]
            }
        }
    }
}

function Get-PumpTemplate {
    foreach ($pat in @('pumplist_template.xls*', '*Pumpen TEMPLATE.xls*', '*pump*template*.xls*')) {
        $t = @(Get-ChildItem -LiteralPath $AppDir -Filter $pat -ErrorAction SilentlyContinue)
        if ($t.Count -gt 0) { return $t[0] }
    }
    return $null
}

function Get-ControlTemplate {
    foreach ($pat in @('pump_control_template.xls*', '*control*template*.xls*')) {
        $t = @(Get-ChildItem -LiteralPath $AppDir -Filter $pat -ErrorAction SilentlyContinue)
        if ($t.Count -gt 0) { return $t[0] }
    }
    return $null
}

function New-ControlWorkbook($data) {
    $tpl = Get-ControlTemplate
    if (-not $tpl) {
        Write-Host "     Control template not found ('pump_control_template.xlsx')." -ForegroundColor Yellow
        return $null
    }

    $wp = $data.Wp
    if (-not $wp) { $wp = 'WP' }
    $kunde = Format-KundeName $data.Kunde
    $baseName = $wp + "_Control.xlsx"
    if ($kunde) { $baseName = $wp + "_" + $kunde + "_Control.xlsx" }

    $newName = $baseName
    $newPath = Join-Path $WorkDir $newName
    $n = 2
    while (Test-Path -LiteralPath $newPath) {
        $stem = [System.IO.Path]::GetFileNameWithoutExtension($baseName)
        $newName = $stem + " (" + $n + ").xlsx"
        $newPath = Join-Path $WorkDir $newName
        $n++
    }

    Copy-Item -LiteralPath $tpl.FullName -Destination $newPath
    try { Unblock-File -LiteralPath $newPath -ErrorAction SilentlyContinue } catch { }

    $spin = Start-Spin ("building " + $newName + " in Excel...")
    $xl = $null
    $wbT = $null
    try {
        try { $xl = New-Object -ComObject Excel.Application } catch {
            throw "Microsoft Excel could not be started (COM). Is Excel installed?"
        }
        $xl.Visible = $false
        $xl.DisplayAlerts = $false
        $xl.ScreenUpdating = $false

        $wbT = $xl.Workbooks.Open($newPath)
        $wsP = $wbT.Worksheets.Item("Warehouse Pick")

        $serCol = 0
        for ($c = 1; $c -le 60; $c++) {
            $h = $wsP.Cells(1, $c).Value2
            if ($h -and ([string]$h).Trim() -eq 'Serial No.') { $serCol = $c; break }
        }
        if ($serCol -eq 0) { throw "Column 'Serial No.' not found in sheet 'Warehouse Pick'." }

        $rows = $data.Rows
        $cnt = $rows.Count
        $arr = New-Object 'object[,]' $cnt, 1
        for ($i = 0; $i -lt $cnt; $i++) {
            $arr[$i, 0] = $rows[$i].Serial
        }
        Set-SheetArray $wsP 2 $serCol $arr

        $xl.CalculateFullRebuild()
        $wsS = $wbT.Worksheets.Item("Scan")
        $wsS.Activate()
        try { $wsS.Range("D5").Select() | Out-Null } catch { }
        $wbT.Save()
        $wbT.Close($true)
        $xl.Quit()

        Stop-Spin $spin
        Write-Host ("     created        : " + $newName + "   (" + $cnt + " serials to scan)") -ForegroundColor Green
        return @{ Path = $newPath; Name = $newName }
    } catch {
        Stop-Spin $spin
        try { if ($wbT) { $wbT.Close($false) } } catch { }
        try { if ($xl) { $xl.Quit() } } catch { }
        try { Remove-Item -LiteralPath $newPath -Force -ErrorAction SilentlyContinue } catch { }
        Write-Host ("     ERROR: " + $_.Exception.Message) -ForegroundColor Red
        return $null
    } finally {
        foreach ($o in @($wbT, $xl)) {
            try { if ($o) { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($o) } } catch { }
        }
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
    }
}

function Get-PumpFileName($data) {
    $wp = $data.Wp
    if (-not $wp) { $wp = 'WP' }
    $kunde = Format-KundeName $data.Kunde
    if ($kunde) { return ($wp + "_" + $kunde + "_Pumpen.xlsx") }
    return ($wp + "_Pumpen.xlsx")
}

function New-PumpWorkbook($data, [string]$srcName) {
    $tpl = Get-PumpTemplate
    if (-not $tpl) {
        Write-Host "     Template not found in the PROMEDIA COPILOT folder." -ForegroundColor Yellow
        Write-Host "     Put 'pumplist_template.xlsx' there, then run again." -ForegroundColor DarkGray
        return $null
    }

    $wp = $data.Wp
    if (-not $wp) { $wp = 'WP' }
    $kunde = (Format-KundeName $data.Kunde) -replace '_', ' '
    $title = ($wp + " " + $kunde + " Pumpen") -replace "\s+", " "

    $baseName = Get-PumpFileName $data
    $newName = $baseName
    $newPath = Join-Path $WorkDir $newName
    $n = 2
    while (Test-Path -LiteralPath $newPath) {
        $stem = [System.IO.Path]::GetFileNameWithoutExtension($baseName)
        $newName = $stem + " (" + $n + ").xlsx"
        $newPath = Join-Path $WorkDir $newName
        $n++
    }

    Copy-Item -LiteralPath $tpl.FullName -Destination $newPath
    try { Unblock-File -LiteralPath $newPath -ErrorAction SilentlyContinue } catch { }

    $spin = Start-Spin ("building " + $newName + " in Excel...")
    $xl = $null
    $wbT = $null
    $ok = $false
    try {
        try { $xl = New-Object -ComObject Excel.Application } catch {
            throw "Microsoft Excel could not be started (COM). Is Excel installed?"
        }
        $xl.Visible = $false
        $xl.DisplayAlerts = $false
        $xl.ScreenUpdating = $false

        $wbT = $xl.Workbooks.Open($newPath)
        $wsT = $wbT.Worksheets.Item("Lines")

        $rows = $data.Rows
        $cnt = $rows.Count
        $lastRow = $cnt + 1
        $arr = New-Object 'object[,]' $lastRow, 2
        $arr[0, 0] = 'Serial No.'
        $arr[0, 1] = 'Bin Code'
        for ($i = 0; $i -lt $cnt; $i++) {
            $t = $i + 1
            $arr[$t, 0] = $rows[$i].Serial
            $arr[$t, 1] = $rows[$i].Bin
        }
        Set-SheetArray $wsT 1 1 $arr

        $wsA = $wbT.Worksheets.Item("Pump Bins")
        $wsA.Range("A1").Value2 = $title
        $xl.CalculateFullRebuild()

        $pumps = 0
        try { $pumps = [int]$wsA.Range("K3").Value2 } catch { }

        $wsA.Activate()
        try { $wsA.Range("A1").Select() | Out-Null } catch { }
        $wbT.Save()
        $wbT.Close($true)
        $xl.Quit()
        $ok = $true

        Stop-Spin $spin
        Write-Host ("     created        : " + $newName + "   (" + $pumps + " pumps)") -ForegroundColor Green
        return @{ Path = $newPath; Name = $newName; Pumps = $pumps }
    } catch {
        Stop-Spin $spin
        try { if ($wbT) { $wbT.Close($false) } } catch { }
        try { if ($xl) { $xl.Quit() } } catch { }
        try { Remove-Item -LiteralPath $newPath -Force -ErrorAction SilentlyContinue } catch { }
        Write-Host ("     ERROR: " + $_.Exception.Message) -ForegroundColor Red
        return $null
    } finally {
        foreach ($o in @($wbT, $xl)) {
            try { if ($o) { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($o) } } catch { }
        }
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
    }
}

function Get-PumpSources {
    $sources = New-Object System.Collections.Generic.List[object]
    $spin = Start-Spin "scanning pick lists for pumps..."
    foreach ($f in @(Get-ChildItem -LiteralPath $WorkDir -Filter '*.pdf' -ErrorAction SilentlyContinue | Sort-Object Name)) {
        $data = $null
        try { $data = Get-PumpDataFromPdf $f.FullName } catch { $data = $null }
        if ($data -and $data.Rows.Count -gt 0) {
            $sources.Add(@{ File = $f; Data = $data })
        }
    }
    Stop-Spin $spin
    return $sources
}

function Invoke-PumpCheck {
    $sources = Get-PumpSources
    if ($sources.Count -eq 0) { return }

    foreach ($s in $sources) {
        $data = $s.Data
        $kunde = (Format-KundeName $data.Kunde) -replace '_', ' '
        $target = Join-Path $WorkDir (Get-PumpFileName $data)
        if (Test-Path -LiteralPath $target) { continue }

        Write-Host ""
        Write-Host $light -ForegroundColor DarkCyan
        Write-Host ("   PUMPS detected:  " + $data.Wp + "  " + $kunde + "   (" + $data.Rows.Count + " Compat Ella pumps)") -ForegroundColor Yellow
        Write-Host ("     " + $s.File.Name) -ForegroundColor DarkGray
        Write-Host ""
        $ans = Read-Host "   Create pump list? (Y/N)"
        if (-not ($ans -match '^\s*[yj]')) {
            Write-Host "   Skipped." -ForegroundColor DarkGray
            continue
        }

        $res = New-PumpWorkbook $data $s.File.Name
        if ($res) {
            [void](New-ControlWorkbook $data)
            Start-Process -FilePath $res.Path
        }
    }
}

function Invoke-PumpList {
    $sources = Get-PumpSources

    if ($sources.Count -eq 0) {
        Write-Host "  No pick list with pumps found in this folder." -ForegroundColor Yellow
        Write-Host "  Put the picking list PDF from Business Central here first." -ForegroundColor DarkGray
        return
    }

    $src = $sources[0]
    if ($sources.Count -gt 1) {
        $items = @($sources | ForEach-Object {
            $k = (Format-KundeName $_.Data.Kunde) -replace '_', ' '
            $_.Data.Wp.PadRight(10) + $k.PadRight(22) + $_.Data.Rows.Count.ToString().PadLeft(4) + " pumps    " + $_.File.Name
        })
        $sel = Show-Menu "PUMP LIST  -  SELECT PICK LIST" ($items + @("", "Back"))
        if ($sel -lt 0 -or $sel -ge $sources.Count) { return }
        $src = $sources[$sel]
    }

    $kunde = (Format-KundeName $src.Data.Kunde) -replace '_', ' '
    Clear-Host
    Show-Header
    Write-Host ""
    Write-Host ("   Source   : " + $src.File.Name) -ForegroundColor DarkGray
    Write-Host ("   WP       : " + $src.Data.Wp + "  " + $kunde) -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "   Working..." -ForegroundColor DarkCyan
    Write-Host ""

    $res = New-PumpWorkbook $src.Data $src.File.Name
    if ($res) {
        [void](New-ControlWorkbook $src.Data)
        Write-Host ""
        Start-Process -FilePath $res.Path
    }
}

function Invoke-Rename {
    $files = Get-ChildItem -LiteralPath $WorkDir -Filter *.pdf | ForEach-Object { $_.FullName }
    if (-not $files -or $files.Count -eq 0) {
        Write-Host "  No PDF files found in this folder." -ForegroundColor Yellow
        return
    }

    $renamed = 0
    $skipped = 0
    $fail = 0
    $missingPairs = 0

    $pairFile = Get-PairsFile
    $pairs = @{}
    if (Test-Path -LiteralPath $pairFile) {
        foreach ($l in (Get-Content -LiteralPath $pairFile)) {
            if ($l -match '^(PAC\d+)=(PWS\d+)$') { $pairs[$matches[1]] = $matches[2] }
        }
    }

    foreach ($f in $files) {
        $orig = [System.IO.Path]::GetFileName($f)
        $spin = Start-Spin ("reading " + $orig + "...")
        $text = $null
        try { $text = Get-PdfText $f } catch { $text = $null }
        Stop-Spin $spin
        if (-not $text) {
            Write-Host ("  ERROR reading: " + $orig) -ForegroundColor Red
            $fail++
            continue
        }

        $pac  = First $text 'PAC\d+'
        $pws  = First $text 'PWS\d+'
        $wp   = First $text 'WP\d+'
        $sord = Get-AllSords $text
        if ($pac) { $pac = $pac.ToUpper() }
        if ($pws) { $pws = $pws.ToUpper() }
        if ($wp) { $wp = $wp.ToUpper() }
        if ($sord) { $sord = $sord.ToUpper() }

        if ($pac -and $pws) { $pairs[$pac] = $pws }

        $newName = $null
        if ($pac -and $sord) {
            $newName = "${pac}_${sord}.pdf"
        } elseif ($pws -and $sord) {
            $newName = "${pws}_${sord}.pdf"
        } elseif ($wp -and $sord) {
            $kunde = Get-Kunde $text
            if ($kunde) { $newName = "${wp}_$($kunde.ToUpper())_${sord}.pdf" }
            else { $newName = "${wp}_${sord}.pdf" }
        }

        if (-not $newName) {
            Write-Host ("  skipped (not a delivery document): " + $orig) -ForegroundColor DarkGray
            continue
        }

        if ($orig -ceq $newName) { $skipped++; continue }

        $target = Join-Path $WorkDir $newName
        $caseOnly = ($orig -eq $newName)
        if (-not $caseOnly -and (Test-Path -LiteralPath $target)) {
            Write-Host ("  skipped (target already exists): " + $orig) -ForegroundColor DarkYellow
            $skipped++
            continue
        }

        if ($caseOnly) {
            $tmp = Join-Path $WorkDir ($newName + '.__case')
            Move-Item -LiteralPath $f -Destination $tmp -Force
            Move-Item -LiteralPath $tmp -Destination $target -Force
        } else {
            Move-Item -LiteralPath $f -Destination $target
        }
        Write-Host ("  " + $orig + "  ->  " + $newName) -ForegroundColor Green
        $renamed++
    }

    if ($pairs.Count -gt 0) {
        try { Set-Content -LiteralPath $pairFile -Value (@($pairs.GetEnumerator() | ForEach-Object { $_.Key + "=" + $_.Value })) } catch { }
    }

    $pacFiles = @(Get-ChildItem -LiteralPath $WorkDir -Filter 'PAC*.pdf' -ErrorAction SilentlyContinue)
    $pwsFiles = @(Get-ChildItem -LiteralPath $WorkDir -Filter 'PWS*.pdf' -ErrorAction SilentlyContinue)
    $pwsByNum = @{}
    foreach ($f in $pwsFiles) { if ($f.Name -match '^(PWS\d+)') { $pwsByNum[$matches[1]] = $true } }
    $pacByNum = @{}
    foreach ($f in $pacFiles) { if ($f.Name -match '^(PAC\d+)') { $pacByNum[$matches[1]] = $true } }

    foreach ($f in $pacFiles) {
        if ($f.Name -notmatch '^(PAC\d+)') { continue }
        $pacNum = $matches[1]
        $pwsNum = $pairs[$pacNum]
        if (-not $pwsNum) { $pwsNum = Get-PwsFromPdf $f.FullName }
        if ($pwsNum -and -not $pwsByNum.ContainsKey($pwsNum)) {
            Write-Host ("  ERROR: " + $pacNum + " is missing its PWS pair (" + $pwsNum + ")") -ForegroundColor Red
            $missingPairs++
        }
    }

    $pwsToPac = @{}
    foreach ($e in $pairs.GetEnumerator()) { $pwsToPac[$e.Value] = $e.Key }
    foreach ($f in $pwsFiles) {
        if ($f.Name -notmatch '^(PWS\d+)') { continue }
        $pwsNum = $matches[1]
        $pacNum = $pwsToPac[$pwsNum]
        if ($pacNum -and -not $pacByNum.ContainsKey($pacNum)) {
            Write-Host ("  ERROR: " + $pwsNum + " is missing its PAC pair (" + $pacNum + ")") -ForegroundColor Red
            $missingPairs++
        }
    }

    Invoke-GroupageCheck
    Invoke-PumpCheck

    Write-Host ""
    Write-Host $light -ForegroundColor DarkCyan
    Write-Host "   SUMMARY" -ForegroundColor Cyan
    Write-Host ("     Renamed        : " + $renamed) -ForegroundColor Green
    Write-Host ("     Already ok     : " + $skipped) -ForegroundColor DarkGray
    $failColor = if ($fail -gt 0) { "Red" } else { "DarkGray" }
    Write-Host ("     Errors         : " + $fail) -ForegroundColor $failColor
    $pairColor = if ($missingPairs -gt 0) { "Red" } else { "DarkGray" }
    Write-Host ("     Missing pairs  : " + $missingPairs) -ForegroundColor $pairColor
}

function Add-Stamp([string]$path, [string[]]$lines, [int]$x = 495) {
    $bytes = [System.IO.File]::ReadAllBytes($path)
    $s = $latin.GetString($bytes)

    $prevMatches = [regex]::Matches($s, 'startxref\s+(\d+)\s+%%EOF')
    if ($prevMatches.Count -eq 0) { throw "No startxref found" }
    $prev = $prevMatches[$prevMatches.Count - 1].Groups[1].Value

    $sizeMatches = [regex]::Matches($s, '/Size\s+(\d+)')
    $newObj = [int]$sizeMatches[$sizeMatches.Count - 1].Groups[1].Value

    $root = [regex]::Match($s, '/Root\s+(\d+\s+0\s+R)').Groups[1].Value
    $infoM = [regex]::Match($s, '/Info\s+(\d+\s+0\s+R)')

    $pageNum = $null
    $pageBody = $null
    foreach ($m in [regex]::Matches($s, '(\d+)\s+0\s+obj(.*?)endobj', [System.Text.RegularExpressions.RegexOptions]::Singleline)) {
        if ($m.Groups[2].Value -match '/Type\s*/Page(?!s)') {
            $pageNum = $m.Groups[1].Value
            $pageBody = $m.Groups[2].Value
            break
        }
    }
    if (-not $pageNum) { throw "No page object found" }

    $defs = [regex]::Matches($s, '(?<![0-9])' + $pageNum + '\s+0\s+obj(.*?)endobj', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if ($defs.Count -gt 0) { $pageBody = $defs[$defs.Count - 1].Groups[1].Value }

    $cm = [regex]::Match($pageBody, '/Contents\s*(\d+\s+0\s+R)')
    if (-not $cm.Success) { $cm = [regex]::Match($pageBody, '/Contents\s*\[([^\]]*)\]') }
    $existing = $cm.Groups[1].Value.Trim()
    $newPage = [regex]::Replace($pageBody, '/Contents\s*(?:\d+\s+0\s+R|\[[^\]]*\])', "/Contents[$existing $newObj 0 R]")

    $font = [regex]::Match($pageBody, '/Font\s*<<\s*/([A-Za-z0-9]+)').Groups[1].Value
    if (-not $font) { $font = "F1" }

    $y = 560
    $size = 14
    $lh = 22

    $marks = [regex]::Matches($s, '%\s*DWSTAMP\s+END=(\d+)')
    if ($marks.Count -gt 0) {
        $minY = 999999
        foreach ($mk in $marks) {
            $v = [int]$mk.Groups[1].Value
            if ($v -lt $minY) { $minY = $v }
        }
        $y = $minY - $lh - 6
        if ($y -lt 460) { $y = 460 }
    }

    $ops = New-Object System.Collections.Generic.List[string]
    $ops.Add("q BT /$font $size Tf 0 0 0 rg $x $y Td $lh TL")
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $t = $lines[$i]
        $t = $t -replace '\\', '\\'
        $t = $t -replace '\(', '\('
        $t = $t -replace '\)', '\)'
        if ($i -eq 0) { $ops.Add("($t) Tj") } else { $ops.Add("T* ($t) Tj") }
    }
    $ops.Add("ET Q")
    $lastY = $y - (($lines.Count - 1) * $lh)
    $content = ($ops -join " ") + "`n% DWSTAMP END=" + $lastY + "`n"
    $contentLen = $latin.GetBytes($content).Length

    $pageObj = "$pageNum 0 obj`n$newPage`nendobj`n"
    $strmObj = "$newObj 0 obj`n<</Length $contentLen>>`nstream`n$content`nendstream`nendobj`n"

    if (-not $s.EndsWith("`n")) { $s += "`n" }
    $offPage = $s.Length
    $s += $pageObj
    $offStrm = $s.Length
    $s += $strmObj
    $xrefPos = $s.Length

    $xref = "xref`n0 1`n0000000000 65535 f`r`n"
    $xref += "$pageNum 1`n" + ('{0:D10} 00000 n' -f $offPage) + "`r`n"
    $xref += "$newObj 1`n" + ('{0:D10} 00000 n' -f $offStrm) + "`r`n"

    $info = ""
    if ($infoM.Success) { $info = "/Info " + $infoM.Groups[1].Value }
    $trailer = "trailer`n<</Size $($newObj + 1)/Root $root$info/Prev $prev>>`nstartxref`n$xrefPos`n%%EOF`n"

    $s += $xref + $trailer
    [System.IO.File]::WriteAllBytes($path, $latin.GetBytes($s))
}

function Invoke-Annotate {
    $wpFiles = @(Get-ChildItem -LiteralPath $WorkDir -Filter 'WP*.pdf' | Sort-Object Name)
    if ($wpFiles.Count -eq 0) {
        Write-Host "  No WP documents found. Rename your picking lists first (option 1)." -ForegroundColor Yellow
        return
    }

    $items = @($wpFiles | ForEach-Object { $_.Name }) + "" + "Back"
    $sel = Show-Menu "SELECT WP DOCUMENT" $items
    if ($sel -lt 0 -or $items[$sel] -eq "Back") { $script:SkipPause = $true; return }
    $file = $wpFiles[$sel].FullName

    $docName = $wpFiles[$sel].Name
    $isGroupage = $false
    $aspin = Start-Spin ("reading " + $docName + "...")
    try { if ((Get-PdfText $file) -match 'GROUPAGE') { $isGroupage = $true } } catch { }
    Stop-Spin $aspin

    $lines = New-Object System.Collections.Generic.List[string]
    while ($true) {
        Clear-Host
        Show-Header
        Write-Host ""
        Write-Host ("   ANNOTATE:  " + $docName) -ForegroundColor Cyan
        if ($isGroupage) {
            Write-Host "   This document is marked GROUPAGE - your text is placed below it." -ForegroundColor DarkYellow
        }
        Write-Host ""
        Write-Host "   ENTER on empty line = save     del = delete last line     cancel = cancel" -ForegroundColor DarkGray
        Write-Host $light -ForegroundColor DarkCyan
        Write-Host ""
        if ($lines.Count -eq 0) {
            Write-Host "   (no text yet)" -ForegroundColor DarkGray
        } else {
            for ($i = 0; $i -lt $lines.Count; $i++) {
                Write-Host ("   " + ($i + 1) + ":  " + $lines[$i]) -ForegroundColor Green
            }
        }
        Write-Host ""
        $line = Read-Host ("   " + ($lines.Count + 1))

        if ([string]::IsNullOrEmpty($line)) { break }
        $cmd = $line.Trim()
        if (($cmd -ieq 'del') -or ($cmd -eq '-')) {
            if ($lines.Count -gt 0) { $lines.RemoveAt($lines.Count - 1) }
            continue
        }
        if ($cmd -ieq 'cancel') {
            $script:SkipPause = $true
            return
        }
        $lines.Add($line)
    }

    Clear-Host
    Show-Header
    Write-Host ""

    if ($lines.Count -eq 0) {
        Write-Host "   Nothing entered, cancelled." -ForegroundColor Yellow
        $script:SkipPause = $true
        return
    }

    $sspin = Start-Spin ("stamping " + $docName + "...")
    try {
        Add-Stamp $file $lines.ToArray() 380
        Stop-Spin $sspin
        Write-Host ("   Saved. Stamped " + $lines.Count + " line(s) onto page 1 of") -ForegroundColor Green
        Write-Host ("   " + $docName) -ForegroundColor Green
    } catch {
        Stop-Spin $sspin
        Write-Host ("   ERROR while stamping: " + $_.Exception.Message) -ForegroundColor Red
    }
}

function Show-DocMenu {
    param([string]$Title, [object[]]$Entries)
    $selectable = @()
    for ($i = 0; $i -lt $Entries.Count; $i++) { if (-not $Entries[$i].Header) { $selectable += $i } }
    if ($selectable.Count -eq 0) { return -1 }
    $pos = 0
    $top = 0
    try { [Console]::CursorVisible = $false } catch { }
    while ($true) {
        $rows = Get-ViewRows
        $cur = $selectable[$pos]
        if ($cur -lt $top) { $top = $cur }
        if ($cur -ge $top + $rows) { $top = $cur - $rows + 1 }
        if ($top -gt $Entries.Count - $rows) { $top = $Entries.Count - $rows }
        if ($top -lt 0) { $top = 0 }
        $end = [math]::Min($top + $rows - 1, $Entries.Count - 1)

        $frame = Get-HeaderRows
        $frame.Add(@(@{ T = ""; F = "Gray" }))
        $frame.Add(@(@{ T = ("   " + $Title); F = "Cyan" }))
        $frame.Add(@(@{ T = ""; F = "Gray" }))
        for ($i = $top; $i -le $end; $i++) {
            $e = $Entries[$i]
            if ($e.Header) {
                if ($e.Text -eq "") { $frame.Add(@(@{ T = ""; F = "Gray" })) }
                else { $frame.Add(@(@{ T = ("   " + $e.Text); F = "Yellow" })) }
            } elseif ($i -eq $cur) {
                $frame.Add(@(@{ T = ("   > " + ([string]$e.Text).PadRight(58)); F = "Black"; B = "Cyan" }))
            } elseif ($e.Done) {
                $frame.Add(@(@{ T = ("     " + $e.Text); F = "DarkGreen" }))
            } else {
                $frame.Add(@(@{ T = ("     " + $e.Text); F = "Gray" }))
            }
        }
        $frame.Add(@(@{ T = ""; F = "Gray" }))
        $hint = "   Up/Down = move     Enter = select     Esc / Backspace = back"
        if ($top -gt 0 -or $end -lt $Entries.Count - 1) {
            $hint = $hint + "     " + ($pos + 1) + "/" + $selectable.Count
        }
        $frame.Add(@(@{ T = $hint; F = "DarkGray" }))
        $grid = Render-Frame $frame

        $key = Wait-KeyWithSnow $grid
        if ($null -eq $key) { continue }
        switch ($key.Key) {
            'UpArrow'   { $pos = ($pos - 1 + $selectable.Count) % $selectable.Count }
            'DownArrow' { $pos = ($pos + 1) % $selectable.Count }
            'Home'      { $pos = 0 }
            'End'       { $pos = $selectable.Count - 1 }
            'PageUp'    { $pos = [math]::Max(0, $pos - 10) }
            'PageDown'  { $pos = [math]::Min($selectable.Count - 1, $pos + 10) }
            'Enter'     { try { [Console]::CursorVisible = $true } catch { }; Clear-Host; return $selectable[$pos] }
            'Escape'    { try { [Console]::CursorVisible = $true } catch { }; Clear-Host; return -1 }
            'Backspace' { try { [Console]::CursorVisible = $true } catch { }; Clear-Host; return -1 }
            'Delete'    { try { [Console]::CursorVisible = $true } catch { }; Clear-Host; return -1 }
        }
    }
}

function Print-Pdf([string]$path, [string]$printerName, [int]$copies) {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime | Out-Null
    Add-Type -AssemblyName System.Drawing | Out-Null

    $asOp = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
        $_.Name -eq 'AsTask' -and $_.IsGenericMethodDefinition -and $_.GetParameters().Count -eq 1 -and
        $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
    } | Select-Object -First 1

    $asAct = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
        $_.Name -eq 'AsTask' -and -not $_.IsGenericMethodDefinition -and $_.GetParameters().Count -eq 1 -and
        $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncAction'
    } | Select-Object -First 1

    [void][Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
    [void][Windows.Data.Pdf.PdfDocument, Windows.Data.Pdf, ContentType = WindowsRuntime]
    [void][Windows.Storage.Streams.InMemoryRandomAccessStream, Windows.Storage.Streams, ContentType = WindowsRuntime]
    [void][Windows.Data.Pdf.PdfPageRenderOptions, Windows.Data.Pdf, ContentType = WindowsRuntime]

    $fileOp = [Windows.Storage.StorageFile]::GetFileFromPathAsync($path)
    $fileTask = $asOp.MakeGenericMethod([Windows.Storage.StorageFile]).Invoke($null, @($fileOp))
    $fileTask.Wait(-1) | Out-Null
    $file = $fileTask.Result

    $pdfOp = [Windows.Data.Pdf.PdfDocument]::LoadFromFileAsync($file)
    $pdfTask = $asOp.MakeGenericMethod([Windows.Data.Pdf.PdfDocument]).Invoke($null, @($pdfOp))
    $pdfTask.Wait(-1) | Out-Null
    $pdf = $pdfTask.Result

    $bitmaps = New-Object System.Collections.Generic.List[System.Drawing.Image]
    for ($i = 0; $i -lt $pdf.PageCount; $i++) {
        $page = $pdf.GetPage([uint32]$i)
        $ras = New-Object Windows.Storage.Streams.InMemoryRandomAccessStream
        $opts = New-Object Windows.Data.Pdf.PdfPageRenderOptions
        $opts.DestinationWidth = [uint32]([math]::Round($page.Size.Width * 3))
        $renderAct = $page.RenderToStreamAsync($ras, $opts)
        $renderTask = $asAct.Invoke($null, @($renderAct))
        $renderTask.Wait(-1) | Out-Null
        $net = [System.IO.WindowsRuntimeStreamExtensions]::AsStream($ras)
        $net.Position = 0
        $bitmaps.Add([System.Drawing.Image]::FromStream($net))
        $page.Dispose()
    }

    $pd = New-Object System.Drawing.Printing.PrintDocument
    $pd.PrinterSettings.PrinterName = $printerName
    if (-not $pd.PrinterSettings.IsValid) { throw "Printer not available: $printerName" }
    $pd.PrinterSettings.Copies = [int16]$copies
    $pd.DocumentName = [System.IO.Path]::GetFileName($path)
    $pd.OriginAtMargins = $false
    try { $pd.DefaultPageSettings.Margins = New-Object System.Drawing.Printing.Margins(0, 0, 0, 0) } catch { }
    if ($bitmaps.Count -gt 0) {
        $pd.DefaultPageSettings.Landscape = ($bitmaps[0].Width -gt $bitmaps[0].Height)
    }

    $script:__printIdx = 0
    $handler = {
        param($sender, $e)
        $img = $bitmaps[$script:__printIdx]
        $rect = $e.PageBounds
        $ratio = [math]::Min($rect.Width / $img.Width, $rect.Height / $img.Height)
        $w = [int]($img.Width * $ratio)
        $h = [int]($img.Height * $ratio)
        $x = [int](($rect.Width - $w) / 2)
        $y = [int](($rect.Height - $h) / 2)
        try {
            $x = $x - [int]$e.PageSettings.HardMarginX
            $y = $y - [int]$e.PageSettings.HardMarginY
        } catch { }
        $e.Graphics.DrawImage($img, $x, $y, $w, $h)
        $script:__printIdx++
        $e.HasMorePages = $script:__printIdx -lt $bitmaps.Count
    }
    $pd.add_PrintPage($handler)
    $pd.Print()
    $pd.remove_PrintPage($handler)

    foreach ($b in $bitmaps) { $b.Dispose() }
}

function Get-OcrPageText([string]$path, [int]$pageIndex = 0) {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime | Out-Null

    $asOp = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
        $_.Name -eq 'AsTask' -and $_.IsGenericMethodDefinition -and $_.GetParameters().Count -eq 1 -and
        $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
    } | Select-Object -First 1

    $asAct = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
        $_.Name -eq 'AsTask' -and -not $_.IsGenericMethodDefinition -and $_.GetParameters().Count -eq 1 -and
        $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncAction'
    } | Select-Object -First 1

    [void][Windows.Data.Pdf.PdfDocument, Windows.Data.Pdf, ContentType = WindowsRuntime]
    [void][Windows.Storage.Streams.InMemoryRandomAccessStream, Windows.Storage.Streams, ContentType = WindowsRuntime]
    [void][Windows.Data.Pdf.PdfPageRenderOptions, Windows.Data.Pdf, ContentType = WindowsRuntime]
    [void][Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics.Imaging, ContentType = WindowsRuntime]
    [void][Windows.Graphics.Imaging.SoftwareBitmap, Windows.Graphics.Imaging, ContentType = WindowsRuntime]
    [void][Windows.Media.Ocr.OcrEngine, Windows.Media.Ocr, ContentType = WindowsRuntime]
    [void][Windows.Media.Ocr.OcrResult, Windows.Media.Ocr, ContentType = WindowsRuntime]
    [void][Windows.Globalization.Language, Windows.Globalization, ContentType = WindowsRuntime]

    $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
    if (-not $engine) {
        foreach ($lt in @('de-DE', 'en-US')) {
            try {
                $lang = New-Object Windows.Globalization.Language($lt)
                $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage($lang)
            } catch { }
            if ($engine) { break }
        }
    }
    if (-not $engine) { throw "Windows OCR is not available on this PC." }

    $bytes = [System.IO.File]::ReadAllBytes($path)
    $ms = New-Object System.IO.MemoryStream
    $ms.Write($bytes, 0, $bytes.Length)
    $ms.Position = 0
    $inStream = [System.IO.WindowsRuntimeStreamExtensions]::AsRandomAccessStream($ms)

    $pdfOp = [Windows.Data.Pdf.PdfDocument]::LoadFromStreamAsync($inStream)
    $pdfTask = $asOp.MakeGenericMethod([Windows.Data.Pdf.PdfDocument]).Invoke($null, @($pdfOp))
    $pdfTask.Wait(-1) | Out-Null
    $pdf = $pdfTask.Result
    if ($pdf.PageCount -lt 1) { throw "The PDF has no pages." }
    if ($pageIndex -ge [int]$pdf.PageCount) { return '' }

    $page = $pdf.GetPage([uint32]$pageIndex)
    $ras = New-Object Windows.Storage.Streams.InMemoryRandomAccessStream
    $opts = New-Object Windows.Data.Pdf.PdfPageRenderOptions
    $maxDim = [double][Windows.Media.Ocr.OcrEngine]::MaxImageDimension
    $scale = 3.0
    if ($page.Size.Width * $scale -gt $maxDim) { $scale = $maxDim / $page.Size.Width }
    if ($page.Size.Height * $scale -gt $maxDim) { $scale = $maxDim / $page.Size.Height }
    $opts.DestinationWidth = [uint32]([math]::Floor($page.Size.Width * $scale))
    $renderAct = $page.RenderToStreamAsync($ras, $opts)
    $renderTask = $asAct.Invoke($null, @($renderAct))
    $renderTask.Wait(-1) | Out-Null

    $ras.Seek(0)
    $decOp = [Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($ras)
    $decTask = $asOp.MakeGenericMethod([Windows.Graphics.Imaging.BitmapDecoder]).Invoke($null, @($decOp))
    $decTask.Wait(-1) | Out-Null
    $decoder = $decTask.Result

    $bmpOp = $decoder.GetSoftwareBitmapAsync([Windows.Graphics.Imaging.BitmapPixelFormat]::Bgra8, [Windows.Graphics.Imaging.BitmapAlphaMode]::Premultiplied)
    $bmpTask = $asOp.MakeGenericMethod([Windows.Graphics.Imaging.SoftwareBitmap]).Invoke($null, @($bmpOp))
    $bmpTask.Wait(-1) | Out-Null
    $bitmap = $bmpTask.Result

    $ocrOp = $engine.RecognizeAsync($bitmap)
    $ocrTask = $asOp.MakeGenericMethod([Windows.Media.Ocr.OcrResult]).Invoke($null, @($ocrOp))
    $ocrTask.Wait(-1) | Out-Null
    $result = $ocrTask.Result

    $sb = New-Object System.Text.StringBuilder
    foreach ($ln in $result.Lines) {
        [void]$sb.AppendLine($ln.Text)
    }
    try { $bitmap.Dispose() } catch { }
    try { $page.Dispose() } catch { }
    try { $ras.Dispose() } catch { }
    try { $inStream.Dispose() } catch { }
    try { $ms.Dispose() } catch { }
    return $sb.ToString()
}

function ConvertTo-FuKunde([string]$s) {
    if (-not $s) { return '' }
    $s = $s -replace '(?i)\bPW[S5]\S*', ' '
    $s = $s -replace '\d{1,2}\s*[.,]\s*\d{1,2}\s*[.,]\s*\d{2,4}', ' '
    $s = $s -replace '[\\/:*?"<>|.,]', ' '
    $parts = @($s -split '\s+' | Where-Object { $_ -ne '' -and $_ -notmatch '^[&+]+$' -and $_ -notmatch '^(?i)(and|und)$' })
    $junk = '^(?i)(pick(-?up)?|te[ck]up|addres+\w*|aderes+\w*|adres+\w*|transport|reason|shipment|method|incoterms|carrier|truck|destination|customer|delivery|note|page|doc|type|no|date|via|exw|dap|ddp|fca|cpt|cip)$'
    $start = 0
    while ($start -lt $parts.Count) {
        $t = $parts[$start]
        $letters = $t -replace '[^A-Za-z]', ''
        if ($letters.Length -ge 3 -and $t -cmatch '^[A-Z]' -and $t -notmatch $junk) { break }
        $start++
    }
    if ($start -ge $parts.Count) { return '' }
    $parts = @($parts)[$start..($parts.Count - 1)]
    $merged = New-Object System.Collections.Generic.List[string]
    foreach ($t in $parts) {
        if ($merged.Count -gt 0 -and $merged[$merged.Count - 1].Length -le 2 -and $t.Length -le 2) {
            $merged[$merged.Count - 1] = $merged[$merged.Count - 1] + $t
        } else {
            $merged.Add($t)
        }
    }
    if ($merged.Count -eq 0) { return '' }
    $take = [math]::Min(2, $merged.Count)
    return (@($merged)[0..($take - 1)] -join '_')
}

function Get-FuInfo([string]$ocrText) {
    $res = @{ IsFu = $false; Kunde = ''; Order = '' }
    if (-not $ocrText) { return $res }

    $hasDn = $ocrText -match '(?i)Deliv'
    $hasPws = $ocrText -match '(?i)PW[S5]'
    $hasAx = $ocrText -match '(?i)AX[I1l]UM'

    $orders = New-Object System.Collections.Generic.List[string]
    $prefixRx = [regex]'(?i)\b(?:[S5][O0]RD[ \t]*(\d{2})|(TRN)[ \t]*[-.]?[ \t]*[O0]RD)[ \t]*[-.:]?[ \t]*'
    foreach ($m in $prefixRx.Matches($ocrText)) {
        $isTrn = $m.Groups[2].Success
        $sufPat = '0\d{4}'
        if ($isTrn) { $sufPat = '0\d{3,5}' }
        $tailStart = $m.Index + $m.Length
        $tailLen = [math]::Min(90, $ocrText.Length - $tailStart)
        if ($tailLen -le 0) { continue }
        $tail = $ocrText.Substring($tailStart, $tailLen)
        $sm = [regex]::Match($tail, '^(' + $sufPat + ')\b')
        if (-not $sm.Success) { $sm = [regex]::Match($tail, '\b(' + $sufPat + ')\b') }
        if (-not $sm.Success) { continue }
        $v = 'SORD' + $m.Groups[1].Value + '-' + $sm.Groups[1].Value
        if ($isTrn) { $v = 'TRN-ORD-' + $sm.Groups[1].Value }
        if (-not $orders.Contains($v)) { $orders.Add($v) }
    }
    if ($orders.Count -eq 0) { return $res }
    if (-not ($hasDn -or $hasPws -or $hasAx)) { return $res }

    $lines = @($ocrText -split '\r?\n')
    $kunde = ''
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $ln = $lines[$i]
        $dms = [regex]::Matches($ln, '(?i)destinat[a-z]*')
        if ($dms.Count -eq 0) { continue }
        $dm = $dms[$dms.Count - 1]
        $kunde = ConvertTo-FuKunde ($ln.Substring($dm.Index + $dm.Length))
        if (-not $kunde -and $i + 1 -lt $lines.Count) { $kunde = ConvertTo-FuKunde $lines[$i + 1] }
        if (-not $kunde -and $i + 2 -lt $lines.Count) { $kunde = ConvertTo-FuKunde $lines[$i + 2] }
        if ($kunde) { break }
    }
    if (-not $kunde) {
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $ln = $lines[$i]
            if ($ln -notmatch '(?i)\bCustomer\b') { continue }
            if ($ln -match "(?i)Customer\W{0,2}s\b") { continue }
            if ($ln -match '(?i)Customer\s+Code') { continue }
            $idx = $ln.ToUpper().LastIndexOf('CUSTOMER')
            $kunde = ConvertTo-FuKunde ($ln.Substring($idx + 8))
            if (-not $kunde -and $i + 1 -lt $lines.Count) { $kunde = ConvertTo-FuKunde $lines[$i + 1] }
            if ($kunde) { break }
        }
    }
    if (-not $kunde) { return $res }
    $res.Kunde = $kunde

    $out = $orders[0]
    for ($i = 1; $i -lt $orders.Count; $i++) {
        $dm = [regex]::Match($orders[$i], '(\d+)\s*$')
        $suf = $dm.Groups[1].Value
        if ($suf.Length -gt 3) { $suf = $suf.Substring($suf.Length - 3) }
        $out = $out + '_' + $suf
    }
    $res.Order = $out
    $res.IsFu = $true
    return $res
}

function Invoke-FuScan {
    $scan = Get-OrAskFolder 'SCANDIR' "Select the Halle M SCAN folder (signed delivery documents)"
    if (-not $scan) {
        Write-Host "  No scan folder selected." -ForegroundColor Yellow
        return
    }

    $cands = @(Get-ChildItem -LiteralPath $scan -Filter '*.pdf' -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^doc' } | Sort-Object LastWriteTime -Descending)
    if ($cands.Count -eq 0) {
        Write-Host "  No new scanned documents (doc*.pdf) found in:" -ForegroundColor Yellow
        Write-Host ("  " + $scan) -ForegroundColor DarkGray
        return
    }

    Write-Host ("  " + $cands.Count + " scanned document(s) to check.   (beta)") -ForegroundColor DarkCyan

    $renamed = 0
    $skipped = 0
    $failed = 0
    foreach ($f in $cands) {
        $spin = Start-Spin ("reading " + $f.Name + " (OCR)...")
        $text = $null
        $err = ''
        $ok = $true
        try { $text = Get-OcrPageText $f.FullName } catch { $ok = $false; $err = $_.Exception.GetBaseException().Message }
        Stop-Spin $spin
        if (-not $ok) {
            Write-Host ("  ERROR reading " + $f.Name + ": " + $err) -ForegroundColor Red
            $failed++
            continue
        }

        $info = Get-FuInfo $text
        if (-not $info.IsFu) {
            $pg = 1
            while (-not $info.IsFu -and $pg -le 2) {
                $extra = ''
                try { $extra = Get-OcrPageText $f.FullName $pg } catch { }
                if ($extra) { $info = Get-FuInfo ($text + "`n" + $extra) }
                $pg++
            }
        }
        if (-not $info.IsFu) {
            Write-Host ("  skipped (no " + $FuPrefix + " recognized): " + $f.Name) -ForegroundColor DarkGray
            $skipped++
            continue
        }

        $datum = $f.LastWriteTime.ToString('yyMMdd')
        $baseName = $FuPrefix + "_" + $info.Kunde + "_" + $info.Order + "_" + $datum + ".pdf"
        $newName = $baseName
        $target = Join-Path $scan $newName
        $n = 2
        while (Test-Path -LiteralPath $target) {
            $stem = [System.IO.Path]::GetFileNameWithoutExtension($baseName)
            $newName = $stem + " (" + $n + ").pdf"
            $target = Join-Path $scan $newName
            $n++
        }

        Write-Host ""
        Write-Host ("  " + $f.Name) -ForegroundColor Cyan
        Write-Host ("    ->  " + $newName) -ForegroundColor Yellow
        $ans = Read-Host "  Rename? (Y/N)"
        if ($ans -match '^\s*[yj]') {
            try {
                Move-Item -LiteralPath $f.FullName -Destination $target
                Write-Host "    renamed." -ForegroundColor Green
                $renamed++
            } catch {
                Write-Host ("    ERROR: " + $_.Exception.Message) -ForegroundColor Red
                $failed++
            }
        } else {
            Write-Host "    skipped." -ForegroundColor DarkGray
            $skipped++
        }
    }

    Write-Host ""
    Write-Host $light -ForegroundColor DarkCyan
    Write-Host ("   Renamed : " + $renamed) -ForegroundColor Green
    Write-Host ("   Skipped : " + $skipped) -ForegroundColor DarkGray
    $failColor = if ($failed -gt 0) { "Red" } else { "DarkGray" }
    Write-Host ("   Errors  : " + $failed) -ForegroundColor $failColor
}

function Get-FuMoveInfo($f) {
    $text = Get-OcrPageText $f.FullName
    $lines = @($text -split '\r?\n')

    $destLines = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -notmatch '(?i)destinat') { continue }
        for ($j = $i + 1; $j -lt $lines.Count -and $destLines.Count -lt 6; $j++) {
            $v = $lines[$j].Trim()
            if (-not $v) { continue }
            if ($v -match '(?i)^(product|reference|descript|notes|carrier|gross|q\.?ty|u\.?m)') { break }
            $v = ($v -replace '(?i)marienh\S*|siegen|\(?57080\)?|pick.?up|addres+\w*|aderes+\w*', ' ').Trim()
            if (-not $v) { continue }
            $destLines.Add($v)
        }
        break
    }
    $destText = ($destLines -join "`n")

    $country = ''
    foreach ($mm in [regex]::Matches($destText, '\b([A-Z]{2})\b')) {
        $cc = $mm.Groups[1].Value
        if ($IsoCountry.ContainsKey($cc)) { $country = $cc }
    }

    $addr = New-Object System.Collections.Generic.List[string]
    foreach ($dl in $destLines) {
        if ($dl -match '^\d{1,3}$') { continue }
        $addr.Add($dl)
    }
    while ($addr.Count -gt 1 -and $addr[$addr.Count - 1] -match '^[A-Z]{2}$') { $addr.RemoveAt($addr.Count - 1) }
    $location = ''
    if ($addr.Count -gt 0) {
        $location = $addr[$addr.Count - 1]
        while ($location -match '\s+[A-Z]{2}\s*$') { $location = ([regex]::Replace($location, '\s+[A-Z]{2}\s*$', '')).Trim() }
    }

    $month = 0
    $year = ''
    $dm = [regex]::Match($text, '(\d{2})\.(\d{2})\.(\d{4})')
    if ($dm.Success) { $month = [int]$dm.Groups[2].Value; $year = $dm.Groups[3].Value }
    if (($month -lt 1 -or $month -gt 12) -and $f.BaseName -match '_(\d{2})(\d{2})(\d{2})(\s*\(\d+\))?$') {
        $year = '20' + $matches[1]
        $month = [int]$matches[2]
    }
    if ($month -lt 1 -or $month -gt 12 -or -not $year) {
        $month = (Get-Date).Month
        $year = (Get-Date).Year.ToString()
    }

    $kunde = ''
    $km = [regex]::Match($f.BaseName, '^' + [regex]::Escape($FuPrefix) + '_(.+?)_(?:SORD|TRN)')
    if ($km.Success) { $kunde = $km.Groups[1].Value -replace '_', ' ' }
    if (-not $kunde) {
        $fi = Get-FuInfo $text
        if ($fi.Kunde) { $kunde = $fi.Kunde -replace '_', ' ' }
    }

    return @{ Customer = $kunde; Month = $month; Year = $year; SiteText = $text; Country = $country; DestText = $destText; Location = $location }
}

function Invoke-FuMove {
    $root = Get-RootFolder
    if (-not $root) {
        Write-Host "  No root folder selected." -ForegroundColor Yellow
        return
    }
    $scan = Get-OrAskFolder 'SCANDIR' "Select the Halle M SCAN folder (signed delivery documents)"
    if (-not $scan) {
        Write-Host "  No scan folder selected." -ForegroundColor Yellow
        return
    }

    $moved = 0
    while ($true) {
        $fuFiles = @(Get-ChildItem -LiteralPath $scan -Filter ($FuPrefix + '_*.pdf') -ErrorAction SilentlyContinue | Sort-Object Name)

        $entries = New-Object System.Collections.Generic.List[object]
        $entries.Add(@{ Text = ($FuPrefix + " documents   (to customer folder)      (beta)"); Header = $true })
        if ($fuFiles.Count -eq 0) { $entries.Add(@{ Text = "(none)"; Header = $true }) }
        foreach ($f in $fuFiles) {
            $entries.Add(@{ Text = $f.Name; Header = $false; Act = 'FU'; File = $f })
        }
        $entries.Add(@{ Text = ""; Header = $true })
        $entries.Add(@{ Text = "Back"; Header = $false; Act = 'BACK' })

        $sel = Show-DocMenu ("MOVE " + $FuPrefix + " DOCUMENTS") $entries.ToArray()
        if ($sel -lt 0) { break }
        $e = $entries[$sel]
        if ($e.Act -eq 'BACK') { break }

        $f = $e.File
        $spin = Start-Spin ("reading " + $f.Name + " (OCR)...")
        $info = $null
        $err = ''
        try { $info = Get-FuMoveInfo $f } catch { $err = $_.Exception.GetBaseException().Message }
        Stop-Spin $spin
        if (-not $info) {
            Write-Host ("  ERROR reading " + $f.Name + ": " + $err) -ForegroundColor Red
            Write-Host ""
            Write-Host "   Press any key to continue..." -ForegroundColor DarkGray
            [void][Console]::ReadKey($true)
            continue
        }

        $monthLabel = $MonthsDE[$info.Month - 1] + " " + $info.Year
        $cust = $info.Customer
        if (-not $cust) { $cust = "(unknown customer)" }
        $title = $cust + "   (" + $f.Name + ")    Date: " + $monthLabel
        $start = Resolve-StartFolder $root $info
        $res = Move-PairInteractive $root $start $title $info @($f.FullName)
        if ($res -eq "MOVED") {
            $moved++
            Write-Host ""
            Write-Host "   Press any key to continue..." -ForegroundColor DarkGray
            [void][Console]::ReadKey($true)
        }
    }

    Clear-Host
    Show-Header
    Write-Host ""
    Write-Host $light -ForegroundColor DarkCyan
    Write-Host "   MOVE SUMMARY" -ForegroundColor Cyan
    Write-Host ("     Files moved : " + $moved) -ForegroundColor Green
}

function Invoke-Print {
    $printer = Get-Setting 'PRINTER'
    $valid = $false
    if ($printer) {
        try { $valid = (@(Get-Printer -ErrorAction Stop | Select-Object -ExpandProperty Name) -contains $printer) }
        catch { $valid = $true }
    }
    if (-not $valid) {
        $printer = Select-Printer
        if (-not $printer) { $script:SkipPause = $true; return }
        Set-Setting 'PRINTER' $printer
    }

    $printedFile = Get-PrintedFile
    $printed = New-Object System.Collections.Generic.HashSet[string]
    if (Test-Path -LiteralPath $printedFile) {
        foreach ($ln in (Get-Content -LiteralPath $printedFile)) {
            $t = $ln.Trim()
            if ($t) { [void]$printed.Add($t) }
        }
    }

    $pairFile = Get-PairsFile
    $pairs = @{}
    if (Test-Path -LiteralPath $pairFile) {
        foreach ($l in (Get-Content -LiteralPath $pairFile)) {
            if ($l -match '^(PAC\d+)=(PWS\d+)$') { $pairs[$matches[1]] = $matches[2] }
        }
    }

    while ($true) {
        $spin = Start-Spin "reading documents..."
        $pacFiles = @(Get-ChildItem -LiteralPath $WorkDir -Filter 'PAC*.pdf' | Sort-Object Name)
        $pwsFiles = @(Get-ChildItem -LiteralPath $WorkDir -Filter 'PWS*.pdf' | Sort-Object Name)
        $wp = @(Get-ChildItem -LiteralPath $WorkDir -Filter 'WP*.pdf' | Sort-Object Name)

        $pwsByNum = @{}
        foreach ($f in $pwsFiles) { if ($f.Name -match '^(PWS\d+)') { $pwsByNum[$matches[1]] = $f } }

        $pairEntries = New-Object System.Collections.Generic.List[object]
        $usedPws = @{}
        $pairsDirty = $false
        foreach ($f in $pacFiles) {
            $pacNum = if ($f.Name -match '^(PAC\d+)') { $matches[1] } else { $f.BaseName }
            $sord = Format-SordDisplay $f.Name
            $pwsNum = $pairs[$pacNum]
            if (-not $pwsNum) {
                $pwsNum = Get-PwsFromPdf $f.FullName
                if ($pwsNum) { $pairs[$pacNum] = $pwsNum; $pairsDirty = $true }
            }
            $paths = @()
            $detail = $pacNum
            $src = $f
            if ($pwsNum -and $pwsByNum.ContainsKey($pwsNum)) {
                $paths += $pwsByNum[$pwsNum].FullName
                $usedPws[$pwsNum] = $true
                $detail = "$pwsNum + $pacNum"
                $src = $pwsByNum[$pwsNum]
            }
            $paths += $f.FullName
            if ($sord) { $detail = $detail + "   " + $sord }
            $pairEntries.Add(@{ Id = $pacNum; Detail = $detail; Paths = $paths; Src = $src })
        }
        foreach ($num in ($pwsByNum.Keys | Sort-Object)) {
            if (-not $usedPws[$num]) {
                $f = $pwsByNum[$num]
                $sord = Format-SordDisplay $f.Name
                $detail = $num
                if ($sord) { $detail = $detail + "   " + $sord }
                $pairEntries.Add(@{ Id = $num; Detail = $detail; Paths = @($f.FullName); Src = $f })
            }
        }
        if ($pairsDirty -and $pairs.Count -gt 0) {
            try { Set-Content -LiteralPath $pairFile -Value (@($pairs.GetEnumerator() | ForEach-Object { $_.Key + "=" + $_.Value })) } catch { }
        }

        foreach ($pe in $pairEntries) {
            $di = Get-DeliveryInfo $pe.Src.FullName
            $pe.Info = $di
            $pe.Key = (Normalize-Name $di.Customer) + '|' + (Normalize-Name $di.Location) + '|' + $di.Country
        }
        $groups = New-Object System.Collections.Generic.List[object]
        $seenKey = @{}
        foreach ($pe in $pairEntries) {
            if ($seenKey.ContainsKey($pe.Key)) { continue }
            $seenKey[$pe.Key] = $true
            $members = @($pairEntries | Where-Object { $_.Key -eq $pe.Key })
            $allPaths = @()
            $ids = @()
            foreach ($m in $members) { $allPaths += $m.Paths; $ids += $m.Id }
            $groups.Add(@{ Id = ($ids -join '+'); Info = $pe.Info; Count = $members.Count; Members = $members; Paths = $allPaths })
        }

        $entries = New-Object System.Collections.Generic.List[object]
        $entries.Add(@{ Text = "Delivery documents   (2 copies)"; Header = $true })
        if ($groups.Count -eq 0) { $entries.Add(@{ Text = "(none)"; Header = $true }) }
        foreach ($g in $groups) {
            $cust = $g.Info.Customer
            if (-not $cust) { $cust = "(unknown customer)" }
            if ($g.Count -gt 1) { $disp = $cust + "   (" + $g.Count + " documents)" }
            else { $disp = $cust + "   (" + $g.Members[0].Detail + ")" }
            $done = $printed.Contains($g.Id)
            if ($done) { $disp = $disp + "   [printed]" }
            $entries.Add(@{ Text = $disp; Header = $false; Paths = $g.Paths; Copies = 2; Id = $g.Id; Done = $done })
        }
        $entries.Add(@{ Text = ""; Header = $true })
        $entries.Add(@{ Text = "Warehouse picks   (1 copy)"; Header = $true })

        $groupages = Get-ActiveGroupages
        $covered = @{}
        foreach ($g in $groupages) { foreach ($n in $g.Names) { $covered[$n] = $true } }

        if ($wp.Count -eq 0 -and $groupages.Count -eq 0) { $entries.Add(@{ Text = "(none)"; Header = $true }) }

        foreach ($g in $groupages) {
            $done = $printed.Contains($g.Id)
            $t = $g.Label
            if ($done) { $t = $t + "   [printed]" }
            $entries.Add(@{ Text = $t; Header = $false; Paths = $g.Paths; Copies = 1; Id = $g.Id; Done = $done; Open = $g.Xlsx })
        }
        foreach ($f in $wp) {
            if ($covered.ContainsKey($f.Name)) { continue }
            $done = $printed.Contains($f.Name)
            $t = $f.Name
            if ($done) { $t = $t + "   [printed]" }
            $entries.Add(@{ Text = $t; Header = $false; Paths = @($f.FullName); Copies = 1; Id = $f.Name; Done = $done })
        }
        $entries.Add(@{ Text = ""; Header = $true })
        $entries.Add(@{ Text = "Back"; Header = $false; Paths = $null; Copies = 0 })

        Stop-Spin $spin
        $sel = Show-DocMenu ("PRINTER  ->  " + $printer) $entries.ToArray()
        if ($sel -lt 0) { $script:SkipPause = $true; return }
        $chosen = $entries[$sel]
        if (-not $chosen.Paths) { $script:SkipPause = $true; return }

        Clear-Host
        Show-Header
        Write-Host ""
        $allOk = $true
        for ($set = 1; $set -le $chosen.Copies; $set++) {
            if ($chosen.Copies -gt 1) {
                Write-Host ("  --- Set " + $set + " of " + $chosen.Copies + " ---") -ForegroundColor DarkGray
            }
            foreach ($p in $chosen.Paths) {
                Write-Host ("  Printing " + [System.IO.Path]::GetFileName($p) + "  ->  " + $printer) -ForegroundColor Cyan
                $pspin = Start-Spin ("sending " + [System.IO.Path]::GetFileName($p) + " to " + $printer + "...")
                try {
                    Print-Pdf $p $printer 1
                    Stop-Spin $pspin
                    Write-Host "    Sent." -ForegroundColor Green
                } catch {
                    Stop-Spin $pspin
                    Write-Host ("    ERROR: " + $_.Exception.Message) -ForegroundColor Red
                    $allOk = $false
                }
            }
        }
        if ($chosen.Open -and (Test-Path -LiteralPath $chosen.Open)) {
            Write-Host ("  Opening " + [System.IO.Path]::GetFileName($chosen.Open) + " (print it manually)") -ForegroundColor Cyan
            try { Start-Process -FilePath $chosen.Open } catch { }
        }
        if ($allOk -and $chosen.Id) {
            [void]$printed.Add($chosen.Id)
            try { Set-Content -LiteralPath $printedFile -Value (@($printed)) } catch { }
        }
        Write-Host ""
        Write-Host "   Press any key to continue..." -ForegroundColor DarkGray
        [void][Console]::ReadKey($true)
    }
}

function Get-PageBody([string]$s) {
    foreach ($m in [regex]::Matches($s, '\d+\s+0\s+obj(.*?)endobj', [System.Text.RegularExpressions.RegexOptions]::Singleline)) {
        if ($m.Groups[1].Value -match '/Type\s*/Page(?!s)') { return $m.Groups[1].Value }
    }
    return ""
}

function Get-Obj([string]$s, [int]$num) {
    $m = [regex]::Match($s, '(?<![0-9])' + $num + '\s+0\s+obj(.*?)endobj', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if ($m.Success) { return $m.Groups[1].Value } else { return "" }
}

function Expand-ObjStream([string]$body) {
    $st = $body.IndexOf('stream')
    $en = $body.IndexOf('endstream')
    if ($st -lt 0 -or $en -lt 0) { return "" }
    $raw = $body.Substring($st + 6, $en - $st - 6).TrimStart("`r", "`n")
    $d = Inflate ($latin.GetBytes($raw))
    if ($d) { return $latin.GetString($d) } else { return "" }
}

function Get-FontMap([string]$s, [string]$page, [string]$fname, [hashtable]$cache) {
    if (-not $fname) { return $null }
    if ($cache.ContainsKey($fname)) { return $cache[$fname] }
    $result = $null
    $ref = '/' + [regex]::Escape($fname) + '\s+(\d+)\s+0\s+R'
    $fm = [regex]::Match($page, $ref)
    if (-not $fm.Success) { $fm = [regex]::Match($s, $ref) }
    if ($fm.Success) {
        $fobj = Get-Obj $s ([int]$fm.Groups[1].Value)
        $tm = [regex]::Match($fobj, '/ToUnicode\s+(\d+)\s+0\s+R')
        if ($tm.Success) {
            $cmap = Expand-ObjStream (Get-Obj $s ([int]$tm.Groups[1].Value))
            $single = @{}
            $bc = [regex]::Match($cmap, 'beginbfchar(.*?)endbfchar', [System.Text.RegularExpressions.RegexOptions]::Singleline)
            if ($bc.Success) {
                foreach ($m in [regex]::Matches($bc.Groups[1].Value, '<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>')) {
                    $u = $m.Groups[2].Value
                    if ($u.Length -gt 4) { $u = $u.Substring(0, 4) }
                    $single[[Convert]::ToInt32($m.Groups[1].Value, 16)] = [Convert]::ToInt32($u, 16)
                }
            }
            $ranges = New-Object System.Collections.Generic.List[object]
            $br = [regex]::Match($cmap, 'beginbfrange(.*?)endbfrange', [System.Text.RegularExpressions.RegexOptions]::Singleline)
            if ($br.Success) {
                foreach ($m in [regex]::Matches($br.Groups[1].Value, '<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>')) {
                    $ranges.Add(@{ A = [Convert]::ToInt32($m.Groups[1].Value, 16); B = [Convert]::ToInt32($m.Groups[2].Value, 16); U = [Convert]::ToInt32($m.Groups[3].Value, 16) })
                }
            }
            $result = @{ Single = $single; Ranges = $ranges }
        }
    }
    $cache[$fname] = $result
    return $result
}

function Convert-Hex([string]$hex, $map) {
    if (-not $map) { return '' }
    $hex = $hex -replace '\s', ''
    $single = $map.Single
    $ranges = $map.Ranges
    $sb = New-Object System.Text.StringBuilder
    for ($i = 0; $i + 4 -le $hex.Length; $i += 4) {
        $g = [Convert]::ToInt32($hex.Substring($i, 4), 16)
        if ($single.ContainsKey($g)) { [void]$sb.Append([char]$single[$g]) }
        else { foreach ($r in $ranges) { if ($g -ge $r.A -and $g -le $r.B) { [void]$sb.Append([char]($r.U + ($g - $r.A))); break } } }
    }
    return $sb.ToString()
}

function Get-DeliveryInfo([string]$path) {
    $bytes = [System.IO.File]::ReadAllBytes($path)
    $s = $latin.GetString($bytes)
    $t = Get-PdfText $path

    $month = 0; $year = ""
    $dm = [regex]::Match($t, '(\d{2})\.(\d{2})\.(\d{4})')
    if ($dm.Success) { $month = [int]$dm.Groups[2].Value; $year = $dm.Groups[3].Value }

    $rawName = Get-DestName $t
    $cparts = @($rawName -replace '[\\/:*?"<>|]', ' ' -split '\s+' | Where-Object { $_ -ne '' -and $_ -notmatch '^[&+]+$' -and $_ -notmatch '^(and|und)$' })
    if ($cparts.Count -gt 2) { $cparts = $cparts[0..1] }
    $customer = ($cparts -join ' ')

    $siteSb = New-Object System.Text.StringBuilder
    foreach ($m in [regex]::Matches($t, '\(((?:[^()\\]|\\.)*)\)\s*Tj')) {
        $val = $m.Groups[1].Value
        if ($val -match 'Marienh|Siegen|57080') { continue }
        [void]$siteSb.Append(" ")
        [void]$siteSb.Append($val)
    }
    $siteText = $siteSb.ToString()

    $destBlock = Get-DestBlock $t
    $country = Get-DestCountry $destBlock

    $addr = New-Object System.Collections.Generic.List[string]
    foreach ($line in ($destBlock -split "`n")) {
        $lt = $line.Trim()
        if (-not $lt) { continue }
        if ($lt -match '^(Delivery Note|Packing List|Page|Truck|Destination|Sold To|Ship To|Deliver To|Customer)$') { continue }
        if ($lt -match '^\d{1,3}$') { continue }
        if ($lt -match '^(PWS|PAC|WP)\d') { continue }
        if ($lt -match '^Connected to|Shipment No') { continue }
        $addr.Add($lt)
    }
    while ($addr.Count -gt 1 -and $addr[$addr.Count - 1] -match '^[A-Z]{2}$') { $addr.RemoveAt($addr.Count - 1) }
    $location = ""
    if ($addr.Count -gt 0) {
        $location = $addr[$addr.Count - 1]
        $location = ([regex]::Replace($location, '\s+[A-Z]{2}\s*$', '')).Trim()
    }

    return @{ Customer = $customer; Month = $month; Year = $year; SiteText = $siteText; Country = $country; DestText = $destBlock; Location = $location }
}

function Get-DestBlock([string]$t) {
    $toks = New-Object System.Collections.Generic.List[string]
    foreach ($m in [regex]::Matches($t, '\(((?:[^()\\]|\\.)*)\)\s*Tj')) {
        $toks.Add(($m.Groups[1].Value -replace '\\\(', '(' -replace '\\\)', ')').Trim())
    }
    foreach ($lab in @('Destination', 'Ship To', 'Deliver To', 'Sold To', 'Customer')) {
        $start = -1
        for ($i = 0; $i -lt $toks.Count; $i++) { if ($toks[$i] -eq $lab) { $start = $i; break } }
        if ($start -lt 0) { continue }
        $sb = New-Object System.Text.StringBuilder
        $n = 0
        for ($i = $start + 1; $i -lt $toks.Count -and $n -lt 14; $i++) {
            $v = $toks[$i]
            if (-not $v) { continue }
            if ($n -gt 0 -and $v -match '^(Pick-?up|Incoterms|Carrier|Transport Reason|Shipment Method|Doc\. Type|Connected to)') { break }
            [void]$sb.Append("`n")
            [void]$sb.Append($v)
            $n++
        }
        $r = $sb.ToString().Trim()
        if ($r) { return $r }
    }
    return ""
}

function Get-DestCountry([string]$destBlock) {
    if (-not $destBlock) { return "" }
    $found = ""
    foreach ($mm in [regex]::Matches($destBlock, '\b([A-Z]{2})\b')) {
        $cc = $mm.Groups[1].Value
        if ($IsoCountry.ContainsKey($cc)) { $found = $cc }
    }
    if ($found) { return $found }
    return (Get-CountryCode $destBlock)
}

function Normalize-Name([string]$n) {
    if (-not $n) { return "" }
    $x = $n.ToLower()
    $x = $x -replace '[' + [char]0xe0 + '-' + [char]0xe5 + ']', 'a'
    $x = $x -replace '[' + [char]0xe8 + '-' + [char]0xeb + ']', 'e'
    $x = $x -replace '[' + [char]0xec + '-' + [char]0xef + ']', 'i'
    $x = $x -replace '[' + [char]0xf2 + '-' + [char]0xf6 + ']', 'o'
    $x = $x -replace '[' + [char]0xf9 + '-' + [char]0xfc + ']', 'u'
    $x = $x -replace [char]0xe7, 'c'
    $x = $x -replace [char]0xdf, 'ss'
    $x = $x -replace '\b(gmbh|ag|sas|sarl|sro|ab|bv|nv|sa|srl|spa|ltd|limited|oy|as|aps|co|kg|se|plc|inc|the)\b', ' '
    $x = $x -replace '[^a-z0-9]', ' '
    $x = $x -replace '\s+', ' '
    return $x.Trim()
}

function Score-Name([string]$a, [string]$b) {
    $na = Normalize-Name $a
    $nb = Normalize-Name $b
    if (-not $na -or -not $nb) { return 0 }
    if ($na -eq $nb) { return 100 }
    if ($nb.Contains($na) -or $na.Contains($nb)) { return 80 }
    $ta = @($na -split ' ')
    $tb = @($nb -split ' ')
    $common = 0
    foreach ($w in $ta) { if ($w.Length -ge 2 -and ($tb -contains $w)) { $common++ } }
    if ($common -gt 0) { return 40 + $common * 10 }
    if ($ta[0] -eq $tb[0]) { return 25 }
    foreach ($w in $ta) { if ($w.Length -ge 4 -and $nb.Contains($w)) { return 20 } }
    foreach ($w in $tb) { if ($w.Length -ge 4 -and $na.Contains($w)) { return 15 } }
    return 0
}

function Get-MatchLocation([hashtable]$info) {
    if ($info.Location) { return $info.Location }
    if ($info.DestText) { return $info.DestText }
    return $info.SiteText
}

function Find-BestBase([string]$root, [hashtable]$info) {
    if (-not $info.Country) { return $root }
    $countryDir = $null
    foreach ($cd in (Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue)) {
        if ((Score-Country $cd.Name $info.Country) -ge 1) { $countryDir = $cd.FullName; break }
    }
    if (-not $countryDir) { return $root }
    $site = Get-MatchLocation $info
    $best = $null; $bestScore = 0
    foreach ($ud in (Get-ChildItem -LiteralPath $countryDir -Directory -ErrorAction SilentlyContinue)) {
        $sc = (Score-Name $info.Customer $ud.Name) + (Score-FolderSite $ud.Name $site) * 15
        if ($sc -gt $bestScore) { $bestScore = $sc; $best = $ud.FullName }
    }
    if ($best) { return $best }
    return $countryDir
}

function Test-FolderMonth([string]$name, [int]$month, [string]$year) {
    $fm = Get-FolderMonth $name
    if ($fm -ne 0 -and $fm -ne $month) { return -1 }
    $y2 = $year.Substring($year.Length - 2)
    $hasYear = ($name -match $year) -or ($name -match ('(^|\D)' + $y2 + '(\D|$)'))
    $hasMonth = ($fm -eq $month)
    if ($hasMonth -and $hasYear) { return 3 }
    if ($hasMonth) { return 2 }
    if ($hasYear) { return 1 }
    return 0
}

function Score-FolderSite([string]$name, [string]$siteText) {
    $nf = Normalize-Name $name
    if (-not $nf) { return 0 }
    $ns = Normalize-Name $siteText
    if (-not $ns) { return 0 }
    $docTokens = @($ns -split ' ' | Where-Object { $_.Length -ge 3 })
    if ($docTokens.Count -eq 0) { return 0 }
    $score = 0
    foreach ($t in ($nf -split ' ')) {
        if ($t.Length -lt 3) { continue }
        foreach ($d in $docTokens) {
            if ($d -eq $t) { $score += 2; break }
            if ($t.Length -ge 4 -and $d.Length -ge 4 -and ($d.StartsWith($t) -or $t.StartsWith($d))) { $score += 1; break }
        }
    }
    return $score
}

function Test-FolderSite([string]$name, [string]$siteText) {
    return ((Score-FolderSite $name $siteText) -ge 2)
}

function Get-CountryCode([string]$siteText) {
    if (-not $siteText) { return "" }
    $m = [regex]::Match($siteText, '\b([A-Za-z]{2})-\d{3,5}')
    if ($m.Success -and $CountryNames.ContainsKey($m.Groups[1].Value.ToUpper())) { return $m.Groups[1].Value.ToUpper() }
    $ns = Normalize-Name $siteText
    foreach ($code in $CountryNames.Keys) {
        foreach ($v in $CountryNames[$code]) {
            if ($ns -match ('\b' + $v + '\b')) { return $code }
        }
    }
    foreach ($mm in [regex]::Matches($siteText, '\b([A-Z]{2})\b')) {
        if ($CountryNames.ContainsKey($mm.Groups[1].Value)) { return $mm.Groups[1].Value }
    }
    return ""
}

function Get-CountryLabel([string]$code) {
    if (-not $code) { return "(not found in document)" }
    if ($IsoCountry.ContainsKey($code)) { return ($code + " (" + $IsoCountry[$code] + ")") }
    return $code
}

function Score-Country([string]$folderName, [string]$code) {
    if (-not $code) { return 0 }
    if ($folderName.Trim().ToUpper() -eq $code) { return 1 }
    $nf = Normalize-Name $folderName
    if (-not $nf) { return 0 }
    $lc = $code.ToLower()
    if ($nf -eq $lc) { return 1 }
    if ($nf -match ('\b' + $lc + '\b')) { return 1 }
    if ($CountryNames.ContainsKey($code)) {
        foreach ($v in $CountryNames[$code]) { if ($nf -eq $v -or $nf.Contains($v)) { return 1 } }
    }
    if ($IsoCountry.ContainsKey($code)) {
        $en = Normalize-Name $IsoCountry[$code]
        if ($en -and ($nf -eq $en -or $nf.Contains($en))) { return 1 }
    }
    return 0
}

function Get-FolderMonth([string]$name) {
    if (-not $name) { return 0 }
    for ($i = 0; $i -lt 12; $i++) {
        if ([regex]::IsMatch($name, ('\b(' + $MonthPat[$i] + ')\b'), [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) { return ($i + 1) }
    }
    if ($name -match '^\s*(0?[1-9]|1[0-2])\s*$') { return [int]$matches[1] }
    if ($name -match '\b20\d{2}\b') {
        $rest = $name -replace '\b20\d{2}\b', ' '
        if ($rest -match '(?<!\d)(0?[1-9]|1[0-2])(?!\d)') { return [int]$matches[1] }
    }
    return 0
}

function Fold-Text([string]$s) {
    if (-not $s) { return "" }
    $x = $s.ToLower()
    $x = $x -replace [char]0xe4, 'a'
    $x = $x -replace [char]0xf6, 'o'
    $x = $x -replace [char]0xfc, 'u'
    return $x
}

function Apply-Case([string]$src, [string]$dst) {
    if ($src -ceq $src.ToUpper()) { return $dst.ToUpper() }
    if ($src.Substring(0, 1) -ceq $src.Substring(0, 1).ToUpper()) { return ($dst.Substring(0, 1).ToUpper() + $dst.Substring(1)) }
    return $dst.ToLower()
}

function Build-MonthFolderName([string]$sample, [int]$month, [string]$year) {
    $out = $sample
    $mi = 0
    $mm = $null
    for ($i = 0; $i -lt 12; $i++) {
        $m = [regex]::Match($sample, ('\b(' + $MonthPat[$i] + ')\b'), [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($m.Success) { $mi = $i + 1; $mm = $m; break }
    }
    if ($mi -gt 0) {
        $tok = $mm.Value
        $f = Fold-Text $tok
        $new = $MonthAbbrDE[$month - 1]
        if ($f -eq (Fold-Text $MonthsDE[$mi - 1])) { $new = $MonthsDE[$month - 1] }
        elseif ($f -eq (Fold-Text $MonthsEN[$mi - 1])) { $new = $MonthsEN[$month - 1] }
        elseif ($f -eq (Fold-Text $MonthAbbrDE[$mi - 1])) { $new = $MonthAbbrDE[$month - 1] }
        elseif ($f -eq (Fold-Text $MonthAbbrEN[$mi - 1])) { $new = $MonthAbbrEN[$month - 1] }
        $new = Apply-Case $tok $new
        $out = $out.Substring(0, $mm.Index) + $new + $out.Substring($mm.Index + $mm.Length)
    } else {
        $nm = [regex]::Match($sample, '(?<!\d)(0[1-9]|1[0-2])(?!\d)')
        if ($nm.Success) { $out = $out.Substring(0, $nm.Index) + ('{0:D2}' -f $month) + $out.Substring($nm.Index + $nm.Length) }
    }
    $y4 = [regex]::Match($out, '\b20\d{2}\b')
    if ($y4.Success) {
        $out = $out.Substring(0, $y4.Index) + $year + $out.Substring($y4.Index + $y4.Length)
    } else {
        $y2 = [regex]::Match($out, '(?<!\d)(\d{2})(?!\d)')
        if ($y2.Success -and (-not ($y2.Groups[1].Value -match '^(0[1-9]|1[0-2])$'))) {
            $out = $out.Substring(0, $y2.Index) + $year.Substring(2) + $out.Substring($y2.Index + $y2.Length)
        }
    }
    return $out
}

function Get-FolderYear([string]$name) {
    $m = [regex]::Match($name, '\b(20\d{2})\b')
    if ($m.Success) { return $m.Groups[1].Value }
    if ($name -match '^\s*(\d{2})\s*$') { return ("20" + $matches[1]) }
    return ""
}

function Suggest-MonthFolder([string]$container, [int]$month, [string]$year) {
    if ($container -and (Test-Path -LiteralPath $container)) {
        $sibs = @(Get-ChildItem -LiteralPath $container -Directory -ErrorAction SilentlyContinue | Where-Object { (Get-FolderMonth $_.Name) -ne 0 })
        if ($sibs.Count -gt 0) {
            $sameYear = @($sibs | Where-Object { (Get-FolderYear $_.Name) -eq $year })
            $model = $sibs[$sibs.Count - 1].Name
            if ($sameYear.Count -gt 0) { $model = $sameYear[$sameYear.Count - 1].Name }
            return (Build-MonthFolderName $model $month $year)
        }
    }
    return ($MonthsDE[$month - 1] + " " + $year)
}

function Resolve-CreateTarget([string]$cur, [int]$month, [string]$year) {
    $p = $cur
    if ((Get-FolderMonth (Split-Path $p -Leaf)) -ne 0) { $p = Split-Path $p -Parent }

    for ($i = 0; $i -lt 5; $i++) {
        $leaf = Split-Path $p -Leaf
        if (-not ((Get-FolderYear $leaf) -and ((Get-FolderMonth $leaf) -eq 0))) { break }
        $parent = Split-Path $p -Parent
        if (-not $parent) { break }
        $p = $parent
    }

    return @{ Parent = $p; NeedYear = "" }
}

function Resolve-StartFolder([string]$root, [hashtable]$info) {
    $start = Find-BestBase $root $info
    if ($start -eq $root) { return $root }
    $locMatch = Get-MatchLocation $info
    for ($d = 0; $d -lt 6; $d++) {
        $children = @(Get-ChildItem -LiteralPath $start -Directory -ErrorAction SilentlyContinue)
        if ($children.Count -eq 0) { break }
        $bestChild = $null; $bestScore = 0; $bestMy = 0
        foreach ($c in $children) {
            if ((Get-FolderMonth $c.Name) -eq 0 -and (Get-FolderYear $c.Name)) { continue }
            $my = Test-FolderMonth $c.Name $info.Month $info.Year
            $si = Score-FolderSite $c.Name $locMatch
            $cu = 0
            if ((Score-Name $info.Customer $c.Name) -ge 40) { $cu = 1 }
            $sc = $my * 10 + $si * 2 + $cu * 3
            if ($my -lt 0) { $sc = -1 }
            if ($sc -gt $bestScore) { $bestScore = $sc; $bestChild = $c.FullName; $bestMy = $my }
        }
        if ($bestScore -eq 0) { break }
        $start = $bestChild
        if ($bestMy -ge 2) { return $start }
    }
    return $start
}

function Browse-ForFolder([string]$desc) {
    try {
        $sh = New-Object -ComObject Shell.Application
        $f = $sh.BrowseForFolder(0, $desc, 0, 0)
        if ($f -and $f.Self) { return $f.Self.Path }
    } catch { }
    return $null
}

function Get-SettingsFile { return (Join-Path $AppDir "_promedia_copilot_settings.txt") }

function Get-PairsFile {
    $f = Join-Path $AppDir "_promedia_copilot_pairs.txt"
    if (-not (Test-Path -LiteralPath $f)) {
        $old = Join-Path $AppDir "_doc_wizard_pairs.txt"
        if (Test-Path -LiteralPath $old) { try { Copy-Item -LiteralPath $old -Destination $f -ErrorAction Stop } catch { } }
    }
    return $f
}

function Get-PrintedFile {
    $f = Join-Path $AppDir "_promedia_copilot_printed.txt"
    if (-not (Test-Path -LiteralPath $f)) {
        $old = Join-Path $AppDir "_doc_wizard_printed.txt"
        if (Test-Path -LiteralPath $old) { try { Copy-Item -LiteralPath $old -Destination $f -ErrorAction Stop } catch { } }
    }
    return $f
}

function Get-Settings {
    $f = Get-SettingsFile
    $h = @{}
    if (Test-Path -LiteralPath $f) {
        foreach ($l in (Get-Content -LiteralPath $f)) {
            if ($l -match '^([A-Z_]+)=(.*)$') { $h[$matches[1]] = $matches[2] }
        }
        return $h
    }
    $oldSettings = Join-Path $AppDir "_doc_wizard_settings.txt"
    if (Test-Path -LiteralPath $oldSettings) {
        foreach ($l in (Get-Content -LiteralPath $oldSettings)) {
            if ($l -match '^([A-Z_]+)=(.*)$') { $h[$matches[1]] = $matches[2] }
        }
        if ($h.Count -gt 0) { Save-Settings $h; return $h }
    }
    $oldRoot = Join-Path $AppDir "_doc_wizard_root.cfg"
    $oldPrn = Join-Path $AppDir "_doc_wizard.cfg"
    if (Test-Path -LiteralPath $oldRoot) { try { $h['ROOT'] = (Get-Content -LiteralPath $oldRoot -TotalCount 1).Trim() } catch { } }
    if (Test-Path -LiteralPath $oldPrn) { try { $h['PRINTER'] = (Get-Content -LiteralPath $oldPrn -TotalCount 1).Trim() } catch { } }
    if ($h.Count -gt 0) { Save-Settings $h }
    return $h
}

function Save-Settings([hashtable]$h) {
    $f = Get-SettingsFile
    $merged = @{}
    if (Test-Path -LiteralPath $f) {
        try {
            foreach ($l in (Get-Content -LiteralPath $f)) {
                if ($l -match '^([A-Z_]+)=(.*)$') { $merged[$matches[1]] = $matches[2] }
            }
        } catch { }
    }
    foreach ($k in @($h.Keys)) { $merged[$k] = $h[$k] }
    if ($merged.Count -eq 0) { return }
    try { Set-Content -LiteralPath $f -Value (@($merged.GetEnumerator() | ForEach-Object { $_.Key + "=" + $_.Value })) } catch { }
}

function Get-Setting([string]$key) {
    $h = Get-Settings
    if ($h.ContainsKey($key)) { return $h[$key] } else { return "" }
}

function Set-Setting([string]$key, [string]$val) {
    $h = Get-Settings
    $h[$key] = $val
    Save-Settings $h
}

function Get-OrAskFolder([string]$key, [string]$desc) {
    $p = Get-Setting $key
    if ($p -and (Test-Path -LiteralPath $p)) { return $p }
    $picked = Browse-ForFolder $desc
    if ($picked -and (Test-Path -LiteralPath $picked)) { Set-Setting $key $picked; return $picked }
    return $null
}

function Get-RootFolder {
    return (Get-OrAskFolder 'ROOT' "Select the ROOT folder (contains the country folders)")
}

function Select-Printer {
    try { $printers = @(Get-Printer -ErrorAction Stop | Sort-Object Name | Select-Object -ExpandProperty Name) }
    catch { $printers = @(Get-CimInstance Win32_Printer -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name) }
    if (-not $printers -or $printers.Count -eq 0) {
        Write-Host "  No printers found on this PC." -ForegroundColor Yellow
        [void][Console]::ReadKey($true)
        return $null
    }
    $items = @($printers) + "" + "Back"
    $sel = Show-Menu "SELECT PRINTER" $items
    if ($sel -lt 0 -or $items[$sel] -eq "Back") { return $null }
    return $items[$sel]
}

function Move-FileSafe([string]$src, [string]$dest) {
    try {
        Move-Item -LiteralPath $src -Destination $dest
        return $true
    } catch {
        Write-Host ("  In use, not moved: " + [System.IO.Path]::GetFileName($src)) -ForegroundColor Red
        Write-Host "  Close it in the PDF viewer or preview pane, then run Move again." -ForegroundColor DarkGray
        return $false
    }
}

function Move-PairInteractive([string]$root, [string]$startDir, [string]$title, [hashtable]$info, [string[]]$files) {
    $month = $info.Month
    $year = $info.Year
    $siteText = Get-MatchLocation $info
    $cur = $startDir
    if (-not (Test-Path -LiteralPath $cur)) { $cur = $root }
    $suggest = $MonthsDE[$month - 1] + " " + $year

    $locShow = $info.Location
    if ($locShow.Length -gt 52) { $locShow = $locShow.Substring(0, 52) }

    while ($true) {
        $subs = @(Get-ChildItem -LiteralPath $cur -Directory -ErrorAction SilentlyContinue | Sort-Object Name)

        $entries = New-Object System.Collections.Generic.List[object]
        $entries.Add(@{ Text = $title; Header = $true })
        $entries.Add(@{ Text = ""; Header = $true })
        $entries.Add(@{ Text = "From the document:"; Header = $true })
        $entries.Add(@{ Text = ("  Customer: " + $info.Customer); Header = $true })
        $entries.Add(@{ Text = ("  Location: " + $locShow); Header = $true })
        $entries.Add(@{ Text = ("  Country : " + (Get-CountryLabel $info.Country)); Header = $true })
        $entries.Add(@{ Text = ""; Header = $true })
        $entries.Add(@{ Text = ("Current: " + $cur); Header = $true })
        $entries.Add(@{ Text = ""; Header = $true })
        $ct = Resolve-CreateTarget $cur $month $year
        $createParent = $ct.Parent
        $needYear = $ct.NeedYear
        $effContainer = $createParent
        if ($needYear) { $effContainer = Join-Path $createParent $needYear }
        $suggest = Suggest-MonthFolder $effContainer $month $year
        if ($needYear) {
            $createHint = "   -> creates " + $needYear + "\" + $suggest
        } elseif ($effContainer -ne $cur) {
            $createHint = "   -> in " + (Split-Path $effContainer -Leaf)
        } else {
            $createHint = ""
        }

        $monthExists = $false
        if (-not $needYear) {
            if ((Test-FolderMonth (Split-Path $cur -Leaf) $month $year) -ge 2) {
                $monthExists = $true
            } else {
                foreach ($d in @(Get-ChildItem -LiteralPath $effContainer -Directory -ErrorAction SilentlyContinue)) {
                    if ((Test-FolderMonth $d.Name $month $year) -ge 2) { $monthExists = $true; break }
                }
            }
        }
        $createEntry = @{ Text = ("[ + Create folder: " + $suggest + " ]" + $createHint); Header = $false; Act = "CREATE" }

        if (-not $monthExists) { $entries.Add($createEntry) }
        $entries.Add(@{ Text = "[ Move here ]"; Header = $false; Act = "SELECT" })
        if ($cur.TrimEnd('\').Length -gt $root.TrimEnd('\').Length) {
            $entries.Add(@{ Text = "[ .. up ]"; Header = $false; Act = "UP" })
        }
        if ($monthExists) { $entries.Add($createEntry) }
        $entries.Add(@{ Text = "[ + New folder here (own name) ]"; Header = $false; Act = "NEWDIR" })
        $entries.Add(@{ Text = "[ Change root folder ]"; Header = $false; Act = "ROOT" })
        $entries.Add(@{ Text = "[ Back to list ]"; Header = $false; Act = "SKIP" })
        $entries.Add(@{ Text = ""; Header = $true })
        $entries.Add(@{ Text = "Subfolders:"; Header = $true })
        if ($subs.Count -eq 0) { $entries.Add(@{ Text = "(no subfolders)"; Header = $true }) }
        foreach ($d in $subs) {
            $mark = ""
            $mv = Test-FolderMonth $d.Name $month $year
            if ($mv -ge 2) { $mark = "   <-- month match" }
            elseif ($mv -eq 1) { $mark = "   <-- year" }
            elseif (Test-FolderSite $d.Name $siteText) { $mark = "   <-- location" }
            $entries.Add(@{ Text = ($d.Name + $mark); Header = $false; Act = ("DIR|" + $d.FullName) })
        }

        $sel = Show-DocMenu "MOVE DELIVERY DOCUMENTS" $entries.ToArray()
        if ($sel -lt 0) { return "SKIP" }
        $act = $entries[$sel].Act

        if ($act -eq "SELECT") {
            Clear-Host
            Show-Header
            Write-Host ""
            $ok = $true
            foreach ($f in $files) {
                $dest = Join-Path $cur ([System.IO.Path]::GetFileName($f))
                if (Test-Path -LiteralPath $dest) {
                    Write-Host ("  Target exists, skipped: " + [System.IO.Path]::GetFileName($f)) -ForegroundColor DarkYellow
                    $ok = $false
                    continue
                }
                if (-not (Move-FileSafe $f $dest)) { $ok = $false }
            }
            if ($ok) { Write-Host ("  Moved to: " + $cur) -ForegroundColor Green }
            return "MOVED"
        } elseif ($act -eq "UP") {
            $cur = [System.IO.Path]::GetDirectoryName($cur)
        } elseif ($act -eq "ROOT") {
            $picked = Browse-ForFolder "Select the ROOT folder"
            if ($picked -and (Test-Path -LiteralPath $picked)) {
                Set-Setting 'ROOT' $picked
                $script:__root = $picked
                $cur = $picked
            }
        } elseif ($act -eq "CREATE") {
            Write-Host ""
            $target = $effContainer
            Write-Host ("  Creating in: " + $target) -ForegroundColor DarkGray
            $name = Read-Host ("  Folder name (Enter = " + $suggest + ")")
            if ([string]::IsNullOrWhiteSpace($name)) { $name = $suggest }
            $newDir = Join-Path $target $name
            try {
                if ($needYear -and (-not (Test-Path -LiteralPath $target))) { New-Item -ItemType Directory -Path $target | Out-Null }
                if (-not (Test-Path -LiteralPath $newDir)) { New-Item -ItemType Directory -Path $newDir | Out-Null }
                $cur = $newDir
            } catch {
                Write-Host ("  Could not create folder: " + $_.Exception.Message) -ForegroundColor Red
                [void][Console]::ReadKey($true)
            }
        } elseif ($act -eq "NEWDIR") {
            Write-Host ""
            Write-Host ("  Creating in: " + $cur) -ForegroundColor DarkGray
            $name = Read-Host "  New folder name (empty = cancel)"
            if (-not [string]::IsNullOrWhiteSpace($name)) {
                $newDir = Join-Path $cur $name
                try {
                    if (-not (Test-Path -LiteralPath $newDir)) { New-Item -ItemType Directory -Path $newDir | Out-Null }
                    $cur = $newDir
                } catch {
                    Write-Host ("  Could not create folder: " + $_.Exception.Message) -ForegroundColor Red
                    [void][Console]::ReadKey($true)
                }
            }
        } elseif ($act -eq "SKIP") {
            return "SKIP"
        } elseif ($act -like "DIR|*") {
            $cur = $act.Substring(4)
        }
    }
}

function Move-ControlFile([string]$path) {
    $dest = Get-OrAskFolder 'PUMPCONTROL' "Select the PUMP CONTROL folder"
    if (-not $dest) { return 0 }

    Clear-Host
    Show-Header
    Write-Host ""

    $name = [System.IO.Path]::GetFileName($path)
    if (-not (Test-Path -LiteralPath $path)) { return 0 }
    $target = Join-Path $dest $name
    if (Test-Path -LiteralPath $target) {
        Write-Host ("  Target exists, skipped: " + $name) -ForegroundColor DarkYellow
        return 0
    }
    if (Move-FileSafe $path $target) {
        Write-Host ("  Moved " + $name + " -> " + $dest) -ForegroundColor Green
        return 1
    }
    return 0
}

function Move-WpBundle([string]$title, [string[]]$paths) {
    if (Get-Setting 'REPRINT') {
        $opts = @("Pick list folder", "'Noch zu drucken' folder", "", "Back")
    } else {
        $opts = @("Pick list folder", "", "Back")
    }
    $c = Show-Menu $title $opts
    if ($c -lt 0) { return 0 }
    $pick = $opts[$c]
    if ($pick -eq "Back") { return 0 }
    if ($pick -eq "Pick list folder") { $dest = Get-OrAskFolder 'PICKLIST' "Select the PICK LIST folder" }
    else { $dest = Get-OrAskFolder 'REPRINT' "Select the 'Noch zu drucken' folder" }
    if (-not $dest) { return 0 }

    Clear-Host
    Show-Header
    Write-Host ""

    $n = 0
    foreach ($p in $paths) {
        $name = [System.IO.Path]::GetFileName($p)
        if (-not (Test-Path -LiteralPath $p)) { continue }
        $target = Join-Path $dest $name
        if (Test-Path -LiteralPath $target) {
            Write-Host ("  Target exists, skipped: " + $name) -ForegroundColor DarkYellow
            continue
        }
        if (Move-FileSafe $p $target) {
            Write-Host ("  Moved " + $name + " -> " + $dest) -ForegroundColor Green
            $n++
        }
    }
    return $n
}

function Get-PumpXlsxFor([string[]]$names) {
    $res = New-Object System.Collections.Generic.List[string]
    $wpNums = @{}
    foreach ($n in $names) {
        if ($n -match '^(WP\d+)') { $wpNums[$matches[1]] = $true }
    }
    if ($wpNums.Count -eq 0) { return @() }
    foreach ($x in @(Get-ChildItem -LiteralPath $WorkDir -Filter 'WP*_Pumpen*.xls*' -ErrorAction SilentlyContinue | Sort-Object Name)) {
        if ($x.Name -match '^(WP\d+)') {
            if ($wpNums.ContainsKey($matches[1])) { $res.Add($x.FullName) }
        }
    }
    return $res.ToArray()
}

function Invoke-Move {
    $script:__root = Get-RootFolder
    if (-not $script:__root) {
        Write-Host "  No root folder selected." -ForegroundColor Yellow
        return
    }

    $pairFile = Get-PairsFile
    $pairs = @{}
    if (Test-Path -LiteralPath $pairFile) {
        foreach ($l in (Get-Content -LiteralPath $pairFile)) {
            if ($l -match '^(PAC\d+)=(PWS\d+)$') { $pairs[$matches[1]] = $matches[2] }
        }
    }

    $moved = 0

    while ($true) {
        $spin = Start-Spin "reading documents..."
        $pacFiles = @(Get-ChildItem -LiteralPath $WorkDir -Filter 'PAC*.pdf' -ErrorAction SilentlyContinue | Sort-Object Name)
        $pwsFiles = @(Get-ChildItem -LiteralPath $WorkDir -Filter 'PWS*.pdf' -ErrorAction SilentlyContinue)
        $pwsByNum = @{}
        foreach ($f in $pwsFiles) { if ($f.Name -match '^(PWS\d+)') { $pwsByNum[$matches[1]] = $f } }

        $delEntries = New-Object System.Collections.Generic.List[object]
        $usedPws = @{}
        foreach ($f in $pacFiles) {
            $pacNum = if ($f.Name -match '^(PAC\d+)') { $matches[1] } else { $f.BaseName }
            $sord = Format-SordDisplay $f.Name
            $pwsNum = $pairs[$pacNum]
            if (-not $pwsNum) { $pwsNum = Get-PwsFromPdf $f.FullName }
            $paths = @()
            $detail = $pacNum
            $src = $f
            if ($pwsNum -and $pwsByNum.ContainsKey($pwsNum)) {
                $paths += $pwsByNum[$pwsNum].FullName
                $usedPws[$pwsNum] = $true
                $detail = "$pwsNum + $pacNum"
                $src = $pwsByNum[$pwsNum]
            }
            $paths += $f.FullName
            if ($sord) { $detail = $detail + " " + [char]0x2013 + " " + $sord }
            $delEntries.Add(@{ Detail = $detail; Paths = $paths; Src = $src })
        }
        foreach ($num in ($pwsByNum.Keys | Sort-Object)) {
            if (-not $usedPws[$num]) {
                $f = $pwsByNum[$num]
                $sord = Format-SordDisplay $f.Name
                $detail = $num
                if ($sord) { $detail = $detail + " " + [char]0x2013 + " " + $sord }
                $delEntries.Add(@{ Detail = $detail; Paths = @($f.FullName); Src = $f })
            }
        }

        foreach ($d in $delEntries) {
            $di = Get-DeliveryInfo $d.Src.FullName
            if (-not $di.Month -or -not $di.Year) {
                $di.Month = (Get-Date).Month
                $di.Year = (Get-Date).Year.ToString()
            }
            $d.Info = $di
            $d.Key = (Normalize-Name $di.Customer) + '|' + (Normalize-Name $di.Location) + '|' + $di.Country
        }
        $delGroups = New-Object System.Collections.Generic.List[object]
        $seenKey = @{}
        foreach ($d in $delEntries) {
            if ($seenKey.ContainsKey($d.Key)) { continue }
            $seenKey[$d.Key] = $true
            $members = @($delEntries | Where-Object { $_.Key -eq $d.Key })
            $allPaths = @()
            foreach ($m in $members) { $allPaths += $m.Paths }
            $delGroups.Add(@{ Members = $members; Paths = $allPaths; Info = $d.Info; Count = $members.Count })
        }

        $groupages = Get-ActiveGroupages
        $covered = @{}
        foreach ($g in $groupages) { foreach ($n in $g.Names) { $covered[$n] = $true } }
        $wpFiles = @(Get-ChildItem -LiteralPath $WorkDir -Filter 'WP*.pdf' -ErrorAction SilentlyContinue | Sort-Object Name)

        $entries = New-Object System.Collections.Generic.List[object]
        $entries.Add(@{ Text = "Delivery documents   (to customer folder)"; Header = $true })
        if ($delGroups.Count -eq 0) { $entries.Add(@{ Text = "(none)"; Header = $true }) }
        foreach ($g in $delGroups) {
            $cust = $g.Info.Customer
            if (-not $cust) { $cust = "(unknown customer)" }
            if ($g.Count -gt 1) {
                $lbl = $cust + "   (" + $g.Paths.Count + " files)"
            } else {
                $lbl = $cust + "   (" + $g.Members[0].Detail + ")"
            }
            $entries.Add(@{ Text = $lbl; Header = $false; Act = 'DEL'; Data = $g })
        }
        $entries.Add(@{ Text = ""; Header = $true })
        $entries.Add(@{ Text = "Warehouse picks   (to pick list / noch zu drucken)"; Header = $true })
        $pickCount = 0
        $usedPumps = @{}
        foreach ($g in $groupages) {
            $p = @($g.Paths)
            if ($g.HasXlsx) { $p += $g.Xlsx }
            $pumps = Get-PumpXlsxFor $g.Names
            $txt = $g.Label
            if ($pumps.Count -gt 0) {
                $p += $pumps
                foreach ($u in $pumps) { $usedPumps[$u] = $true }
                $txt = $txt + "  + " + $pumps.Count + " pump list(s)"
            }
            $entries.Add(@{ Text = $txt; Header = $false; Act = 'WP'; Title = ("MOVE GROUPAGE:   " + ($g.Customer -replace '_', ' ')); Paths = $p })
            $pickCount++
        }
        foreach ($f in $wpFiles) {
            if ($covered.ContainsKey($f.Name)) { continue }
            $p = @($f.FullName)
            $pumps = Get-PumpXlsxFor @($f.Name)
            $txt = $f.Name
            if ($pumps.Count -gt 0) {
                $p += $pumps
                foreach ($u in $pumps) { $usedPumps[$u] = $true }
                $txt = $txt + "   + pump list"
            }
            $entries.Add(@{ Text = $txt; Header = $false; Act = 'WP'; Title = ("MOVE PICK LIST:   " + $f.Name); Paths = $p })
            $pickCount++
        }
        foreach ($x in @(Get-ChildItem -LiteralPath $WorkDir -Filter 'WP*_Pumpen*.xls*' -ErrorAction SilentlyContinue | Sort-Object Name)) {
            if ($usedPumps.ContainsKey($x.FullName)) { continue }
            $entries.Add(@{ Text = $x.Name; Header = $false; Act = 'WP'; Title = ("MOVE PUMP LIST:   " + $x.Name); Paths = @($x.FullName) })
            $pickCount++
        }
        if ($pickCount -eq 0) { $entries.Add(@{ Text = "(none)"; Header = $true }) }
        $entries.Add(@{ Text = ""; Header = $true })
        $entries.Add(@{ Text = "Pump control files   (to pump control folder)"; Header = $true })
        $ctrlFiles = @(Get-ChildItem -LiteralPath $WorkDir -Filter 'WP*_Control*.xls*' -ErrorAction SilentlyContinue |
                       Where-Object { $_.Name -notmatch '^~\$' } | Sort-Object Name)
        if ($ctrlFiles.Count -eq 0) { $entries.Add(@{ Text = "(none)"; Header = $true }) }
        foreach ($c in $ctrlFiles) {
            $entries.Add(@{ Text = $c.Name; Header = $false; Act = 'CTRL'; Path = $c.FullName })
        }
        $entries.Add(@{ Text = ""; Header = $true })
        $entries.Add(@{ Text = "Back"; Header = $false; Act = 'BACK' })

        Stop-Spin $spin
        $sel = Show-DocMenu "MOVE DOCUMENTS" $entries.ToArray()
        if ($sel -lt 0) { break }
        $e = $entries[$sel]
        if ($e.Act -eq 'BACK') { break }

        $did = 0
        if ($e.Act -eq 'CTRL') {
            $did = Move-ControlFile $e.Path
        } elseif ($e.Act -eq 'WP') {
            $did = Move-WpBundle $e.Title $e.Paths
        } else {
            $g = $e.Data
            $info = $g.Info
            $monthLabel = $MonthsDE[$info.Month - 1] + " " + $info.Year
            $cust = $info.Customer
            if (-not $cust) { $cust = "(unknown customer)" }
            if ($g.Count -gt 1) {
                $title = $cust + "   (" + $g.Paths.Count + " files)    Date: " + $monthLabel
            } else {
                $title = $cust + "   (" + $g.Members[0].Detail + ")    Date: " + $monthLabel
            }
            $start = Resolve-StartFolder $script:__root $info
            $res = Move-PairInteractive $script:__root $start $title $info $g.Paths
            if ($res -eq "MOVED") { $did = $g.Paths.Count }
        }

        if ($did -gt 0) {
            $moved += $did
            Write-Host ""
            Write-Host "   Press any key to continue..." -ForegroundColor DarkGray
            [void][Console]::ReadKey($true)
        }
    }

    Invoke-Housekeeping

    Clear-Host
    Show-Header
    Write-Host ""
    Write-Host $light -ForegroundColor DarkCyan
    Write-Host "   MOVE SUMMARY" -ForegroundColor Cyan
    Write-Host ("     Files moved : " + $moved) -ForegroundColor Green
}

function Format-Setting([string]$value, [int]$max) {
    if (-not $value) { return "(not set)" }
    if ($value.Length -le $max) { return $value }
    return "..." + $value.Substring($value.Length - ($max - 3))
}

function Test-SetupComplete {
    $s = Get-Settings
    foreach ($k in @('PRINTER', 'ROOT', 'PICKLIST', 'PUMPCONTROL')) {
        if (-not $s[$k]) { return $false }
    }
    return $true
}

function Invoke-Settings([bool]$requireAll) {
    while ($true) {
        $s = Get-Settings
        $complete = Test-SetupComplete

        $entries = New-Object System.Collections.Generic.List[object]
        if ($requireAll) {
            $entries.Add(@{ Text = "Please configure all entries below."; Header = $true })
            $entries.Add(@{ Text = "They are stored, so you only do this once."; Header = $true })
            $entries.Add(@{ Text = ""; Header = $true })
        }
        if ($s['WORKDIR']) {
            $wdShow = Format-Setting $s['WORKDIR'] 46
        } else {
            $wdShow = (Format-Setting (Split-Path $AppDir -Parent) 38) + "   (auto)"
        }
        $entries.Add(@{ Text = ("Downloads folder".PadRight(24) + ":  " + $wdShow); Header = $false; Act = 'WORKDIR'; Done = [bool]$s['WORKDIR'] })
        $entries.Add(@{ Text = ""; Header = $true })
        $entries.Add(@{ Text = ("Default printer".PadRight(24) + ":  " + (Format-Setting $s['PRINTER'] 46)); Header = $false; Act = 'PRINTER'; Done = [bool]$s['PRINTER'] })
        $entries.Add(@{ Text = ("Outbound main folder".PadRight(24) + ":  " + (Format-Setting $s['ROOT'] 46)); Header = $false; Act = 'ROOT'; Done = [bool]$s['ROOT'] })
        $entries.Add(@{ Text = ("Pick list folder".PadRight(24) + ":  " + (Format-Setting $s['PICKLIST'] 46)); Header = $false; Act = 'PICKLIST'; Done = [bool]$s['PICKLIST'] })
        $reprintText = if ($s['REPRINT']) { Format-Setting $s['REPRINT'] 46 } else { "(optional)" }
        $entries.Add(@{ Text = ("'Noch zu drucken' folder".PadRight(24) + ":  " + $reprintText); Header = $false; Act = 'REPRINT'; Done = $true })
        $entries.Add(@{ Text = ("Pump control folder".PadRight(24) + ":  " + (Format-Setting $s['PUMPCONTROL'] 46)); Header = $false; Act = 'PUMPCONTROL'; Done = [bool]$s['PUMPCONTROL'] })
        $entries.Add(@{ Text = ("Halle M scan folder".PadRight(24) + ":  " + (Format-Setting $s['SCANDIR'] 40) + "   (beta)"); Header = $false; Act = 'SCANDIR'; Done = [bool]$s['SCANDIR'] })
        $bIdx = 0
        if ($s['BANNER'] -match '^\d+$') { $bIdx = [int]$s['BANNER'] }
        if ($bIdx -lt 0 -or $bIdx -ge $BannerStyles.Count) { $bIdx = 0 }
        $entries.Add(@{ Text = ("Banner style".PadRight(24) + ":  " + $BannerStyles[$bIdx].N); Header = $false; Act = 'BANNER'; Done = $true })
        $entries.Add(@{ Text = ""; Header = $true })
        if ($requireAll) {
            if ($complete) { $entries.Add(@{ Text = "Continue"; Header = $false; Act = 'DONE' }) }
            else { $entries.Add(@{ Text = "(set all entries above to continue)"; Header = $true }) }
        } else {
            $entries.Add(@{ Text = "Back"; Header = $false; Act = 'DONE' })
        }

        $title = if ($requireAll) { "WELCOME TO PROMEDIA COPILOT" } else { "SETTINGS" }
        $sel = Show-DocMenu $title $entries.ToArray()

        if ($sel -lt 0) {
            if ($requireAll -and -not $complete) { continue }
            $script:SkipPause = $true
            return
        }

        switch ($entries[$sel].Act) {
            'PRINTER'  { $pr = Select-Printer; if ($pr) { Set-Setting 'PRINTER' $pr } }
            'ROOT'     { $p = Browse-ForFolder "Select the OUTBOUND main folder (contains the country folders)"; if ($p) { Set-Setting 'ROOT' $p } }
            'PICKLIST' { $p = Browse-ForFolder "Select the PICK LIST folder"; if ($p) { Set-Setting 'PICKLIST' $p } }
            'REPRINT'  { $p = Browse-ForFolder "Select the 'Noch zu drucken' folder"; if ($p) { Set-Setting 'REPRINT' $p } }
            'PUMPCONTROL' { $p = Browse-ForFolder "Select the PUMP CONTROL folder"; if ($p) { Set-Setting 'PUMPCONTROL' $p } }
            'SCANDIR'  { $p = Browse-ForFolder "Select the Halle M SCAN folder (signed delivery documents)"; if ($p) { Set-Setting 'SCANDIR' $p } }
            'WORKDIR'  {
                $p = Browse-ForFolder "Select the DOWNLOADS folder (where the PDFs are downloaded)"
                if ($p) { Set-Setting 'WORKDIR' $p; $script:WorkDir = $p.TrimEnd('\') }
            }
            'BANNER'   {
                $names = @($BannerStyles | ForEach-Object { $_.N })
                $bsel = Show-Menu "BANNER STYLE" (@($names) + "" + "Back")
                if ($bsel -ge 0 -and $bsel -lt $names.Count) {
                    Set-Setting 'BANNER' ([string]$bsel)
                    $script:BannerCache = $null
                }
            }
            'DONE'     { $script:SkipPause = $true; return }
        }
    }
}

$FuMenuLabel = $FuPrefix + " scan   (beta)"
$FuMoveLabel = "Auto move " + $FuPrefix + " documents   (beta)"
$mainItems = @("Auto rename/create documents", "Annotate WP documents", "Print", "Auto move to folders", $FuMenuLabel, $FuMoveLabel, "Settings", "", "Quit")

$cfgWork = Get-Setting 'WORKDIR'
if ($cfgWork -and (Test-Path -LiteralPath $cfgWork)) { $WorkDir = $cfgWork.TrimEnd('\') }

try {
    if (-not (Test-SetupComplete)) { Invoke-Settings $true }

    Invoke-Housekeeping

    while ($true) {
        $choice = Show-Menu "MAIN MENU" $mainItems

        if ($choice -lt 0 -or $mainItems[$choice] -eq "Quit") {
            Clear-Host
            Show-Header
            Write-Host ""
            Write-Host "   Bye." -ForegroundColor DarkGray
            Write-Host ""
            try { [Console]::CursorVisible = $true } catch { }
            return
        }

        Clear-Host
        Show-Header
        Write-Host ""

        $script:SkipPause = $false
        switch ($mainItems[$choice]) {
            "Auto rename/create documents" { Invoke-Rename }
            "Annotate WP documents" { Invoke-Annotate }
            "Print"                 { Invoke-Print }
            "Auto move to folders"  { Invoke-Move }
            $FuMenuLabel            { Invoke-FuScan }
            $FuMoveLabel            { Invoke-FuMove }
            "Settings"              { Invoke-Settings $false }
        }

        if (-not $script:SkipPause) {
            Write-Host ""
            Write-Host $light -ForegroundColor DarkCyan
            Write-Host "   Press any key to return to the menu..." -ForegroundColor DarkGray
            [void][Console]::ReadKey($true)
        }
    }
} catch {
    try { [Console]::CursorVisible = $true } catch { }
    Clear-Host
    Write-Host ""
    Write-Host "   ERROR" -ForegroundColor Red
    Write-Host ("   " + $_.Exception.Message) -ForegroundColor Red
    Write-Host ""
    if ($_.InvocationInfo) {
        Write-Host ("   Line " + $_.InvocationInfo.ScriptLineNumber + ":  " + $_.InvocationInfo.Line.Trim()) -ForegroundColor DarkGray
        Write-Host ""
    }
    Write-Host "   Press any key to exit..." -ForegroundColor DarkGray
    [void][Console]::ReadKey($true)
}
