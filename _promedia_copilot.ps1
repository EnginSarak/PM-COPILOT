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
$script:DefaultBanner = 1

function Get-BannerArt {
    if ($script:BannerCache) { return $script:BannerCache }
    $idx = $script:DefaultBanner
    $v = Get-Setting 'BANNER'
    if ($v -match '^\d+$') { $idx = [int]$v }
    if ($idx -lt 0 -or $idx -ge $BannerStyles.Count) { $idx = $script:DefaultBanner }
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

function Convert-NameAlias([string]$v) {
    if (-not $v) { return $v }
    return ([regex]::Replace($v, '(?i)(?<![A-Za-z])FAROUK[\s_]+MAAMOUN(?![A-Za-z])', 'Tamer'))
}

function Remove-RegionCode([string]$v) {
    if (-not $v) { return $v }
    $v = [regex]::Replace($v, '\(\s*[A-Za-z]{2}\s*\)', ' ')
    return ($v -replace '[ \t]{2,}', ' ').Trim()
}

function Get-Kunde([string]$text) {
    $v = Get-DestName $text
    if (-not $v) { return $null }
    $v = $v -replace '[\\/:*?"<>|]', ' '
    $parts = @($v -split '\s+' | Where-Object { $_ -ne '' -and $_ -notmatch '^[&+]+$' -and $_ -notmatch '^(and|und)$' })
    if ($parts.Count -eq 0) { return $null }
    if ($parts.Count -gt 2) { $parts = $parts[0..1] }
    return (Convert-NameAlias ($parts -join '_'))
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
                Copy-Item -LiteralPath $tpl[0].FullName -Destination $newPath -ErrorAction Stop
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

$script:AppVersion = '1.5.1'

function Compare-AppVersion([string]$a, [string]$b) {
    $pa = @($a -split '\.' | ForEach-Object { try { [int]$_ } catch { 0 } })
    $pb = @($b -split '\.' | ForEach-Object { try { [int]$_ } catch { 0 } })
    for ($i = 0; $i -lt 3; $i++) {
        $va = if ($i -lt $pa.Count) { $pa[$i] } else { 0 }
        $vb = if ($i -lt $pb.Count) { $pb[$i] } else { 0 }
        if ($va -ne $vb) { return ($va - $vb) }
    }
    return 0
}

# Offline update: a ZIP of the tool (GitHub "Download ZIP") placed next to the .bat. No internet access.
function Get-ZipUpdateInfo([string]$zipPath) {
    $zip = $null
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
        $manifest = @($zip.Entries | Where-Object { $_.Name -eq 'update.txt' } |
            Sort-Object { ($_.FullName -split '/').Count }) | Select-Object -First 1
        if (-not $manifest) { return $null }
        $prefix = $manifest.FullName.Substring(0, $manifest.FullName.Length - 'update.txt'.Length)

        $sr = New-Object System.IO.StreamReader($manifest.Open())
        try { $text = $sr.ReadToEnd() } finally { $sr.Dispose() }

        $info = @{ Zip = $zipPath; Prefix = $prefix; Version = ''; Note = ''; Files = New-Object System.Collections.Generic.List[string] }
        foreach ($ln in ($text -split '\r?\n')) {
            if ($ln -match '^VERSION=(.+)$') { $info.Version = $matches[1].Trim() }
            elseif ($ln -match '^NOTE=(.+)$') { $info.Note = $matches[1].Trim() }
            elseif ($ln -match '^FILE=(.+)$') { $info.Files.Add($matches[1].Trim()) }
        }
        if (-not $info.Version -or -not $info.Files.Contains('_promedia_copilot.ps1')) { return $null }
        $names = @($zip.Entries | ForEach-Object { $_.FullName })
        foreach ($f in $info.Files) { if ($names -notcontains ($prefix + $f)) { return $null } }
        return $info
    } catch {
        return $null
    } finally {
        if ($zip) { $zip.Dispose() }
    }
}

function Install-ZipUpdate([hashtable]$info) {
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('pmcopilot_update_' + [guid]::NewGuid().ToString('N'))
    $zip = $null
    try {
        New-Item -ItemType Directory -Path $tmp -ErrorAction Stop | Out-Null
        $zip = [System.IO.Compression.ZipFile]::OpenRead($info.Zip)
        foreach ($f in $info.Files) {
            $entry = $zip.GetEntry($info.Prefix + $f)
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, (Join-Path $tmp $f), $true)
        }
    } catch {
        Write-Host ('   Could not read the update file: ' + $_.Exception.Message) -ForegroundColor Red
        if ($zip) { $zip.Dispose() }
        try { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue } catch { }
        return $false
    }
    $zip.Dispose()

    $ok = $true
    foreach ($f in $info.Files) {
        try { Copy-Item -LiteralPath (Join-Path $tmp $f) -Destination (Join-Path $AppDir $f) -Force -ErrorAction Stop }
        catch { Write-Host ('   Could not replace ' + $f + ': ' + $_.Exception.Message) -ForegroundColor Red; $ok = $false }
    }
    try { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue } catch { }
    return $ok
}

function Invoke-LocalUpdate {
    $zips = @(Get-ChildItem -LiteralPath $AppDir -Filter '*.zip' -File -ErrorAction SilentlyContinue)
    if ($zips.Count -eq 0) { return }
    try {
        Add-Type -AssemblyName System.IO.Compression -ErrorAction Stop
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop
    } catch { return }

    $best = $null
    $stale = New-Object System.Collections.Generic.List[object]
    foreach ($z in $zips) {
        $info = Get-ZipUpdateInfo $z.FullName
        if (-not $info) { continue }
        if ((Compare-AppVersion $info.Version $script:AppVersion) -le 0) { $stale.Add($info); continue }
        if (-not $best -or (Compare-AppVersion $info.Version $best.Version) -gt 0) {
            if ($best) { $stale.Add($best) }
            $best = $info
        } else { $stale.Add($info) }
    }

    foreach ($s in $stale) {
        try {
            Remove-Item -LiteralPath $s.Zip -Force -ErrorAction Stop
            Write-Host ('   Removed old update file ' + (Split-Path $s.Zip -Leaf) + ' (Version ' + $s.Version + ', not newer than ' + $script:AppVersion + ').') -ForegroundColor DarkGray
        } catch { }
    }
    if (-not $best) { return }

    Write-Host ""
    Write-Host $light -ForegroundColor DarkCyan
    Write-Host ("   UPDATE FILE FOUND:  " + $script:AppVersion + "  ->  " + $best.Version) -ForegroundColor Cyan
    Write-Host ("   " + (Split-Path $best.Zip -Leaf)) -ForegroundColor DarkGray
    if ($best.Note) { Write-Host ("   " + $best.Note) -ForegroundColor DarkGray }
    Write-Host $light -ForegroundColor DarkCyan
    Write-Host ""
    $ans = Read-Host "   Install now? (Y/N)"
    if ($ans -notmatch '(?i)^y') { return }

    if (Install-ZipUpdate $best) {
        try { Remove-Item -LiteralPath $best.Zip -Force -ErrorAction Stop } catch { }
        Write-Host ("   Updated to " + $best.Version + ". Restarting...") -ForegroundColor Green
        Start-Sleep -Seconds 1
        try { Start-Process -FilePath (Join-Path $AppDir "PROMEDIA COPILOT.bat") } catch { }
        $script:SkipPause = $true
        exit
    } else {
        Write-Host "   Update failed. Still running the current version." -ForegroundColor Red
        Write-Host ""
        Write-Host "   Press any key to continue..." -ForegroundColor DarkGray
        [void][Console]::ReadKey($true)
    }
}

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

        if ($v -eq 'Take' -or $v -eq 'Place') {
            $nx = $i + 1
            while ($nx -lt $toks.Count -and -not $toks[$nx]) { $nx++ }
            if ($nx -lt $toks.Count) {
                $cand = $toks[$nx].Trim()
                if ($cand.Length -le 20 -and $cand -match '^[A-Z][A-Z0-9]*(\.\d+)?$' -and $cand -notmatch '^N\d{8,}$') {
                    $curBin = $cand
                }
            }
            continue
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
    return (Convert-NameAlias ($parts -join '_'))
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

    $spin = Start-Spin ("building " + $newName + " in Excel...")
    $xl = $null
    $wbT = $null
    try {
        Copy-Item -LiteralPath $tpl.FullName -Destination $newPath -ErrorAction Stop
        try { Unblock-File -LiteralPath $newPath -ErrorAction SilentlyContinue } catch { }

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

    $spin = Start-Spin ("building " + $newName + " in Excel...")
    $xl = $null
    $wbT = $null
    $ok = $false
    try {
        Copy-Item -LiteralPath $tpl.FullName -Destination $newPath -ErrorAction Stop
        try { Unblock-File -LiteralPath $newPath -ErrorAction SilentlyContinue } catch { }

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

        try {
            if ($caseOnly) {
                $tmp = Join-Path $WorkDir ($newName + '.__case')
                Move-Item -LiteralPath $f -Destination $tmp -Force -ErrorAction Stop
                Move-Item -LiteralPath $tmp -Destination $target -Force -ErrorAction Stop
            } else {
                Move-Item -LiteralPath $f -Destination $target -ErrorAction Stop
            }
            Write-Host ("  " + $orig + "  ->  " + $newName) -ForegroundColor Green
            $renamed++
        } catch {
            Write-Host ("  Could not rename " + $orig + ": " + $_.Exception.Message) -ForegroundColor Red
            $fail++
        }
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

function Get-OcrPages([string]$path, [int]$maxPages = 6) {
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

    $count = [int]$pdf.PageCount
    if ($maxPages -gt 0 -and $count -gt $maxPages) { $count = $maxPages }
    $maxDim = [double][Windows.Media.Ocr.OcrEngine]::MaxImageDimension
    $pages = New-Object System.Collections.Generic.List[string]

    for ($p = 0; $p -lt $count; $p++) {
        $page = $pdf.GetPage([uint32]$p)
        $ras = New-Object Windows.Storage.Streams.InMemoryRandomAccessStream
        $opts = New-Object Windows.Data.Pdf.PdfPageRenderOptions
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
        $pages.Add($sb.ToString())

        try { $bitmap.Dispose() } catch { }
        try { $page.Dispose() } catch { }
        try { $ras.Dispose() } catch { }
    }

    try { $inStream.Dispose() } catch { }
    try { $ms.Dispose() } catch { }
    return $pages.ToArray()
}

function Get-OcrPageText([string]$path, [int]$pageIndex = 0) {
    $pages = @(Get-OcrPages $path ($pageIndex + 1))
    if ($pageIndex -ge $pages.Count) { return '' }
    return $pages[$pageIndex]
}

function Get-FuDocText([string[]]$pages) {
    if (-not $pages -or $pages.Count -eq 0) { return '' }
    $doc = @($pages | Where-Object { $_ -match '(?i)(PW[S5]\s*\d|PAC\s*\d|AX[I1l]UM)' })
    if ($doc.Count -eq 0) { $doc = $pages }
    return ($doc -join "`n")
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
    return (Convert-NameAlias (@($merged)[0..($take - 1)] -join '_'))
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

    Write-Host ("  " + $cands.Count + " scanned document(s) to check.") -ForegroundColor DarkCyan

    $renamed = 0
    $skipped = 0
    $failed = 0
    foreach ($f in $cands) {
        $spin = Start-Spin ("reading " + $f.Name + " (OCR)...")
        $text = $null
        $err = ''
        $ok = $true
        try { $text = Get-FuDocText (Get-OcrPages $f.FullName 6) } catch { $ok = $false; $err = $_.Exception.GetBaseException().Message }
        Stop-Spin $spin
        if (-not $ok) {
            Write-Host ("  ERROR reading " + $f.Name + ": " + $err) -ForegroundColor Red
            $failed++
            continue
        }

        $info = Get-FuInfo $text
        if (-not $info.IsFu) {
            Write-Host ("  skipped (no " + $FuPrefix + " recognized): " + $f.Name) -ForegroundColor DarkGray
            $skipped++
            continue
        }
        if ($info.Kunde -match '^(?i)PR[O0]MED[I1l]A') { continue }

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
                Move-Item -LiteralPath $f.FullName -Destination $target -ErrorAction Stop
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

function Get-FuDestLines([string[]]$lines) {
    $stop = '(?i)(^\s*(product|item\b|reference|descript|notes|q\.?ty|u\.?m\b|lot\s*no|expiry|goods|package|gross|net\s|withdrawal|driver|recipient|connected|sold\s*to|page\b)|ax[i1l]um|customer.?s\s*(po|code))'
    $out = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -notmatch '(?i)destinat(?!aire)') { continue }
        for ($j = $i + 1; $j -lt $lines.Count -and $out.Count -lt 5; $j++) {
            $raw = $lines[$j].Trim()
            if (-not $raw) { continue }
            if ($raw -match $stop) { break }
            $v = $raw -replace '(?i)marienh\S*[\s\d]*siegen\s*\(?\s*57080\s*\)?\s*DE\b', ' '
            $v = $v -replace '(?i)marienh\S*|siegen|\(?\s*57080\s*\)?', ' '
            $v = $v -replace '(?i)pick.?up|addres+\w*|aderes+\w*', ' '
            $v = $v -replace '(?i)incoterms?|carrier|transport\s*reason|shipment\s*method|doc\.\s*(type|no\.?|date)', ' '
            $v = $v -replace '(?i)\bPW[S5]\d+\b|\bPAC\d+\b', ' '
            $v = $v -replace '\b\d{2}\.\d{2}\.\d{4}\b', ' '
            $v = ($v -replace '\s{2,}', ' ').Trim()
            if (-not $v) { continue }
            $out.Add($v)
        }
        break
    }
    return $out.ToArray()
}

function Get-FuDestCountry([string[]]$addr) {
    if (-not $addr -or $addr.Count -eq 0) { return "" }
    for ($i = $addr.Count - 1; $i -ge 0; $i--) {
        $m = [regex]::Match($addr[$i], '\b([A-Z]{2})\s*$')
        if ($m.Success -and $IsoCountry.ContainsKey($m.Groups[1].Value)) { return $m.Groups[1].Value }
    }
    foreach ($l in $addr) {
        $m = [regex]::Match($l, '\b([A-Za-z]{2})-\d{3,5}\b')
        if ($m.Success) {
            $cc = $m.Groups[1].Value.ToUpper()
            if ($IsoCountry.ContainsKey($cc)) { return $cc }
        }
    }
    $found = ""
    foreach ($mm in [regex]::Matches(($addr -join "`n"), '\b([A-Z]{2})\b')) {
        if ($IsoCountry.ContainsKey($mm.Groups[1].Value)) { $found = $mm.Groups[1].Value }
    }
    if ($found) { return $found }
    return (Get-CountryCode ($addr -join ' '))
}

function Get-FuMoveInfo($f) {
    $text = Get-FuDocText (Get-OcrPages $f.FullName 1)
    if (-not (($text -match '(?i)ax[i1l]um') -and ($text -match '(?i)destinat(?!aire)'))) {
        $text = Get-FuDocText (Get-OcrPages $f.FullName 6)
    }
    $lines = @($text -split '\r?\n')

    $destLines = @(Get-FuDestLines $lines)
    $destText = Remove-RegionCode ($destLines -join "`n")

    $addr = New-Object System.Collections.Generic.List[string]
    foreach ($dl in $destLines) {
        $dl = Remove-RegionCode $dl
        if (-not $dl -or $dl -match '^\d{1,3}$') { continue }
        $addr.Add($dl)
    }

    $country = Get-FuDestCountry $addr.ToArray()
    while ($addr.Count -gt 1 -and $addr[$addr.Count - 1] -match '^[A-Z]{2}$') { $addr.RemoveAt($addr.Count - 1) }

    $location = ''
    if ($addr.Count -gt 0) {
        $location = $addr[$addr.Count - 1]
        while ($location -match '\s+[A-Z]{2}\s*$') { $location = ([regex]::Replace($location, '\s+[A-Z]{2}\s*$', '')).Trim() }
        for ($k = 0; $k -lt 2; $k++) {
            $location = $location -replace '^\s*[A-Za-z]{2}-\d{3,5}\s*', ''
            $location = $location -replace '^\s*\d{4,5}\s+[A-Z]{2}\s+', ''
            $location = $location -replace '^\s*\d{4,6}\s+', ''
            $location = $location -replace '^\s*\d{1,3}\s+', ''
        }
        $location = $location.Trim()
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

    $kundeFull = $kunde
    if ($destLines.Count -gt 0) {
        $cand = ($destLines[0] -replace '[\\/:*?"<>|]', ' ').Trim()
        if ($cand -and (Normalize-Name $cand)) { $kundeFull = $cand }
    }

    return @{ Customer = $kunde; CustomerFull = $kundeFull; Month = $month; Year = $year; SiteText = $text; Country = $country; DestText = $destText; Location = $location }
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
        $entries.Add(@{ Text = ($FuPrefix + " documents   (to customer folder)"); Header = $true })
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
            $openList = New-Object System.Collections.Generic.List[string]
            if ($g.HasXlsx) { $openList.Add($g.Xlsx) }
            foreach ($u in (Get-PumpXlsxFor $g.Names)) { $openList.Add($u) }
            $entries.Add(@{ Text = $t; Header = $false; Paths = $g.Paths; Copies = 1; Id = $g.Id; Done = $done; Open = $openList.ToArray() })
        }
        foreach ($f in $wp) {
            if ($covered.ContainsKey($f.Name)) { continue }
            $done = $printed.Contains($f.Name)
            $pumps = @(Get-PumpXlsxFor @($f.Name))
            $t = $f.Name
            if ($pumps.Count -gt 0) { $t = $t + "   + " + $pumps.Count + " pump list(s)" }
            if ($done) { $t = $t + "   [printed]" }
            $entries.Add(@{ Text = $t; Header = $false; Paths = @($f.FullName); Copies = 1; Id = $f.Name; Done = $done; Open = $pumps })
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
        foreach ($o in @($chosen.Open)) {
            if (-not $o) { continue }
            if (-not (Test-Path -LiteralPath $o)) { continue }
            Write-Host ("  Opening " + [System.IO.Path]::GetFileName($o) + " (print it manually)") -ForegroundColor Cyan
            try { Start-Process -FilePath $o } catch { }
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

# Layout-aware PDF text reader for documents not made by Business Central (Axium invoices, Italian
# certificates): fonts with ToUnicode maps or simple encodings, object streams, form XObjects.
$pdfTokRx = [regex]::new('\((?>[^()\\]+|\\.|\((?<d>)|\)(?<-d>))*(?(d)(?!))\)|<<|>>|<[0-9A-Fa-f\s]*>|[\[\]{}]|/[^\s/\[\]()<>{}%]*|[+-]?(?:\d+\.?\d*|\.\d+)|[A-Za-z''"*][A-Za-z0-9''"*]*|%[^\r\n]*', [System.Text.RegularExpressions.RegexOptions]::Singleline)
$pdfObjRx = [regex]::new('(?<![0-9])(\d+)\s+\d+\s+obj\b(.*?)endobj', [System.Text.RegularExpressions.RegexOptions]::Singleline)
$pdfEscRx = [regex]::new('\\(?:[0-7]{1,3}|\r\n|.)', [System.Text.RegularExpressions.RegexOptions]::Singleline)
$pdfInv = [System.Globalization.CultureInfo]::InvariantCulture
$pdfAnsi = [System.Text.Encoding]::GetEncoding(1252)

# Escape sequence -> byte char, looked up instead of decoded one by one
$PdfEscapes = New-Object System.Collections.Hashtable([System.StringComparer]::Ordinal)
for ($pdfN = 0; $pdfN -lt 256; $pdfN++) {
    $pdfO = [Convert]::ToString($pdfN, 8)
    foreach ($pdfLen in 1..3) { if ($pdfO.Length -le $pdfLen) { $PdfEscapes['\' + $pdfO.PadLeft($pdfLen, '0')] = [string][char]$pdfN } }
}
foreach ($pdfPair in @(@('\n', "`n"), @('\r', "`r"), @('\t', "`t"), @('\b', [string][char]8), @('\f', [string][char]12), @("\`r`n", ''), @("\`n", ''), @("\`r", ''))) {
    $PdfEscapes[$pdfPair[0]] = $pdfPair[1]
}

# Glyph names of simple-font /Differences arrays (case matters: Adieresis vs adieresis)
$PdfGlyphNames = New-Object System.Collections.Hashtable([System.StringComparer]::Ordinal)
foreach ($pdfPair in @(
    'space= ', 'exclam=!', 'quotedbl="', 'numbersign=#', 'dollar=$', 'percent=%', 'ampersand=&', "quotesingle='", "quoteright='",
    "quoteleft='", 'parenleft=(', 'parenright=)', 'asterisk=*', 'plus=+', 'comma=,', 'hyphen=-', 'minus=-', 'endash=-', 'emdash=-',
    'period=.', 'slash=/', 'colon=:', 'semicolon=;', 'less=<', 'equal==', 'greater=>', 'question=?', 'at=@', 'bracketleft=[',
    'backslash=\', 'bracketright=]', 'asciicircum=^', 'underscore=_', 'grave=`', 'braceleft={', 'bar=|', 'braceright=}',
    'asciitilde=~', 'zero=0', 'one=1', 'two=2', 'three=3', 'four=4', 'five=5', 'six=6', 'seven=7', 'eight=8', 'nine=9',
    'quotedblleft="', 'quotedblright="', 'bullet=*', 'nbspace= ')) {
    $PdfGlyphNames[$pdfPair.Substring(0, $pdfPair.IndexOf('='))] = $pdfPair.Substring($pdfPair.IndexOf('=') + 1)
}
foreach ($pdfPair in @(
    @('degree', 0xB0), @('section', 0xA7), @('Euro', 0x20AC), @('Adieresis', 0xC4), @('Odieresis', 0xD6), @('Udieresis', 0xDC),
    @('adieresis', 0xE4), @('odieresis', 0xF6), @('udieresis', 0xFC), @('germandbls', 0xDF), @('eacute', 0xE9), @('Eacute', 0xC9),
    @('egrave', 0xE8), @('agrave', 0xE0), @('ugrave', 0xF9), @('ograve', 0xF2), @('igrave', 0xEC), @('ccedilla', 0xE7))) {
    $PdfGlyphNames[$pdfPair[0]] = [string][char]$pdfPair[1]
}

function ConvertFrom-PdfString([string]$tok) {
    # Literal "(...)" or hex "<...>" string token -> one char per byte
    if ($tok.StartsWith('<')) {
        $h = $tok.Substring(1, $tok.Length - 2) -replace '\s', ''
        if ($h.Length % 2 -eq 1) { $h += '0' }
        $sb = New-Object System.Text.StringBuilder
        for ($i = 0; $i -lt $h.Length; $i += 2) { [void]$sb.Append([char][Convert]::ToInt32($h.Substring($i, 2), 16)) }
        return $sb.ToString()
    }
    $s = $tok.Substring(1, $tok.Length - 2)
    if ($s.IndexOf('\') -lt 0) { return $s }
    $sb = New-Object System.Text.StringBuilder
    $pos = 0
    foreach ($m in $pdfEscRx.Matches($s)) {
        if ($m.Index -gt $pos) { [void]$sb.Append($s, $pos, $m.Index - $pos) }
        $v = $m.Value
        $ch = $PdfEscapes[$v]
        if ($null -eq $ch) { $ch = $v.Substring(1) }
        [void]$sb.Append($ch)
        $pos = $m.Index + $m.Length
    }
    if ($pos -lt $s.Length) { [void]$sb.Append($s, $pos, $s.Length - $pos) }
    return $sb.ToString()
}

function Get-PdfTokens([string]$s) {
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($m in $pdfTokRx.Matches($s)) { if ($m.Value[0] -ne '%') { $out.Add($m.Value) } }
    return ,$out
}

function Read-PdfDictValue([string]$dict, [string]$key) {
    # Value of a top-level key of a "<< ... >>" dictionary, as raw text ("5 0 R", "<<...>>", "[...]", "/Name", "12")
    if (-not $dict) { return $null }
    $ms = $pdfTokRx.Matches($dict)
    $depth = 0
    for ($i = 0; $i -lt $ms.Count; $i++) {
        $v = $ms[$i].Value
        if ($v -eq '<<' -or $v -eq '[') { $depth++; continue }
        if ($v -eq '>>' -or $v -eq ']') { $depth--; continue }
        if ($depth -ne 1 -or $v -cne $key) { continue }
        if ($i + 1 -ge $ms.Count) { return $null }
        $n = $ms[$i + 1]
        if ($n.Value -eq '<<' -or $n.Value -eq '[') {
            $d = 0
            for ($j = $i + 1; $j -lt $ms.Count; $j++) {
                $w = $ms[$j].Value
                if ($w -eq '<<' -or $w -eq '[') { $d++ }
                elseif ($w -eq '>>' -or $w -eq ']') {
                    $d--
                    if ($d -eq 0) { return $dict.Substring($n.Index, $ms[$j].Index + $ms[$j].Length - $n.Index) }
                }
            }
            return $null
        }
        if ($i + 3 -lt $ms.Count -and $ms[$i + 3].Value -ceq 'R' -and $n.Value -match '^\d+$' -and $ms[$i + 2].Value -match '^\d+$') {
            return ($n.Value + ' ' + $ms[$i + 2].Value + ' R')
        }
        return $n.Value
    }
    return $null
}

function Resolve-PdfValue($doc, [string]$v) {
    # Follows an "n 0 R" reference to the object text; anything else is returned as it is
    if ($v -and $v -match '^\s*(\d+)\s+\d+\s+R\s*$') {
        $num = [int]$matches[1]
        if ($doc.Objs.ContainsKey($num)) { return $doc.Objs[$num] }
        return $null
    }
    return $v
}

function Get-PdfDictPart([string]$body) {
    # The dictionary of an object body, without a following stream
    if (-not $body) { return '' }
    $t = $body.TrimStart()
    if (-not $t.StartsWith('<<')) { return $t }
    $st = $body.IndexOf('stream')
    if ($st -lt 0) { return $body }
    return $body.Substring(0, $st)
}

function Get-PdfStreamBytes($doc, [string]$body) {
    $st = $body.IndexOf('stream')
    if ($st -lt 0) { return $null }
    $dict = $body.Substring(0, $st)
    $p = $st + 6
    if ($p -lt $body.Length -and $body[$p] -eq "`r") { $p++ }
    if ($p -lt $body.Length -and $body[$p] -eq "`n") { $p++ }
    $len = -1
    $lv = Resolve-PdfValue $doc (Read-PdfDictValue $dict '/Length')
    if ($lv -and $lv.Trim() -match '^\d+$') { $len = [int]$lv.Trim() }
    if ($len -lt 0 -or $p + $len -gt $body.Length) {
        $en = $body.LastIndexOf('endstream')
        if ($en -lt $p) { return $null }
        $len = $en - $p
    }
    $raw = $latin.GetBytes($body.Substring($p, $len))
    $filter = [string](Read-PdfDictValue $dict '/Filter')
    if (-not $filter) { return $raw }
    if ($filter -match '^\s*(/FlateDecode|/Fl|\[\s*/FlateDecode\s*\]|\[\s*/Fl\s*\])\s*$') { return (Inflate $raw) }
    return $null
}

function Open-PdfDoc([string]$path) {
    $s = $latin.GetString([System.IO.File]::ReadAllBytes($path))
    $objs = @{}
    foreach ($m in $pdfObjRx.Matches($s)) { $objs[[int]$m.Groups[1].Value] = $m.Groups[2].Value }
    $doc = @{ Raw = $s; Objs = $objs; Fonts = @{} }
    $packed = @{}
    foreach ($k in @($objs.Keys)) {
        $b = $objs[$k]
        if ($b -notmatch '/Type\s*/ObjStm') { continue }
        $dict = Get-PdfDictPart $b
        $data = Get-PdfStreamBytes $doc $b
        if (-not $data) { continue }
        $txt = $latin.GetString($data)
        $first = [int](Resolve-PdfValue $doc (Read-PdfDictValue $dict '/First'))
        $nums = @([regex]::Matches($txt.Substring(0, [math]::Min($first, $txt.Length)), '\d+') | ForEach-Object { [int]$_.Value })
        for ($i = 0; $i + 1 -lt $nums.Count; $i += 2) {
            $start = $first + $nums[$i + 1]
            $end = $txt.Length
            if ($i + 3 -lt $nums.Count) { $end = $first + $nums[$i + 3] }
            if ($start -lt $txt.Length -and $end -gt $start) { $packed[$nums[$i]] = $txt.Substring($start, $end - $start) }
        }
    }
    foreach ($k in $packed.Keys) { if (-not $objs.ContainsKey($k)) { $objs[$k] = $packed[$k] } }
    return $doc
}

function Get-PdfPageList($doc) {
    $pages = New-Object System.Collections.Generic.List[object]
    $rootM = [regex]::Matches($doc.Raw, '/Root\s+(\d+)\s+\d+\s+R')
    $treeRef = $null
    if ($rootM.Count -gt 0) {
        $cat = Get-PdfDictPart (Resolve-PdfValue $doc ($rootM[$rootM.Count - 1].Groups[1].Value + ' 0 R'))
        $treeRef = Read-PdfDictValue $cat '/Pages'
    }
    $stack = New-Object System.Collections.Generic.List[object]
    if ($treeRef) { $stack.Add(@{ Ref = $treeRef; Res = $null }) }
    $seen = @{}
    while ($stack.Count -gt 0) {
        $node = $stack[0]; $stack.RemoveAt(0)
        if ($node.Ref -notmatch '^\s*(\d+)') { continue }
        $num = [int]$matches[1]
        if ($seen.ContainsKey($num)) { continue }
        $seen[$num] = $true
        $d = Get-PdfDictPart (Resolve-PdfValue $doc $node.Ref)
        if (-not $d) { continue }
        $res = Read-PdfDictValue $d '/Resources'
        if (-not $res) { $res = $node.Res }
        $kids = Resolve-PdfValue $doc (Read-PdfDictValue $d '/Kids')
        if ($kids) {
            $i = 0
            foreach ($km in [regex]::Matches($kids, '(\d+)\s+\d+\s+R')) {
                $stack.Insert($i, @{ Ref = ($km.Groups[1].Value + ' 0 R'); Res = $res }); $i++
            }
        } else {
            $pages.Add(@{ Dict = $d; Res = $res })
        }
    }
    if ($pages.Count -eq 0) {
        foreach ($k in ($doc.Objs.Keys | Sort-Object)) {
            $d = Get-PdfDictPart $doc.Objs[$k]
            if ($d -match '/Type\s*/Page(?!s)') { $pages.Add(@{ Dict = $d; Res = (Read-PdfDictValue $d '/Resources') }) }
        }
    }
    return ,$pages
}

function Read-PdfCMap([string]$cmap) {
    # ToUnicode CMap -> @{ Map = code->text; Bytes = code length }
    $map = @{}
    $bytes = 1
    $cs = [regex]::Match($cmap, 'begincodespacerange\s*<([0-9A-Fa-f]+)>')
    if ($cs.Success -and $cs.Groups[1].Value.Length -ge 4) { $bytes = 2 }
    foreach ($blk in [regex]::Matches($cmap, 'beginbfchar(.*?)endbfchar', [System.Text.RegularExpressions.RegexOptions]::Singleline)) {
        foreach ($m in [regex]::Matches($blk.Groups[1].Value, '<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]*)>')) {
            if ($m.Groups[1].Value.Length -ge 4) { $bytes = 2 }
            $map[[Convert]::ToInt32($m.Groups[1].Value, 16)] = (ConvertFrom-PdfUtf16 $m.Groups[2].Value)
        }
    }
    foreach ($blk in [regex]::Matches($cmap, 'beginbfrange(.*?)endbfrange', [System.Text.RegularExpressions.RegexOptions]::Singleline)) {
        foreach ($m in [regex]::Matches($blk.Groups[1].Value, '<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>\s*(?:<([0-9A-Fa-f]*)>|\[([^\]]*)\])')) {
            if ($m.Groups[1].Value.Length -ge 4) { $bytes = 2 }
            $a = [Convert]::ToInt32($m.Groups[1].Value, 16)
            $b = [Convert]::ToInt32($m.Groups[2].Value, 16)
            if ($b - $a -gt 65535) { continue }
            if ($m.Groups[3].Success) {
                $dst = $m.Groups[3].Value
                if ($dst.Length -lt 4) { continue }
                $pre = $dst.Substring(0, $dst.Length - 4)
                $last = [Convert]::ToInt32($dst.Substring($dst.Length - 4), 16)
                for ($c = $a; $c -le $b; $c++) {
                    $map[$c] = (ConvertFrom-PdfUtf16 $pre) + [string][char](($last + $c - $a) -band 0xFFFF)
                }
            } else {
                $c = $a
                foreach ($h in [regex]::Matches($m.Groups[4].Value, '<([0-9A-Fa-f]*)>')) {
                    if ($c -gt $b) { break }
                    $map[$c] = ConvertFrom-PdfUtf16 $h.Groups[1].Value
                    $c++
                }
            }
        }
    }
    return @{ Map = $map; Bytes = $bytes }
}

function ConvertFrom-PdfUtf16([string]$hex) {
    $sb = New-Object System.Text.StringBuilder
    for ($i = 0; $i + 4 -le $hex.Length; $i += 4) { [void]$sb.Append([char][Convert]::ToInt32($hex.Substring($i, 4), 16)) }
    return $sb.ToString()
}

function Get-PdfFontInfo($doc, [string]$ref) {
    if ($doc.Fonts.ContainsKey($ref)) { return $doc.Fonts[$ref] }
    $fd = Get-PdfDictPart (Resolve-PdfValue $doc $ref)
    $info = @{ Bytes = 1; Map = $null; Enc = @{}; Widths = @{}; DW = 500.0; Space = $false; Cid = $null }
    $sub = [string](Read-PdfDictValue $fd '/Subtype')
    $tu = Read-PdfDictValue $fd '/ToUnicode'
    if ($tu -and $tu -match '^\s*\d+\s+\d+\s+R') {
        $body = Resolve-PdfValue $doc $tu
        if ($body) {
            $data = Get-PdfStreamBytes $doc $body
            if ($data) {
                $cm = Read-PdfCMap ($latin.GetString($data))
                $info.Map = $cm.Map
                $info.Bytes = $cm.Bytes
            }
        }
    }
    if ($sub -eq '/Type0') {
        $info.Bytes = 2
        $info.DW = 1000.0
        $encRef = Read-PdfDictValue $fd '/Encoding'
        if ($encRef -and $encRef -match '^\s*\d+\s+\d+\s+R') {
            # Embedded CMap: code length from its codespace, CIDs (for the widths) from its cid ranges
            $eb = Resolve-PdfValue $doc $encRef
            $ed = $null
            if ($eb) { $ed = Get-PdfStreamBytes $doc $eb }
            if ($ed) {
                $ct = $latin.GetString($ed)
                $csm = [regex]::Match($ct, 'begincodespacerange\s*<([0-9A-Fa-f]+)>')
                if ($csm.Success -and $csm.Groups[1].Value.Length -le 2) { $info.Bytes = 1 }
                $cidMap = @{}
                foreach ($blk in [regex]::Matches($ct, 'begincidrange(.*?)endcidrange', [System.Text.RegularExpressions.RegexOptions]::Singleline)) {
                    foreach ($m in [regex]::Matches($blk.Groups[1].Value, '<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>\s*(\d+)')) {
                        $a = [Convert]::ToInt32($m.Groups[1].Value, 16); $b = [Convert]::ToInt32($m.Groups[2].Value, 16)
                        if ($b - $a -gt 65535) { continue }
                        for ($c = $a; $c -le $b; $c++) { $cidMap[$c] = [int]$m.Groups[3].Value + $c - $a }
                    }
                }
                foreach ($blk in [regex]::Matches($ct, 'begincidchar(.*?)endcidchar', [System.Text.RegularExpressions.RegexOptions]::Singleline)) {
                    foreach ($m in [regex]::Matches($blk.Groups[1].Value, '<([0-9A-Fa-f]+)>\s*(\d+)')) { $cidMap[[Convert]::ToInt32($m.Groups[1].Value, 16)] = [int]$m.Groups[2].Value }
                }
                if ($cidMap.Count -gt 0) { $info.Cid = $cidMap }
            }
        }
        $desc = Resolve-PdfValue $doc (Read-PdfDictValue $fd '/DescendantFonts')
        $dref = [regex]::Match([string]$desc, '(\d+)\s+\d+\s+R')
        $cid = $null
        if ($dref.Success) { $cid = Get-PdfDictPart (Resolve-PdfValue $doc ($dref.Groups[1].Value + ' 0 R')) }
        elseif ($desc -match '<<') { $cid = $desc.Substring($desc.IndexOf('<<')) }
        if ($cid) {
            $dw = Read-PdfDictValue $cid '/DW'
            if ($dw -match '^[\d.]+$') { $info.DW = [double]::Parse($dw, $pdfInv) }
            $w = Resolve-PdfValue $doc (Read-PdfDictValue $cid '/W')
            if ($w) {
                $toks = Get-PdfTokens $w
                $i = 1
                while ($i -lt $toks.Count - 1) {
                    if ($toks[$i] -notmatch '^\d+$') { $i++; continue }
                    $c1 = [int]$toks[$i]
                    if ($toks[$i + 1] -eq '[') {
                        $j = $i + 2
                        $c = $c1
                        while ($j -lt $toks.Count -and $toks[$j] -ne ']') {
                            $info.Widths[$c] = [double]::Parse($toks[$j], $pdfInv); $c++; $j++
                        }
                        $i = $j + 1
                    } elseif ($i + 2 -lt $toks.Count -and $toks[$i + 1] -match '^\d+$') {
                        $c2 = [int]$toks[$i + 1]
                        $wv = [double]::Parse($toks[$i + 2], $pdfInv)
                        if ($c2 - $c1 -le 65535) { for ($c = $c1; $c -le $c2; $c++) { $info.Widths[$c] = $wv } }
                        $i += 3
                    } else { $i++ }
                }
            }
        }
    } else {
        $info.Bytes = 1
        $info.Space = $true
        $fc = Read-PdfDictValue $fd '/FirstChar'
        $wa = Resolve-PdfValue $doc (Read-PdfDictValue $fd '/Widths')
        if ($fc -match '^\d+$' -and $wa) {
            $c = [int]$fc
            foreach ($t in (Get-PdfTokens $wa)) {
                if ($t -match '^[+-]?[\d.]+$') { $info.Widths[$c] = [double]::Parse($t, $pdfInv); $c++ }
            }
        }
        $enc = Resolve-PdfValue $doc (Read-PdfDictValue $fd '/Encoding')
        if ($enc -and $enc.TrimStart().StartsWith('<<')) {
            $diff = Resolve-PdfValue $doc (Read-PdfDictValue (Get-PdfDictPart $enc) '/Differences')
            if ($diff) {
                $code = 0
                foreach ($t in (Get-PdfTokens $diff)) {
                    if ($t -match '^\d+$') { $code = [int]$t; continue }
                    if (-not $t.StartsWith('/')) { continue }
                    $g = $t.Substring(1)
                    $ch = $null
                    if ($PdfGlyphNames.ContainsKey($g)) { $ch = $PdfGlyphNames[$g] }
                    elseif ($g -cmatch '^[A-Za-z]$') { $ch = $g }
                    elseif ($g -match '^uni([0-9A-Fa-f]{4})') { $ch = [string][char][Convert]::ToInt32($matches[1], 16) }
                    if ($null -ne $ch) { $info.Enc[$code] = $ch }
                    $code++
                }
            }
        }
    }
    $doc.Fonts[$ref] = $info
    return $info
}

function Get-PdfResourceMap($doc, [string]$res, [string]$key) {
    # Name -> object reference for /Font or /XObject of a resource dictionary
    $out = @{}
    $r = Resolve-PdfValue $doc $res
    if (-not $r) { return $out }
    $sub = Resolve-PdfValue $doc (Read-PdfDictValue (Get-PdfDictPart $r) $key)
    if (-not $sub) { return $out }
    foreach ($m in [regex]::Matches($sub, '/([^\s/\[\]()<>{}%]+)\s+(\d+)\s+\d+\s+R')) { $out[$m.Groups[1].Value] = ($m.Groups[2].Value + ' 0 R') }
    return $out
}

function Mul-PdfMatrix([double[]]$m, [double[]]$n) {
    return [double[]]@(
        ($m[0] * $n[0] + $m[1] * $n[2]), ($m[0] * $n[1] + $m[1] * $n[3]),
        ($m[2] * $n[0] + $m[3] * $n[2]), ($m[2] * $n[1] + $m[3] * $n[3]),
        ($m[4] * $n[0] + $m[5] * $n[2] + $n[4]), ($m[4] * $n[1] + $m[5] * $n[3] + $n[5]))
}

$pdfNumP = '(?>[+-]?(?:\d+(?:\.\d*)?|\.\d+))'
$pdfStrP = '(?:\((?>[^()\\]+|\\.|\((?<d>)|\)(?<-d>))*(?(d)(?!))\)|<[0-9A-Fa-f\s]*>)'
$pdfNameP = '/(?<f>[^\s/\[\]()<>{}%]+)'
# Only the operators that place or show text, with their operands. Strings that are not shown are matched
# (last alternative) so nothing inside them is mistaken for an operator; all other content is skipped.
$pdfTextOpRx = [regex]::new(
    '(?<s>' + $pdfStrP + ')\s*(?<op>Tj|'')' +
    '|(?<n>' + $pdfNumP + '\s+' + $pdfNumP + ')\s+(?<s>' + $pdfStrP + ')\s*(?<op>")' +
    '|\[(?<a>(?>[^\[\]()]+|\((?>[^()\\]+|\\.|\((?<d>)|\)(?<-d>))*(?(d)(?!))\))*)\]\s*(?<op>TJ)' +
    '|(?<n>(?:' + $pdfNumP + '\s+){5}' + $pdfNumP + ')\s+(?<op>Tm|cm)(?![A-Za-z0-9*])' +
    '|(?<n>' + $pdfNumP + '\s+' + $pdfNumP + ')\s+(?<op>Td|TD)(?![A-Za-z0-9*])' +
    '|' + $pdfNameP + '\s+(?<n>' + $pdfNumP + ')\s+(?<op>Tf)(?![A-Za-z0-9*])' +
    '|(?<n>' + $pdfNumP + ')\s+(?<op>Tc|Tw|Tz|TL|Ts)(?![A-Za-z0-9*])' +
    '|' + $pdfNameP + '\s+(?<op>Do)(?![A-Za-z0-9*])' +
    '|(?<![A-Za-z0-9_/.])(?<op>BT|T\*|q|Q)(?![A-Za-z0-9_*])' +
    '|' + $pdfStrP,
    [System.Text.RegularExpressions.RegexOptions]::Singleline)
$pdfArrRx = [regex]::new($pdfStrP + '|' + $pdfNumP, [System.Text.RegularExpressions.RegexOptions]::Singleline)

function ConvertTo-PdfNumbers([string]$s) {
    $parts = $s.Split([char[]]" `t`r`n", [System.StringSplitOptions]::RemoveEmptyEntries)
    $out = New-Object 'double[]' $parts.Length
    for ($i = 0; $i -lt $parts.Length; $i++) { $out[$i] = [double]::Parse($parts[$i], $pdfInv) }
    return ,$out
}

function Read-PdfContent($doc, [string]$content, [string]$res, [double[]]$ctm, $chunks, [int]$page, [int]$depth) {
    if ($depth -gt 6) { return }
    $fonts = Get-PdfResourceMap $doc $res '/Font'
    $xobjs = $null
    $content = [regex]::Replace($content, '(?s)\bBI\b.*?\bID\b.*?\bEI\b', ' ')
    $gs = New-Object System.Collections.Generic.List[object]
    $tm = [double[]]@(1, 0, 0, 1, 0, 0); $tlm = $tm
    $font = $null; $fs = 0.0; $tc = 0.0; $tw = 0.0; $th = 1.0; $tl = 0.0; $rise = 0.0
    foreach ($m in $pdfTextOpRx.Matches($content)) {
        $op = $m.Groups['op'].Value
        if (-not $op) { continue }
        $show = $null
        if ($op -ceq 'TJ') {
            $show = New-Object System.Collections.Generic.List[object]
            foreach ($am in $pdfArrRx.Matches($m.Groups['a'].Value)) {
                $v = $am.Value
                if ($v[0] -eq '(' -or $v[0] -eq '<') { $show.Add($v) } else { $show.Add([double]::Parse($v, $pdfInv)) }
            }
        } elseif ($op -ceq 'Tj') {
            $show = @($m.Groups['s'].Value)
        } elseif ($op -ceq 'Tm') {
            $tlm = ConvertTo-PdfNumbers $m.Groups['n'].Value; $tm = $tlm
        } elseif ($op -ceq 'Td' -or $op -ceq 'TD') {
            $v = ConvertTo-PdfNumbers $m.Groups['n'].Value
            if ($op -ceq 'TD') { $tl = - $v[1] }
            $tlm = [double[]]@($tlm[0], $tlm[1], $tlm[2], $tlm[3], ($v[0] * $tlm[0] + $v[1] * $tlm[2] + $tlm[4]), ($v[0] * $tlm[1] + $v[1] * $tlm[3] + $tlm[5]))
            $tm = $tlm
        } elseif ($op -ceq 'Tf') {
            $fs = [double]::Parse($m.Groups['n'].Value, $pdfInv)
            $fn = $m.Groups['f'].Value
            $font = $null
            if ($fonts.ContainsKey($fn)) {
                $fr = $fonts[$fn]
                $font = $doc.Fonts[$fr]
                if ($null -eq $font) { $font = Get-PdfFontInfo $doc $fr }
            }
        } elseif ($op -ceq 'BT') {
            $tm = [double[]]@(1, 0, 0, 1, 0, 0); $tlm = $tm
        } elseif ($op -ceq 'q') {
            $gs.Add(@($ctm, $font, $fs, $tc, $tw, $th, $tl, $rise))
        } elseif ($op -ceq 'Q') {
            if ($gs.Count -gt 0) {
                $g = $gs[$gs.Count - 1]; $gs.RemoveAt($gs.Count - 1)
                $ctm = $g[0]; $font = $g[1]; $fs = $g[2]; $tc = $g[3]; $tw = $g[4]; $th = $g[5]; $tl = $g[6]; $rise = $g[7]
            }
        } elseif ($op -ceq 'cm') {
            $ctm = Mul-PdfMatrix (ConvertTo-PdfNumbers $m.Groups['n'].Value) $ctm
        } elseif ($op -ceq 'T*' -or $op -ceq "'" -or $op -ceq '"') {
            # move to the next line; ' and " then show a string
            if ($op -ceq '"') { $v = ConvertTo-PdfNumbers $m.Groups['n'].Value; $tw = $v[0]; $tc = $v[1] }
            $tlm = [double[]]@($tlm[0], $tlm[1], $tlm[2], $tlm[3], ((-$tl) * $tlm[2] + $tlm[4]), ((-$tl) * $tlm[3] + $tlm[5]))
            $tm = $tlm
            if ($op -cne 'T*') { $show = @($m.Groups['s'].Value) }
        } elseif ($op -ceq 'Do') {
            # text inside form XObjects
            if ($null -eq $xobjs) { $xobjs = Get-PdfResourceMap $doc $res '/XObject' }
            $xn = $m.Groups['f'].Value
            if ($xobjs.ContainsKey($xn)) {
                $xb = Resolve-PdfValue $doc $xobjs[$xn]
                $xd = Get-PdfDictPart $xb
                if ($xd -match '/Subtype\s*/Form') {
                    $data = Get-PdfStreamBytes $doc $xb
                    if ($data) {
                        $xm = [double[]]@(1, 0, 0, 1, 0, 0)
                        $mv = Read-PdfDictValue $xd '/Matrix'
                        if ($mv) {
                            $nums = ConvertTo-PdfNumbers ($mv -replace '[\[\]]', ' ')
                            if ($nums.Count -eq 6) { $xm = $nums }
                        }
                        $xr = Read-PdfDictValue $xd '/Resources'
                        if (-not $xr) { $xr = $res }
                        Read-PdfContent $doc ($latin.GetString($data)) $xr (Mul-PdfMatrix $xm $ctm) $chunks $page ($depth + 1)
                    }
                }
            }
        } else {
            $v = [double]::Parse($m.Groups['n'].Value, $pdfInv)
            if ($op -ceq 'Tc') { $tc = $v } elseif ($op -ceq 'Tw') { $tw = $v } elseif ($op -ceq 'Tz') { $th = $v / 100.0 } elseif ($op -ceq 'TL') { $tl = $v } else { $rise = $v }
        }
        if ($null -eq $show -or -not $font) { continue }

        $sb = New-Object System.Text.StringBuilder
        $start = $null
        $step = $font.Bytes
        $umap = $font.Map; $emap = $font.Enc; $wmap = $font.Widths; $cmap = $font.Cid; $dw = $font.DW
        $wordSp = 0.0
        if ($font.Space) { $wordSp = $tw * $th }
        foreach ($el in $show) {
            if ($el -is [double]) {
                # a wide kerning gap inside TJ ends the chunk, the line builder then puts a space there
                if ([math]::Abs($el) -gt 180 -and $sb.Length -gt 0) {
                    $chunks.Add(@{ P = $page; X = $start[0]; Y = $start[1]; X2 = ($tm[4] * $ctm[0] + $tm[5] * $ctm[2] + $ctm[4]); S = $start[2]; T = $sb.ToString(); Rot = $start[3] })
                    $sb = New-Object System.Text.StringBuilder
                    $start = $null
                }
                $adj = - $el / 1000.0 * $fs * $th
                $tm = [double[]]@($tm[0], $tm[1], $tm[2], $tm[3], ($tm[4] + $adj * $tm[0]), ($tm[5] + $adj * $tm[1]))
                continue
            }
            $str = ConvertFrom-PdfString ([string]$el)
            if ($str.Length -lt $step) { continue }
            if ($null -eq $start) {
                # text rendering matrix [fs*Th 0 0 fs 0 rise] x Tm x CTM: origin, font height, rotated or not
                $m0 = $tm[0] * $ctm[0] + $tm[1] * $ctm[2]; $m1 = $tm[0] * $ctm[1] + $tm[1] * $ctm[3]
                $m2 = $tm[2] * $ctm[0] + $tm[3] * $ctm[2]; $m3 = $tm[2] * $ctm[1] + $tm[3] * $ctm[3]
                $m4 = $tm[4] * $ctm[0] + $tm[5] * $ctm[2] + $ctm[4]; $m5 = $tm[4] * $ctm[1] + $tm[5] * $ctm[3] + $ctm[5]
                $start = @(($rise * $m2 + $m4), ($rise * $m3 + $m5), ([math]::Sqrt($m2 * $m2 + $m3 * $m3) * $fs), ([math]::Abs($m1) -gt [math]::Abs($m0)))
            }
            $wsum = 0.0; $cnt = 0; $spaces = 0
            for ($k = 0; $k + $step -le $str.Length; $k += $step) {
                $code = [int]$str[$k]
                if ($step -eq 2) { $code = $code * 256 + [int]$str[$k + 1] }
                if ($umap -and $umap.ContainsKey($code)) { [void]$sb.Append($umap[$code]) }
                elseif ($emap.ContainsKey($code)) { [void]$sb.Append($emap[$code]) }
                elseif ($step -eq 1) { [void]$sb.Append($pdfAnsi.GetString([byte[]]@($code))) }
                $cid = $code
                if ($cmap -and $cmap.ContainsKey($code)) { $cid = $cmap[$code] }
                if ($wmap.ContainsKey($cid)) { $wsum += $wmap[$cid] } else { $wsum += $dw }
                $cnt++
                if ($step -eq 1 -and $code -eq 32) { $spaces++ }
            }
            $adv = ($wsum / 1000.0 * $fs + $cnt * $tc) * $th + $spaces * $wordSp
            $tm = [double[]]@($tm[0], $tm[1], $tm[2], $tm[3], ($tm[4] + $adv * $tm[0]), ($tm[5] + $adv * $tm[1]))
        }
        if ($sb.Length -gt 0 -and $null -ne $start) {
            $endX = $tm[4] * $ctm[0] + $tm[5] * $ctm[2] + $ctm[4]
            $chunks.Add(@{ P = $page; X = $start[0]; Y = $start[1]; X2 = $endX; S = $start[2]; T = $sb.ToString(); Rot = $start[3] })
        }
    }
}

function Get-PdfLines([string]$path) {
    # Text of a PDF as lines in reading order (top to bottom, left to right)
    $doc = Open-PdfDoc $path
    $chunks = New-Object System.Collections.Generic.List[object]
    $pn = 0
    foreach ($pg in (Get-PdfPageList $doc)) {
        $pn++
        $cv = Read-PdfDictValue $pg.Dict '/Contents'
        if (-not $cv) { continue }
        $refs = @([regex]::Matches((Resolve-PdfValue $doc $cv), '(\d+)\s+\d+\s+R') | ForEach-Object { $_.Groups[1].Value + ' 0 R' })
        if ($cv -match '^\s*\d+\s+\d+\s+R\s*$' -and (Get-PdfDictPart (Resolve-PdfValue $doc $cv)).TrimStart().StartsWith('<<')) { $refs = @($cv) }
        $sb = New-Object System.Text.StringBuilder
        foreach ($r in $refs) {
            $body = Resolve-PdfValue $doc $r
            if (-not $body) { continue }
            $data = Get-PdfStreamBytes $doc $body
            if ($data) { [void]$sb.Append($latin.GetString($data)); [void]$sb.Append("`n") }
        }
        Read-PdfContent $doc $sb.ToString() $pg.Res ([double[]]@(1, 0, 0, 1, 0, 0)) $chunks $pn 0
    }

    # Rows: chunks sorted by page, then top to bottom; a chunk joins the row above when its baseline is close
    $items = New-Object System.Collections.Generic.List[object]
    $keys = New-Object System.Collections.Generic.List[double]
    foreach ($c in $chunks) {
        if ($c.Rot -or -not $c.T.Trim()) { continue }
        $items.Add($c)
        $keys.Add($c.P * 100000.0 - $c.Y)
    }
    $ia = $items.ToArray(); $ka = $keys.ToArray()
    [Array]::Sort([Array]$ka, [Array]$ia)

    $lines = New-Object System.Collections.Generic.List[string]
    $rows = New-Object System.Collections.Generic.List[object]
    $page = 0
    foreach ($c in $ia) {
        if ($c.P -ne $page) {
            if ($page -gt 0) { Add-PdfRows $rows $lines; $rows.Clear() }
            $page = $c.P
        }
        $row = $null
        if ($rows.Count -gt 0) {
            $last = $rows[$rows.Count - 1]
            $tol = [math]::Max(1.5, 0.4 * [math]::Min($c.S, $last.S))
            if ([math]::Abs($last.Y - $c.Y) -le $tol) { $row = $last }
        }
        if (-not $row) { $row = @{ Y = $c.Y; S = $c.S; Items = (New-Object System.Collections.Generic.List[object]) }; $rows.Add($row) }
        $row.Items.Add($c)
    }
    if ($page -gt 0) { Add-PdfRows $rows $lines }
    return ,$lines
}

function Add-PdfRows($rows, $lines) {
    # One text line per row, left to right; a wide gap becomes three spaces (column break)
    foreach ($row in $rows) {
        $ia = $row.Items.ToArray()
        $ka = [double[]]@($ia | ForEach-Object { $_.X })
        [Array]::Sort([Array]$ka, [Array]$ia)
        $sb = New-Object System.Text.StringBuilder
        $prev = $null
        foreach ($c in $ia) {
            if ($prev) {
                if ($c.T -eq $prev.T -and [math]::Abs($c.X - $prev.X) -lt 1.0) { continue }
                $gap = $c.X - $prev.X2
                $sz = [math]::Max(1.0, [math]::Min($c.S, $prev.S))
                $endsSpace = ($sb.Length -gt 0 -and $sb[$sb.Length - 1] -eq ' ')
                if ($gap -gt 1.2 * $sz) { [void]$sb.Append('   ') }
                elseif ($gap -gt 0.12 * $sz -and -not $endsSpace -and -not $c.T.StartsWith(' ')) { [void]$sb.Append(' ') }
            }
            [void]$sb.Append($c.T)
            $prev = $c
        }
        $line = ($sb.ToString() -replace '[\x00-\x08\x0B-\x1F]', '').TrimEnd()
        if ($line.Trim()) { $lines.Add($line) }
    }
    $lines.Add([string][char]12)
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
    $customerFull = ($cparts -join ' ')
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
        $lt = Remove-RegionCode $line
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

    return @{ Customer = $customer; CustomerFull = $customerFull; Month = $month; Year = $year; SiteText = $siteText; Country = $country; DestText = $destBlock; Location = $location }
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
    $destBlock = Remove-RegionCode $destBlock
    $found = ""
    foreach ($mm in [regex]::Matches($destBlock, '\b([A-Z]{2})\b')) {
        $cc = $mm.Groups[1].Value
        if ($IsoCountry.ContainsKey($cc)) { $found = $cc }
    }
    if ($found) { return $found }
    return (Get-CountryCode $destBlock)
}

$UnitsDe = [System.Globalization.CultureInfo]::GetCultureInfo('de-DE')

function ConvertFrom-DeNumber([string]$v) {
    $x = ($v -replace '\s', '') -replace '\.', '' -replace ',', '.'
    $d = 0.0
    if ([double]::TryParse($x, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$d)) { return $d }
    return $null
}

function Get-PackKey([string]$type) {
    $v = $type.Trim().ToUpper()
    if ($v -match '^(PAL|PALLET|PALLETS|PALETTE|PALETTEN|PL|EP|EPAL|EUR)$') { return 'Pallet' }
    if ($v -match '^(CT|CTN|CTNS|CARTON|CARTONS|KARTON|KARTONS)$') { return 'CT (carton)' }
    return $v
}

function Get-ShipmentUnits([string]$path) {
    try { $t = Get-PdfText $path } catch { return $null }
    $toks = New-Object System.Collections.Generic.List[string]
    foreach ($m in [regex]::Matches($t, '\(((?:[^()\\]|\\.)*)\)\s*Tj')) {
        $toks.Add(($m.Groups[1].Value -replace '\\\(', '(' -replace '\\\)', ')').Trim())
    }

    $packAt = -1
    for ($i = 0; $i -lt $toks.Count; $i++) {
        if ($toks[$i] -match '^Packages No\.?$') { $packAt = $i; break }
    }
    if ($packAt -lt 0) { return $null }

    $kgRx = '^(\d[\d.]*(?:,\d+)?)\s*KG$'
    $g = -1
    for ($i = $packAt + 1; $i -lt $toks.Count - 1; $i++) {
        if ($toks[$i] -match $kgRx -and $toks[$i + 1] -match $kgRx) { $g = $i; break }
    }
    if ($g -lt 0) { return $null }

    $gross = ConvertFrom-DeNumber ($toks[$g] -replace '\s*KG$', '')
    $net = ConvertFrom-DeNumber ($toks[$g + 1] -replace '\s*KG$', '')
    if ($null -eq $gross -or $null -eq $net -or $net -gt $gross) { $gross = $null; $net = $null }

    $typeRx = '(?i)^(pallets?|palette|paletten|pal|pl|ep|epal|eur|ct|ctn|ctns|cs|cartons?|kartons?|box|boxes|colli|pkg|parcels?)$'
    $typeTok = $null
    if ($toks[$g - 1] -match $typeRx) { $typeTok = $toks[$g - 1] }

    $count = $null
    if ($g + 2 -lt $toks.Count -and $toks[$g + 2] -match '^\d{1,3}(?:\.\d{3})*,\d{2}$') {
        $count = ConvertFrom-DeNumber $toks[$g + 2]
    }
    if ($null -eq $typeTok) { $count = $null }

    if ($null -eq $count -and $null -eq $gross) { return $null }
    return @{ Type = $typeTok; Count = $count; Net = $net; Gross = $gross }
}

function Format-Units($members) {
    $byType = [ordered]@{}
    $net = 0.0; $gross = 0.0; $hasNet = $false; $hasGross = $false
    foreach ($m in $members) {
        $u = Get-ShipmentUnits $m.Src.FullName
        if (-not $u) { continue }
        if ($null -ne $u.Count) {
            $key = 'units'
            if ($u.Type) { $key = Get-PackKey $u.Type }
            if (-not $byType.Contains($key)) { $byType[$key] = 0.0 }
            $byType[$key] += $u.Count
        }
        if ($null -ne $u.Net) { $net += $u.Net; $hasNet = $true }
        if ($null -ne $u.Gross) { $gross += $u.Gross; $hasGross = $true }
    }
    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($k in $byType.Keys) { $parts.Add($byType[$k].ToString('0.##', $UnitsDe) + ' ' + $k) }
    $out = @{ Units = ($parts -join ' + '); Weight = '' }
    $w = New-Object System.Collections.Generic.List[string]
    if ($hasNet) { $w.Add('Net ' + $net.ToString('#,##0.##', $UnitsDe) + ' kg') }
    if ($hasGross) { $w.Add('Gross ' + $gross.ToString('#,##0.##', $UnitsDe) + ' kg') }
    $out.Weight = ($w -join '   ')
    return $out
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

function Score-Customer([hashtable]$info, [string]$folder) {
    $sc = Score-Name $info.Customer $folder
    if ($sc -ge 40) { return $sc }
    $full = $info.CustomerFull
    if (-not $full) { return $sc }
    $words = @((Normalize-Name $full) -split ' ' | Where-Object { $_.Length -ge 3 })
    $short = @((Normalize-Name $info.Customer) -split ' ')
    $nf = Normalize-Name $folder
    if (-not $nf -or $words.Count -eq 0) { return $sc }
    $fTokens = @($nf -split ' ' | Where-Object { $_.Length -ge 3 })
    if ($fTokens.Count -eq 0) { return $sc }
    for ($i = 0; $i -lt $words.Count; $i++) {
        if ($short -contains $words[$i]) { continue }
        foreach ($t in $fTokens) {
            if ($t -eq $words[$i]) {
                $late = 39 - $i
                if ($late -lt 20) { $late = 20 }
                if ($late -gt $sc) { return $late }
                return $sc
            }
        }
    }
    return $sc
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
        $sc = (Score-Customer $info $ud.Name) + (Score-FolderSite $ud.Name $site) * 15
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

function Find-MonthFolderDeep([string]$container, [int]$month, [string]$year, [int]$maxDepth) {
    if (-not $container -or -not (Test-Path -LiteralPath $container)) { return "" }
    $best = ""
    $queue = New-Object System.Collections.Generic.List[object]
    $queue.Add(@{ Path = $container; Depth = 0; Ctx = "" })
    $i = 0
    while ($i -lt $queue.Count) {
        $node = $queue[$i]
        $i++
        foreach ($d in @(Get-ChildItem -LiteralPath $node.Path -Directory -ErrorAction SilentlyContinue)) {
            $mv = Test-FolderMonth $d.Name $month $year
            if ($mv -ge 3) { return $d.FullName }
            if ($mv -eq 2 -and $node.Ctx -eq $year -and -not $best) { $best = $d.FullName }
            if (($node.Depth + 1) -lt $maxDepth) {
                $fy = Get-FolderYear $d.Name
                if ($fy -and (Get-FolderMonth $d.Name) -eq 0) {
                    $queue.Add(@{ Path = $d.FullName; Depth = $node.Depth + 1; Ctx = $fy })
                }
            }
        }
    }
    return $best
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
            if ((Score-Customer $info $c.Name) -ge 20) { $cu = 1 }
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
        Move-Item -LiteralPath $src -Destination $dest -ErrorAction Stop
        return $true
    } catch {
        Write-Host ("  Could not move " + [System.IO.Path]::GetFileName($src) + ": " + $_.Exception.Message) -ForegroundColor Red
        Write-Host "  Close it in the PDF viewer or preview pane, then run Move again." -ForegroundColor DarkGray
        return $false
    }
}

function Read-FolderName([string]$prompt, [string]$default) {
    while ($true) {
        $n = Read-Host $prompt
        if ($null -eq $n) { $n = '' }
        $n = $n.Trim()
        if ($n -eq 'x' -or $n -eq 'X') { return '' }
        if (-not $n) {
            if ($default) { return $default }
            Write-Host "  A name is required. Type x to cancel." -ForegroundColor Yellow
            continue
        }
        if ($n -match '[\\/:*?"<>|]') {
            Write-Host '  Not allowed in a folder name: \ / : * ? " < > |' -ForegroundColor Yellow
            continue
        }
        return $n
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
        if ($info.Units) { $entries.Add(@{ Text = ("  Units   : " + $info.Units); Header = $true }) }
        if ($info.Weight) { $entries.Add(@{ Text = ("  Weight  : " + $info.Weight); Header = $true }) }
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
        $foundMonth = ""
        if (-not $needYear) {
            if ((Test-FolderMonth (Split-Path $cur -Leaf) $month $year) -ge 2) {
                $monthExists = $true
            } else {
                $foundMonth = Find-MonthFolderDeep $effContainer $month $year 2
                if ($foundMonth) { $monthExists = $true }
            }
        }
        $createEntry = @{ Text = ("[ + Create folder: " + $suggest + " ]" + $createHint); Header = $false; Act = "CREATE" }

        if ($foundMonth) {
            $base = $effContainer.TrimEnd('\')
            $rel = $foundMonth
            if ($foundMonth.StartsWith($base, [System.StringComparison]::OrdinalIgnoreCase)) {
                $rel = $foundMonth.Substring($base.Length).TrimStart('\')
            }
            $entries.Add(@{ Text = ("[ -> Open existing: " + $rel + " ]"); Header = $false; Act = ("DIR|" + $foundMonth) })
        }
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
            $name = Read-FolderName ("  Folder name (Enter = " + $suggest + ", x = cancel)") $suggest
            if (-not $name) { continue }
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
            $name = Read-FolderName "  New folder name (required, x = cancel)" ''
            if ($name) {
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
    $result = 0
    if (-not (Test-Path -LiteralPath $path)) {
        Write-Host ("  File no longer exists: " + $name) -ForegroundColor Red
    } else {
        $target = Join-Path $dest $name
        if (Test-Path -LiteralPath $target) {
            Write-Host ("  Target exists, skipped: " + $name) -ForegroundColor DarkYellow
        } elseif (Move-FileSafe $path $target) {
            Write-Host ("  Moved " + $name + " -> " + $dest) -ForegroundColor Green
            $result = 1
        }
    }

    Write-Host ""
    Write-Host "   Press any key to continue..." -ForegroundColor DarkGray
    [void][Console]::ReadKey($true)
    return $result
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

    Write-Host ""
    Write-Host "   Press any key to continue..." -ForegroundColor DarkGray
    [void][Console]::ReadKey($true)
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
            $moved += $did
        } elseif ($e.Act -eq 'WP') {
            $did = Move-WpBundle $e.Title $e.Paths
            $moved += $did
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
            $fu = Format-Units $g.Members
            $info.Units = $fu.Units
            $info.Weight = $fu.Weight
            $start = Resolve-StartFolder $script:__root $info
            $res = Move-PairInteractive $script:__root $start $title $info $g.Paths
            if ($res -eq "MOVED") {
                $did = $g.Paths.Count
                $moved += $did
                Write-Host ""
                Write-Host "   Press any key to continue..." -ForegroundColor DarkGray
                [void][Console]::ReadKey($true)
            }
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

$CooWorkbookName = 'COO calculation.xlsx'
$CooFormDirName = 'Coo IHK Formulare'
$CooItalyDirName = 'Coo Italy'
$CooCertRx = '\bC\d{2}[0-9A-Z]{2}\d{7}\b'
$CooHistoryFile = '_coo_history.txt'
$CooCatalogFile = '_coo_catalog.json'

function ConvertFrom-CooNumber([string]$v) {
    # "1.688,40", "2170,80", "1608", "4888.00" -> double
    if (-not $v) { return $null }
    $x = $v -replace '\s', ''
    if ($x -match ',' -and $x -match '\.') { $x = $x -replace '\.', '' -replace ',', '.' }
    elseif ($x -match ',') { $x = $x -replace ',', '.' }
    elseif ($x -match '^\d{1,3}(\.\d{3})+$') { $x = $x -replace '\.', '' }
    $d = 0.0
    if ([double]::TryParse($x, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$d)) { return $d }
    return $null
}

function ConvertFrom-CooQty([string]$v) {
    # EA quantities are whole numbers with "." as thousands separator: "25.200" -> 25200
    $x = ($v -replace '\s', '') -replace ',\d*$', '' -replace '\.', ''
    if ($x -match '^\d+$') { return [double]$x }
    return $null
}

function Split-CooCells([string]$line) {
    return ,@($line.Trim() -split '\s{3,}' | Where-Object { $_ })
}

function Get-CooInvoice([string[]]$lines) {
    $text = $lines -join "`n"
    $num = First $text 'PSINV\d{2}-\d{5}'
    if (-not $num -or $text -notmatch '(?i)invoice') { return $null }
    $inv = @{
        Number = $num; Date = ''; Customer = ''; OriginText = ''
        Items = (New-Object System.Collections.Generic.List[object])
        Packages = $null; Net = $null; Gross = $null
    }
    $dm = [regex]::Match($text, '\b(\d{2}/\d{2}/\d{4})\b')
    if ($dm.Success) { $inv.Date = $dm.Groups[1].Value }
    $om = [regex]::Match($text, '(?i)The goods are of\s+(.+?)\s+origin')
    if ($om.Success) { $inv.OriginText = $om.Groups[1].Value.Trim() }
    for ($i = 0; $i -lt $lines.Count - 1 -and -not $inv.Customer; $i++) {
        if ($lines[$i] -notmatch 'Delivery Address\s*$') { continue }
        for ($j = $i + 1; $j -lt [math]::Min($lines.Count, $i + 4); $j++) {
            $cells = Split-CooCells $lines[$j]
            if ($cells.Count -eq 0) { continue }
            $last = $cells[$cells.Count - 1]
            if ($last -notmatch '^(SWIFT|IBAN|Customer|AXIUM|\d)') { $inv.Customer = $last; break }
        }
    }

    $itemRx = '^\s*(?<item>\d{5,10})\s+(?:\d{5,10}\s+)?(?<desc>.*?)\s+(?<uom>[A-Z]{2,4})\s+(?<qty>\d{1,3}(?:\.\d{3})+|\d+)\s+(?<hs>\d{6,10})\s+(?<org>[A-Z]{2})(?:\s|$)'
    $cur = $null
    foreach ($ln in $lines) {
        if ($ln -eq [string][char]12) { continue }
        $m = [regex]::Match($ln, $itemRx)
        if ($m.Success) {
            $cur = @{
                Item = $m.Groups['item'].Value; Desc = $m.Groups['desc'].Value.Trim(); Uom = $m.Groups['uom'].Value
                Qty = (ConvertFrom-CooQty $m.Groups['qty'].Value); Hs = $m.Groups['hs'].Value; Origin = $m.Groups['org'].Value
                Lots = (New-Object System.Collections.Generic.List[object]); Text = (New-Object System.Text.StringBuilder)
            }
            $inv.Items.Add($cur)
            continue
        }
        if (-not $cur) { continue }
        if ($ln -match '^\s*Carrier\b|Total packages') { $cur = $null; continue }
        [void]$cur.Text.Append(' ')
        [void]$cur.Text.Append($ln)
    }
    foreach ($it in $inv.Items) {
        $t = $it.Text.ToString()
        foreach ($lm in [regex]::Matches($t, 'Lot No\.?\s*:?\s*(?<lot>[A-Z]?\d{6,8})\s*(?:(?:EA|PCS|PZ)\s*-?|-)\s*(?<qty>\d{1,3}(?:\.\d{3})+|\d+)')) {
            $it.Lots.Add(@{ Lot = $lm.Groups['lot'].Value; Qty = (ConvertFrom-CooQty $lm.Groups['qty'].Value) })
        }
        $first = (Split-CooCells $t)
        if (-not $it.Desc -and $first.Count -gt 0) { $it.Desc = $first[0] }
        $it.Remove('Text')
    }

    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -notmatch 'Total packages') { continue }
        for ($j = $i + 1; $j -lt [math]::Min($lines.Count, $i + 5); $j++) {
            $nums = @([regex]::Matches($lines[$j], '(?<![\d.,])\d{1,3}(?:[.,]\d{3})*[.,]\d{1,2}(?![\d.,])') | ForEach-Object { ConvertFrom-CooNumber $_.Value })
            if ($nums.Count -ge 3) {
                $inv.Packages = $nums[0]; $inv.Net = $nums[1]; $inv.Gross = $nums[2]
                break
            }
        }
        if ($null -ne $inv.Packages) { break }
    }
    return $inv
}

function Get-CooItalianCert([string[]]$lines) {
    # Italian chamber "Certificato di origine": page 1 is the ORIGINALE, page 2 the same data as COPIA
    $page = New-Object System.Collections.Generic.List[string]
    foreach ($ln in $lines) {
        if ($ln -eq [string][char]12) { if ($page.Count -gt 0) { break } else { continue } }
        $page.Add((($ln -replace '(?:<\s*){2,}<?', ' ') -replace '\s+$', ''))
    }
    $text = $page -join "`n"
    if ($text -notmatch '(?i)certifica') { return $null }
    $num = First $text $CooCertRx
    if (-not $num) { return $null }
    $c = @{ Number = $num; Origin = ''; Doc = ''; DocDate = ''; Pallets = $null; Net = $null; Gross = $null; Swapped = $false; Product = ''; Issued = ''; Lots = (New-Object System.Collections.Generic.List[object]) }

    for ($i = 0; $i -lt $page.Count; $i++) {
        if ($page[$i] -notmatch '(?i)Country of origin') { continue }
        for ($j = $i + 1; $j -lt [math]::Min($page.Count, $i + 9) -and -not $c.Origin; $j++) {
            foreach ($cell in (Split-CooCells $page[$j])) {
                if ($cell -cmatch '^(EGYPT|EGITTO|ITALY|ITALIA|[A-Z]{4,}(?: [A-Z]{2,})*)(?:\s*\(.*\))?$' -and $cell -notmatch '^(GERMANY|ORIGINALE|COPIA|PROMEDIA)\b') {
                    $c.Origin = $matches[1]
                    break
                }
            }
        }
        break
    }
    if (-not $c.Origin -and $text -match '\bEGYPT\b') { $c.Origin = 'EGYPT' }

    $dm = [regex]::Match($text, '(PSINV\d{2}-V-\d{5})(?:\s*ON)?(?:\s*(\d{2}/\d{2}/\d{4}))?')
    if ($dm.Success) { $c.Doc = $dm.Groups[1].Value; $c.DocDate = $dm.Groups[2].Value }
    $dd = [regex]::Match($text, 'Document Date:?\s*(\d{2}/\d{2}/\d{4})')
    if ($dd.Success) { $c.DocDate = $dd.Groups[1].Value }
    $pm = [regex]::Match($text, '(?i)NUMBER OF PALLETS:?\s*(\d+)')
    if (-not $pm.Success) { $pm = [regex]::Match($text, '(?i)\b([\dO]+)\s*PALLETS\b') }
    if ($pm.Success) { $c.Pallets = [double](($pm.Groups[1].Value -replace 'O', '0')) }
    $nm = [regex]::Match($text, '(?i)Net weight\s*(?:KG)?\s*:?\s*(\d[\d.,]*)')
    $gm = [regex]::Match($text, '(?i)Gross weight\s*(?:KG)?\s*:?\s*(\d[\d.,]*)')
    if ($nm.Success) { $c.Net = ConvertFrom-CooNumber ($nm.Groups[1].Value.TrimEnd('.', ',')) }
    if ($gm.Success) { $c.Gross = ConvertFrom-CooNumber ($gm.Groups[1].Value.TrimEnd('.', ',')) }
    if ($null -ne $c.Net -and $null -ne $c.Gross -and $c.Net -gt $c.Gross) {
        $t = $c.Net; $c.Net = $c.Gross; $c.Gross = $t; $c.Swapped = $true
    }
    $prm = [regex]::Match($text, '(?m)^\s*(F\d{5}-\d{2}\s+.+?)(?:\s{3,}|$)')
    if ($prm.Success) { $c.Product = $prm.Groups[1].Value.Trim() }
    $c.Products = @([regex]::Matches($text, '\bF\d{5}-\d{2}\b') | ForEach-Object { $_.Value } | Select-Object -Unique)
    $im = [regex]::Match($text, '(?m)\b([A-Z][a-z]+),\s*(\d{2}/\d{2}/\d{4})')
    if ($im.Success) { $c.Issued = $im.Groups[2].Value }

    $last = $null
    foreach ($m in [regex]::Matches($text, 'Lot No\.?\s*:?[ \t]*(?<lot>P\d{7}|\d{8})?(?:\s*-\s*PZ\s*-\s*(?<q2>\d[\d.]*))?|Q\.\s?ty\s*:?[ \t]*(?<qty>\d{1,3}(?:\.\d{3})+|\d+)?')) {
        if ($m.Value -match '^Lot') {
            if (-not $m.Groups['lot'].Success) { continue }
            $lot = $m.Groups['lot'].Value
            if (@($c.Lots | Where-Object { $_.Lot -eq $lot }).Count -gt 0) { $last = $null; continue }
            $last = @{ Lot = $lot; Qty = $null }
            if ($m.Groups['q2'].Success) { $last.Qty = ConvertFrom-CooQty $m.Groups['q2'].Value }
            $c.Lots.Add($last)
        } elseif ($m.Groups['qty'].Success -and $last -and $null -eq $last.Qty) {
            $last.Qty = ConvertFrom-CooQty $m.Groups['qty'].Value
        }
    }
    return $c
}

function Get-CooShares([double]$total, [double[]]$weights, [int]$decimals) {
    # Splits total in proportion to weights, rounded; the rounding rest goes to the largest share so the sum stays exact
    $sum = 0.0
    foreach ($w in $weights) { $sum += $w }
    $out = New-Object 'double[]' $weights.Count
    if ($sum -le 0) { return ,$out }
    $acc = 0.0; $big = 0
    for ($i = 0; $i -lt $weights.Count; $i++) {
        $out[$i] = [math]::Round($total * $weights[$i] / $sum, $decimals)
        $acc += $out[$i]
        if ($weights[$i] -gt $weights[$big]) { $big = $i }
    }
    $out[$big] = [math]::Round($out[$big] + ($total - $acc), $decimals)
    return ,$out
}

function Get-CooItalyRows($cert) {
    # Rows for sheet "COO Italy": pallets per lot by rule of three, weights by quantity share
    $rows = New-Object System.Collections.Generic.List[object]
    $lots = $cert.Lots
    if ($lots.Count -eq 0 -or $null -eq $cert.Net -or $null -eq $cert.Gross -or -not $cert.Pallets) { return $null }
    $qty = New-Object 'double[]' $lots.Count
    for ($i = 0; $i -lt $lots.Count; $i++) {
        if (-not $lots[$i].Qty) {
            if ($lots.Count -gt 1) { return $null }
            $qty[$i] = 1.0
        } else { $qty[$i] = $lots[$i].Qty }
    }
    $pal = Get-CooShares $cert.Pallets $qty 3
    $net = Get-CooShares $cert.Net $qty 2
    $gross = Get-CooShares $cert.Gross $qty 2
    for ($i = 0; $i -lt $lots.Count; $i++) {
        $rows.Add(@{ Cert = $cert.Number; Doc = $cert.Doc; Lot = $lots[$i].Lot; Pal = $pal[$i]; Net = $net[$i]; Gross = $gross[$i] })
    }
    return ,$rows
}

function Get-CooCertQty($cert) {
    # Total EA of a certificate, $null if a lot has no quantity
    $q = 0.0
    foreach ($l in $cert.Lots) { if (-not $l.Qty) { return $null }; $q += $l.Qty }
    if ($q -le 0) { return $null }
    return $q
}

function Get-CooHistory([string]$cooDir) {
    # EA, pallets and weights of every Italian certificate in "Coo Italy", the reference for Test-CooCert.
    # Reading all PDFs takes about a minute, so the values are kept in _coo_history.txt and only new files are read.
    $path = Join-Path $AppDir $CooHistoryFile
    $ci = [System.Globalization.CultureInfo]::InvariantCulture
    $old = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([StringComparer]::OrdinalIgnoreCase)
    if (Test-Path -LiteralPath $path) {
        try {
            foreach ($ln in [System.IO.File]::ReadAllLines($path)) {
                $i = $ln.IndexOf('|')
                if ($i -gt 0) { $old[$ln.Substring(0, $i)] = $ln.Substring($i + 1) }
            }
        } catch { }
    }
    $files = @(Get-ChildItem -LiteralPath (Join-Path $cooDir $CooItalyDirName) -Filter '*.pdf' -ErrorAction SilentlyContinue)
    $keyOf = { param($f) $f.Name + '*' + $f.Length + '*' + $f.LastWriteTimeUtc.Ticks }
    $todo = @($files | Where-Object { -not $old.ContainsKey((& $keyOf $_)) }).Count
    $lines = New-Object System.Collections.Generic.List[string]
    $certs = New-Object System.Collections.Generic.List[object]
    $seen = @{}
    $spin = $null
    if ($todo -gt 0) { $spin = Start-Spin ("reading " + $todo + " Italian certificate(s) in '" + $CooItalyDirName + "' for the plausibility check...") }
    try {
        foreach ($f in $files) {
            $key = & $keyOf $f
            if ($old.ContainsKey($key)) { $val = $old[$key] }
            else {
                $val = ''
                try {
                    $c = Get-CooItalianCert (Get-PdfLines $f.FullName)
                    $q = $null
                    if ($c) { $q = Get-CooCertQty $c }
                    if ($c -and $q -and $c.Pallets -and $c.Net -and $c.Gross) {
                        $val = @($c.Number, ($c.Products -join ','), $q.ToString($ci), $c.Pallets.ToString($ci), $c.Net.ToString($ci), $c.Gross.ToString($ci)) -join '|'
                    }
                } catch { }
            }
            $lines.Add($key + '|' + $val)
            $p = $val.Split('|')
            if ($p.Count -lt 6 -or $seen.ContainsKey($p[0])) { continue }
            $seen[$p[0]] = $true
            $certs.Add(@{ Number = $p[0]; Products = @($p[1].Split(',') | Where-Object { $_ }); Qty = [double]::Parse($p[2], $ci); Pallets = [double]::Parse($p[3], $ci); Net = [double]::Parse($p[4], $ci); Gross = [double]::Parse($p[5], $ci) })
        }
    } finally { Stop-Spin $spin }
    if ($todo -gt 0 -or $lines.Count -ne $old.Count) {
        try { [System.IO.File]::WriteAllLines($path, $lines.ToArray()) } catch { }
    }
    return ,$certs
}

function Get-CooMedian([double[]]$v) {
    [Array]::Sort($v)
    $n = $v.Count
    if ($n % 2 -eq 1) { return $v[($n - 1) / 2] }
    return ($v[$n / 2 - 1] + $v[$n / 2]) / 2
}

function Get-CooCatalog {
    # EA per pallet by article number, from the catalog backup of PROMEDIA Control (Katalog_Backup_*.json).
    # The newest backup in the Downloads or program folder is kept as _coo_catalog.json, so it may be deleted there.
    $keep = Join-Path $AppDir $CooCatalogFile
    $new = @(Get-ChildItem -LiteralPath @($WorkDir, $AppDir) -Filter 'Katalog_Backup_*.json' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
    if ($new.Count -gt 0 -and (-not (Test-Path -LiteralPath $keep) -or $new[0].LastWriteTime -gt (Get-Item -LiteralPath $keep).LastWriteTime)) {
        try { Copy-Item -LiteralPath $new[0].FullName -Destination $keep -Force -ErrorAction Stop } catch { }
    }
    $cat = @{}
    if (-not (Test-Path -LiteralPath $keep)) { return $cat }
    try {
        $j = [System.IO.File]::ReadAllText($keep, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
        foreach ($e in @($j.catalog)) {
            if ($e.crossRef -and $e.pallet -gt 0) { $cat[([string]$e.crossRef).Trim()] = [double]$e.pallet }
        }
    } catch { }
    return $cat
}

function Get-CooPalletsByLot($inv, $catalog) {
    # EA per pallet of every invoice lot, through its article number in the catalog
    $res = @{}
    foreach ($it in $inv.Items) {
        $p = $catalog[[string]$it.Item]
        if (-not $p) { continue }
        foreach ($l in $it.Lots) { $res[[string]$l.Lot] = $p }
    }
    return $res
}

function Test-CooCert($cert, $history, $palByLot) {
    # Checks an Italian certificate: pallets for its EA by the catalog (else by the earlier certificates of the article),
    # net and gross weight per EA by the earlier certificates. The Italian chamber sometimes issues wrong pallet counts
    # or weights, they must not reach the IHK form.
    $res = @{ Ref = 0; Product = ''; PalBy = ''; Problems = (New-Object System.Collections.Generic.List[string]) }
    $q = Get-CooCertQty $cert
    if (@($cert.Products).Count -ne 1 -or -not $q -or -not $cert.Pallets -or -not $cert.Net -or -not $cert.Gross) { return $res }
    $res.Product = $cert.Products[0]
    $same = @($history | Where-Object { $_.Number -ne $cert.Number -and $_.Products.Count -eq 1 -and $_.Products[0] -eq $res.Product })
    $res.Ref = $same.Count
    $ea = $q.ToString('#,##0', $UnitsDe) + " EA"

    # one article per certificate: a lot of it on the invoice gives the pallet size for all its lots
    $catPal = $null
    foreach ($l in $cert.Lots) { if ($palByLot -and $palByLot[[string]$l.Lot]) { $catPal = $palByLot[[string]$l.Lot]; break } }
    $eaPal = $null
    if ($catPal) { $eaPal = $catPal; $res.PalBy = 'catalog' }
    elseif ($same.Count -ge 3) { $eaPal = Get-CooMedian ([double[]]@($same | ForEach-Object { $_.Qty / $_.Pallets })); $res.PalBy = 'earlier certificates' }
    if ($eaPal) {
        $expPal = [math]::Ceiling($q / $eaPal - 0.01)
        if ($cert.Pallets -ne $expPal) {
            $res.Problems.Add("pallets " + (Format-CooPal $cert.Pallets) + ", expected " + $expPal + "  (" + $ea + ", " + $eaPal.ToString('#,##0', $UnitsDe) + " EA per pallet by the " + $res.PalBy + ")")
        }
    }

    if ($same.Count -lt 3) { return $res }
    $netEa = Get-CooMedian ([double[]]@($same | ForEach-Object { $_.Net / $_.Qty }))
    $grossEa = Get-CooMedian ([double[]]@($same | ForEach-Object { $_.Gross / $_.Qty }))
    $expNet = [math]::Round($q * $netEa, 2)
    $expGross = [math]::Round($q * $grossEa, 2)
    if ([math]::Abs($cert.Net / $expNet - 1) -gt 0.01) {
        $res.Problems.Add("net " + (Format-CooKg $cert.Net) + " kg, expected " + (Format-CooKg $expNet) + " kg  (" + $ea + " x " + $netEa.ToString('0.0000', $UnitsDe) + " kg)")
    }
    if ([math]::Abs($cert.Gross / $expGross - 1) -gt 0.03) {
        $res.Problems.Add("gross " + (Format-CooKg $cert.Gross) + " kg, expected " + (Format-CooKg $expGross) + " kg  (" + $ea + " x " + $grossEa.ToString('0.0000', $UnitsDe) + " kg)")
    }
    return $res
}

function Get-CooEgyptLots($inv) {
    $lots = New-Object System.Collections.Generic.List[object]
    foreach ($it in $inv.Items) {
        if ($it.Origin -ne 'EG') { continue }
        foreach ($l in $it.Lots) { $lots.Add($l) }
    }
    return ,$lots
}

function Get-CooEgyptTotals($inv, $certs) {
    # Pallets and weights of the Egyptian goods. A mixed invoice only has totals for all goods, then the
    # Italian certificates give a suggestion (EA per pallet and kg per EA of each lot); $null if they cannot
    if (@($inv.Items | Where-Object { $_.Origin -ne 'EG' }).Count -eq 0) {
        if ($inv.Packages -and $null -ne $inv.Net -and $null -ne $inv.Gross) {
            return @{ Packages = $inv.Packages; Net = $inv.Net; Gross = $inv.Gross; FromInvoice = $true }
        }
        return $null
    }
    $tot = @{ Packages = 0.0; Net = 0.0; Gross = 0.0; FromInvoice = $false }
    foreach ($l in (Get-CooEgyptLots $inv)) {
        $src = $null
        foreach ($c in $certs) {
            $tq = 0.0
            foreach ($x in $c.Lots) { if ($x.Qty) { $tq += $x.Qty } }
            if ($tq -le 0 -or -not $c.Pallets -or $null -eq $c.Net) { continue }
            foreach ($x in $c.Lots) { if ($x.Lot -eq $l.Lot) { $src = @{ C = $c; Q = $tq } } }
            if ($src) { break }
        }
        if (-not $src) { return $null }
        $tot.Packages += $l.Qty * $src.C.Pallets / $src.Q
        $tot.Net += $l.Qty * $src.C.Net / $src.Q
        $tot.Gross += $l.Qty * $src.C.Gross / $src.Q
    }
    $tot.Packages = [math]::Round($tot.Packages, 2)
    $tot.Net = [math]::Round($tot.Net, 2)
    $tot.Gross = [math]::Round($tot.Gross, 2)
    return $tot
}

function Get-CooGermanRows($inv, $totals) {
    # Rows for sheet "COO DE": the Egyptian lots of the invoice, pallets by rule of three, weights by EA share
    $res = @{ Rows = (New-Object System.Collections.Generic.List[object]); Notes = (New-Object System.Collections.Generic.List[string]); EaPerPal = $null }
    foreach ($it in $inv.Items) {
        if ($it.Origin -ne 'EG') { continue }
        $sum = 0.0
        foreach ($l in $it.Lots) { $sum += $l.Qty }
        if ($it.Lots.Count -eq 0) { $res.Notes.Add("Item " + $it.Item + ": no lot numbers found on the invoice") }
        elseif ($sum -ne $it.Qty) { $res.Notes.Add("Item " + $it.Item + ": the lots add up to " + $sum + " EA, the invoice line says " + $it.Qty + " EA") }
    }
    $lots = Get-CooEgyptLots $inv
    if ($lots.Count -eq 0 -or -not $totals -or -not $totals.Packages) { return $res }
    $ea = New-Object 'double[]' $lots.Count
    $totalEa = 0.0
    for ($i = 0; $i -lt $lots.Count; $i++) { $ea[$i] = $lots[$i].Qty; $totalEa += $lots[$i].Qty }
    $res.EaPerPal = $totalEa / $totals.Packages
    $pal = Get-CooShares $totals.Packages $ea 3
    $net = Get-CooShares ([math]::Min($totals.Net, $totals.Gross)) $ea 2
    $gross = Get-CooShares ([math]::Max($totals.Net, $totals.Gross)) $ea 2
    if ($totals.Net -gt $totals.Gross) { $res.Notes.Add("Net and gross weight were swapped, corrected") }
    for ($i = 0; $i -lt $lots.Count; $i++) {
        $res.Rows.Add(@{ Doc = $inv.Number; Lot = $lots[$i].Lot; Ea = $ea[$i]; Pal = $pal[$i]; Net = $net[$i]; Gross = $gross[$i] })
    }
    return $res
}

function Test-CooDateNumber([string]$n) {
    # 8 digits that read as a date (20261016, 16102026) are not draft or certificate numbers
    return ($n -match '^20\d\d(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])$' -or $n -match '^(0[1-9]|[12]\d|3[01])(0[1-9]|1[0-2])20\d\d$')
}

function Get-CooNumbers([string]$text) {
    # 8-digit draft / certificate numbers in order of appearance; lot numbers start with 0, dates are left out
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($m in [regex]::Matches($text, '(?<!\d)[1-9]\d{7}(?!\d)')) {
        if (-not (Test-CooDateNumber $m.Value) -and -not $out.Contains($m.Value)) { $out.Add($m.Value) }
    }
    return ,$out
}

function Get-CooNumberFromName([string]$name) {
    $found = Get-CooNumbers $name
    if ($found.Count -eq 1) { return $found[0] }
    return ''
}

function Get-CooZips([string]$cooDir) {
    # Every ZIP with PDFs in the Downloads folder is a candidate, whatever the attachments are called:
    # the content decides when it is read. Only update ZIPs of PROMEDIA COPILOT itself are left out.
    try { Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop } catch { }
    $forms = @(Get-ChildItem -LiteralPath (Join-Path $cooDir $CooFormDirName) -Filter '*.pdf' -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
    $res = New-Object System.Collections.Generic.List[object]
    foreach ($z in @(Get-ChildItem -LiteralPath $WorkDir -Filter '*.zip' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)) {
        $zip = $null
        try {
            $zip = [System.IO.Compression.ZipFile]::OpenRead($z.FullName)
            $names = @($zip.Entries | ForEach-Object { $_.Name })
            if ($names -contains 'update.txt' -and $names -contains '_promedia_copilot.ps1') { continue }
            $pdfs = @($names | Where-Object { $_ -match '(?i)\.pdf$' })
            if ($pdfs.Count -eq 0) { continue }
            $nr = Get-CooNumberFromName $z.BaseName
            $done = $false
            if ($nr) { $done = (@($forms | Where-Object { $_ -match ('(?<!\d)' + $nr + '(?!\d)') -and $_ -notmatch '(?i)cancel' }).Count -gt 0) }
            $res.Add(@{ File = $z; Nr = $nr; Pdfs = $pdfs.Count; Done = $done })
        } catch { } finally { if ($zip) { $zip.Dispose() } }
    }
    return ,$res
}

function Read-CooZip([string]$zipPath) {
    # Unpacks the PDFs of the draft e-mail to a temp folder and sorts them: Axium invoice, Italian certificates, other
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('pmcopilot_coo_' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp -ErrorAction Stop | Out-Null
    $case = @{ Zip = $zipPath; Temp = $tmp; DraftNr = ''; Invoices = (New-Object System.Collections.Generic.List[object]); Certs = (New-Object System.Collections.Generic.List[object]); Finals = (New-Object System.Collections.Generic.List[string]); Other = (New-Object System.Collections.Generic.List[string]) }
    $zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
    $files = New-Object System.Collections.Generic.List[object]
    try {
        $n = 0
        foreach ($e in @($zip.Entries | Where-Object { $_.Name -match '(?i)\.pdf$' })) {
            $n++
            $dest = Join-Path $tmp ($n.ToString('00') + '_' + ($e.Name -replace '[\\/:*?"<>|]', '_'))
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($e, $dest, $true)
            $files.Add(@{ Name = $e.Name; Path = $dest })
        }
    } finally { $zip.Dispose() }

    $seen = @{}
    $i = 0
    foreach ($f in $files) {
        $i++
        # the same certificate is often attached twice under different names
        $hash = (Get-FileHash -LiteralPath $f.Path -Algorithm MD5).Hash
        if ($seen.ContainsKey($hash)) { continue }
        $seen[$hash] = $true
        $spin = Start-Spin ("reading " + $i + "/" + $files.Count + ": " + $f.Name + "...")
        $lines = $null
        try { $lines = Get-PdfLines $f.Path } catch { $lines = $null }
        Stop-Spin $spin
        if (-not $lines) { $case.Other.Add($f.Name); continue }
        $c = $null
        $inv = $null
        try {
            $c = Get-CooItalianCert $lines
            if (-not $c) {
                $all = $lines -join "`n"
                if ($all -match '(?i)cert\.ihk\.de|DIGITALLY SIGNED') { $case.Finals.Add($f.Name); continue }
                if ($all -match '(?i)ENTWURF|DRAFT' -and $all -match '(?i)URSPRUNGSZEUGNIS|CERTIFICATE OF ORIGIN') {
                    # IHK draft attached: its number is the draft number when the ZIP name has none
                    $head = Get-CooNumbers ((@($lines | Select-Object -First 6)) -join "`n")
                    if ($head.Count -eq 0) { $head = Get-CooNumbers $all }
                    if ($head.Count -gt 0 -and -not $case.DraftNr) { $case.DraftNr = $head[0] }
                    $case.Other.Add($f.Name)
                    continue
                }
                $inv = Get-CooInvoice $lines
            }
        } catch { $case.Other.Add($f.Name); continue }
        if ($c) {
            if (@($case.Certs | Where-Object { $_.Number -eq $c.Number }).Count -eq 0) {
                $c.File = $f.Path; $c.Name = $f.Name
                $case.Certs.Add($c)
            }
            continue
        }
        if ($inv) {
            if (@($case.Invoices | Where-Object { $_.Number -eq $inv.Number }).Count -eq 0) { $inv.Name = $f.Name; $case.Invoices.Add($inv) }
            continue
        }
        $case.Other.Add($f.Name)
    }
    return $case
}

function Read-CooRows($ws, [int]$cols) {
    # Data rows of a sheet table (row 1 = header), up to the last filled cell in columns A to C.
    # End(xlUp) stops at the end of the table (row ~1048572 here), so the used range is searched instead.
    $ur = $ws.UsedRange
    $bottom = $ur.Row + $ur.Rows.Count - 1
    $last = 1
    if ($bottom -ge 2) {
        $abc = $ws.Range($ws.Cells(2, 1), $ws.Cells($bottom, 3)).Value2
        for ($i = $bottom - 1; $i -ge 1 -and $last -eq 1; $i--) {
            for ($j = 1; $j -le 3; $j++) {
                $x = $abc[$i, $j]
                if ($null -ne $x -and ([string]$x).Trim() -ne '') { $last = $i + 1; break }
            }
        }
    }
    $rows = New-Object System.Collections.Generic.List[object]
    if ($last -lt 2) { return @{ Rows = $rows; Last = $last } }
    $v = $ws.Range($ws.Cells(2, 1), $ws.Cells($last, $cols)).Value2
    for ($i = 1; $i -le $last - 1; $i++) {
        $row = @{ Row = $i + 1; V = @() }
        $vals = New-Object 'object[]' $cols
        for ($j = 1; $j -le $cols; $j++) { $vals[$j - 1] = $v[$i, $j] }
        $row.V = $vals
        $rows.Add($row)
    }
    return @{ Rows = $rows; Last = $last }
}

function ConvertTo-CooKey($v) {
    if ($null -eq $v) { return '' }
    if ($v -is [double]) { return ([int64]$v).ToString('00000000') }
    return ([string]$v).Trim().ToUpper()
}

function ConvertTo-CooDouble($v) {
    if ($null -eq $v) { return 0.0 }
    if ($v -is [double]) { return $v }
    $d = ConvertFrom-CooNumber ([string]$v)
    if ($null -eq $d) { return 0.0 }
    return $d
}

function Open-CooWorkbook([string]$path) {
    $xl = $null
    try { $xl = New-Object -ComObject Excel.Application } catch { throw "Microsoft Excel could not be started (COM). Is Excel installed?" }
    $xl.Visible = $false
    $xl.DisplayAlerts = $false
    $xl.ScreenUpdating = $false
    try { $xl.AskToUpdateLinks = $false } catch { }
    try {
        # Notify = false: a workbook in use opens read-only instead of waiting on a hidden dialog
        $miss = [Type]::Missing
        $wb = $xl.Workbooks.Open($path, 0, $false, $miss, $miss, $miss, $true, $miss, $miss, $miss, $false)
    } catch {
        try { $xl.Quit() } catch { }
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl)
        throw ("Could not open " + [System.IO.Path]::GetFileName($path) + ": " + $_.Exception.Message)
    }
    return @{ Xl = $xl; Wb = $wb }
}

function Close-CooWorkbook($h, [bool]$save) {
    if (-not $h) { return }
    try { if ($save) { $h.Wb.Save() } } finally {
        try { $h.Wb.Close($false) } catch { }
        try { $h.Xl.Quit() } catch { }
        foreach ($o in @($h.Wb, $h.Xl)) {
            try { if ($o) { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($o) } } catch { }
        }
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
    }
}

function Get-CooPlan($case, [string]$nr, $wb, $totals) {
    # Everything that would be written, worked out from the documents and the current workbook
    $wsIt = $wb.Worksheets.Item('COO Italy')
    $wsDe = $wb.Worksheets.Item('COO DE')
    $it = Read-CooRows $wsIt 6
    $de = Read-CooRows $wsDe 9
    $inv = $case.Invoices[0]
    $plan = @{
        Nr = $nr; Invoice = $inv
        ItLast = $it.Last; DeLast = $de.Last
        ItNew = (New-Object System.Collections.Generic.List[object])
        CertInfo = (New-Object System.Collections.Generic.List[object])
        DeNew = (New-Object System.Collections.Generic.List[object])
        DeExisting = (New-Object System.Collections.Generic.List[object])
        Notes = (New-Object System.Collections.Generic.List[string])
        Warnings = (New-Object System.Collections.Generic.List[string])
        Coverage = @{}
    }

    $itAll = New-Object System.Collections.Generic.List[object]
    foreach ($r in $it.Rows) {
        $itAll.Add(@{ Cert = (ConvertTo-CooKey $r.V[0]); Lot = (ConvertTo-CooKey $r.V[2]); Gross = (ConvertTo-CooDouble $r.V[5]) })
    }
    foreach ($c in $case.Certs) {
        $info = @{ Cert = $c; Status = ''; Rows = $null }
        if ($c.Origin -and $c.Origin -notmatch '^(EGYPT|EGITTO)$') {
            $info.Status = 'origin ' + $c.Origin + ', not used'
        } else {
            $rows = Get-CooItalyRows $c
            if (-not $rows) {
                $info.Status = 'could not be read completely (lots, quantities, pallets or weights missing), enter it by hand'
                $plan.Warnings.Add("Italian certificate " + $c.Number + " could not be read completely")
            } else {
                $new = @($rows | Where-Object { $r = $_; @($itAll | Where-Object { $_.Cert -eq $r.Cert -and $_.Lot -eq $r.Lot }).Count -eq 0 })
                if ($new.Count -eq 0) { $info.Status = "already in 'COO Italy'" }
                elseif ($new.Count -lt $rows.Count) { $info.Status = 'partly in ''COO Italy'', missing lots are added' }
                else { $info.Status = 'new' }
                $info.Rows = $new
                foreach ($r in $new) {
                    $plan.ItNew.Add($r)
                    $itAll.Add(@{ Cert = $r.Cert; Lot = $r.Lot; Gross = $r.Gross })
                }
            }
        }
        $plan.CertInfo.Add($info)
    }

    $deAll = New-Object System.Collections.Generic.List[object]
    foreach ($r in $de.Rows) {
        $row = @{ Row = $r.Row; Nr = (ConvertTo-CooKey $r.V[0]); Doc = [string]$r.V[1]; Lot = (ConvertTo-CooKey $r.V[2]); Pal = (ConvertTo-CooDouble $r.V[3]); Net = (ConvertTo-CooDouble $r.V[4]); Gross = (ConvertTo-CooDouble $r.V[5]) }
        $deAll.Add($row)
        if ($row.Nr -eq $nr) { $plan.DeExisting.Add($row) }
    }

    $g = Get-CooGermanRows $inv $totals
    foreach ($n in $g.Notes) { $plan.Notes.Add($n) }
    $plan.EaPerPal = $g.EaPerPal
    if ($plan.DeExisting.Count -eq 0) {
        foreach ($r in $g.Rows) { $plan.DeNew.Add($r); $deAll.Add(@{ Nr = $nr; Lot = (ConvertTo-CooKey $r.Lot); Gross = $r.Gross }) }
    } else {
        # Already entered: only compare with the invoice
        $diff = $false
        if ($plan.DeExisting.Count -ne $g.Rows.Count) { $diff = $true }
        foreach ($r in $g.Rows) {
            $m = @($plan.DeExisting | Where-Object { $_.Lot -eq (ConvertTo-CooKey $r.Lot) })
            if ($m.Count -ne 1 -or [math]::Abs($m[0].Pal - $r.Pal) -gt 0.01 -or [math]::Abs($m[0].Gross - $r.Gross) -gt 0.01 -or [math]::Abs($m[0].Net - $r.Net) -gt 0.01) { $diff = $true }
        }
        $plan.ExistingDiffers = $diff
        $plan.Computed = $g.Rows
    }

    $lots = @($plan.DeNew | ForEach-Object { ConvertTo-CooKey $_.Lot })
    if ($plan.DeExisting.Count -gt 0) { $lots = @($plan.DeExisting | ForEach-Object { $_.Lot }) }
    foreach ($lot in ($lots | Select-Object -Unique)) {
        $its = @($itAll | Where-Object { $_.Lot -eq $lot })
        $total = 0.0; foreach ($x in $its) { $total += $x.Gross }
        $used = 0.0; foreach ($x in @($deAll | Where-Object { $_.Lot -eq $lot })) { $used += $x.Gross }
        $plan.Coverage[$lot] = @{ Certs = @($its | ForEach-Object { $_.Cert } | Select-Object -Unique); Total = $total; Left = ($total - $used) }
        if ($its.Count -eq 0) { $plan.Warnings.Add("Lot " + $lot + ": no Italian certificate in 'COO Italy' or in the ZIP") }
        elseif ($total - $used -lt -0.005) { $plan.Warnings.Add("Lot " + $lot + ": " + (Format-CooKg (-($total - $used))) + " kg more than the Italian certificates cover") }
    }
    return $plan
}

function Format-CooKg([double]$v) { return $v.ToString('#,##0.00', $UnitsDe) }
function Format-CooPal([double]$v) { return $v.ToString('0.###', $UnitsDe) }

function Write-CooRows($ws, [int]$firstRow, $rows, [string[]]$textCols) {
    # Writes the value rows (object[,]) below the last row; text columns are formatted as text first so "02607053" keeps its 0
    $n = $rows.GetLength(0)
    $cols = $rows.GetLength(1)
    $lastRow = $firstRow + $n - 1
    foreach ($col in $textCols) { $ws.Range(($col + $firstRow) + ':' + ($col + $lastRow)).NumberFormat = '@' }
    Set-SheetArray $ws $firstRow 1 $rows
    try {
        if ($ws.ListObjects.Count -gt 0) {
            $lo = $ws.ListObjects.Item(1)
            $loLast = $lo.Range.Row + $lo.Range.Rows.Count - 1
            if ($lastRow -gt $loLast) { $lo.Resize($ws.Range($lo.Range.Cells(1, 1), $ws.Cells($lastRow, $lo.Range.Column + $lo.Range.Columns.Count - 1))) | Out-Null }
        }
    } catch { }
}


function Invoke-CooWrite($h, $plan, [bool]$setForm) {
    # Writes the new rows (and the number into the IHK form), calculates once and reads back what Excel says.
    # The FILTER/SUMIF formulas run over whole table columns, so calculating after every write would take long.
    $res = @{ ItRows = 0; DeRows = 0; DeCheck = (New-Object System.Collections.Generic.List[object]) }
    $calc = $h.Xl.Calculation
    $h.Xl.Calculation = -4135
    try {
        $wb = $h.Wb
        if ($plan.ItNew.Count -gt 0) {
            $ws = $wb.Worksheets.Item('COO Italy')
            $arr = New-Object 'object[,]' $plan.ItNew.Count, 6
            for ($i = 0; $i -lt $plan.ItNew.Count; $i++) {
                $r = $plan.ItNew[$i]
                $arr[$i, 0] = $r.Cert; $arr[$i, 1] = $r.Doc; $arr[$i, 2] = $r.Lot
                $arr[$i, 3] = [double]$r.Pal; $arr[$i, 4] = [double]$r.Net; $arr[$i, 5] = [double]$r.Gross
            }
            Write-CooRows $ws ($plan.ItLast + 1) $arr @('C')
            $res.ItRows = $plan.ItNew.Count
        }
        $wsDe = $wb.Worksheets.Item('COO DE')
        $first = $plan.DeLast + 1
        if ($plan.DeNew.Count -gt 0) {
            $arr = New-Object 'object[,]' $plan.DeNew.Count, 6
            for ($i = 0; $i -lt $plan.DeNew.Count; $i++) {
                $r = $plan.DeNew[$i]
                $arr[$i, 0] = [double]$plan.Nr; $arr[$i, 1] = $r.Doc; $arr[$i, 2] = $r.Lot
                $arr[$i, 3] = [double]$r.Pal; $arr[$i, 4] = [double]$r.Net; $arr[$i, 5] = [double]$r.Gross
            }
            Write-CooRows $wsDe $first $arr @('C')
            for ($r = $first; $r -lt $first + $plan.DeNew.Count; $r++) {
                if (-not $wsDe.Cells($r, 7).HasFormula -and $r -gt 2 -and $wsDe.Cells($r - 1, 7).HasFormula) {
                    [void]$wsDe.Range("G$($r - 1):I$($r - 1)").Copy($wsDe.Range("G${r}:I${r}"))
                }
            }
            $res.DeRows = $plan.DeNew.Count
        }
        if ($setForm) {
            $wsF = $wb.Worksheets.Item('Formular IHK')
            $cell = $wsF.Range('B6')
            for ($r = 1; $r -le 15; $r++) {
                if (([string]$wsF.Cells($r, 1).Value2).Trim() -eq 'Antragsnummer:') { $cell = $wsF.Cells($r, 2); break }
            }
            $cell.Value2 = [double]$plan.Nr
        }
        $h.Xl.Calculate()

        $rowsToCheck = @($plan.DeExisting | ForEach-Object { $_.Row })
        if ($plan.DeNew.Count -gt 0) { $rowsToCheck = @($first..($first + $plan.DeNew.Count - 1)) }
        foreach ($r in $rowsToCheck) {
            $res.DeCheck.Add(@{ Lot = [string]$wsDe.Cells($r, 3).Value2; Certs = [string]$wsDe.Cells($r, 7).Value2; Left = $wsDe.Cells($r, 9).Value2 })
        }
    } finally {
        $h.Xl.Calculation = $calc
    }
    return $res
}

function Export-CooForm($h, [string]$pdfPath) {
    # The sheet's stored printer is looked up on the network first (about 30 s); the local PDF printer
    # avoids that. This only changes the printer of this hidden Excel, not the Windows default printer.
    try {
        $port = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Devices' -ErrorAction Stop).'Microsoft Print to PDF'
        $m = [regex]::Match([string]$h.Xl.ActivePrinter, '^.* (\S+) \S+:$')
        if ($port -and $m.Success) { $h.Xl.ActivePrinter = 'Microsoft Print to PDF ' + $m.Groups[1].Value + ' ' + ($port -split ',')[1] }
    } catch { }
    $h.Wb.Worksheets.Item('Formular IHK').ExportAsFixedFormat(0, $pdfPath)
}

function Show-CooIntro {
    Write-Host "   CERTIFICATE OF ORIGIN   (beta)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   Needed in the Downloads folder:" -ForegroundColor Yellow
    Write-Host "     - the ZIP with the attachments of the draft e-mail from Axium (Download all)," -ForegroundColor Gray
    Write-Host "       whatever they are called: the Axium sales invoice and, for goods of Egyptian" -ForegroundColor Gray
    Write-Host "       origin, the Italian certificates. The draft number comes from the ZIP name." -ForegroundColor Gray
    Write-Host "     - and/or the issued certificate from the IHK: COO_<number>_<customer>.pdf," -ForegroundColor Gray
    Write-Host "       ..._digital_CoO.pdf or ..._cert_doc.pdf" -ForegroundColor Gray
    Write-Host "     - once, and again after catalog changes: the catalog backup Katalog_Backup_*.json" -ForegroundColor Gray
    Write-Host "       for the EA per pallet of each article (it is kept, you may delete it afterwards)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   What happens:" -ForegroundColor Yellow
    Write-Host "     Draft, Egypt : new Italian certificates go to 'COO Italy', the invoice lots to 'COO DE'," -ForegroundColor Gray
    Write-Host "                    the IHK form is saved as PDF in 'Coo IHK Formulare' and new Italian" -ForegroundColor Gray
    Write-Host "                    certificates are filed in 'Coo Italy'. Italian certificates whose pallets do" -ForegroundColor Gray
    Write-Host "                    not fit the catalog (Katalog_Backup_*.json) or whose weights do not fit" -ForegroundColor Gray
    Write-Host "                    the earlier certificates of the article stop the run." -ForegroundColor Gray
    Write-Host "     Draft, Italy : nothing to calculate, a summary to check the IHK draft is shown." -ForegroundColor Gray
    Write-Host "     Certificate  : moved to the customer folder as COO_<number>_<customer>.pdf." -ForegroundColor Gray
    Write-Host ""
    Write-Host "   Nothing is written or moved before you confirm." -ForegroundColor DarkGray
    Write-Host ""
    Write-Host $light -ForegroundColor DarkCyan
    Write-Host "   Enter = start     Esc = back" -ForegroundColor DarkGray
    while ($true) {
        $k = [Console]::ReadKey($true)
        if ($k.Key -eq 'Enter') { return $true }
        if ($k.Key -eq 'Escape' -or $k.Key -eq 'Backspace') { return $false }
    }
}

function Show-CooInvoice($inv) {
    $date = if ($inv.Date) { " of " + $inv.Date } else { "" }
    Write-Host ("   Invoice   : " + $inv.Number + $date + "   " + $inv.Customer) -ForegroundColor Gray
    foreach ($it in $inv.Items) {
        $org = $it.Origin
        if ($IsoCountry.ContainsKey($org)) { $org = $org + " (" + $IsoCountry[$org] + ")" }
        Write-Host ("     " + $it.Item + "  " + $it.Desc + "   " + $it.Qty.ToString('#,##0', $UnitsDe) + " " + $it.Uom + "   origin " + $org) -ForegroundColor Gray
        foreach ($l in $it.Lots) { Write-Host ("        lot " + $l.Lot.PadRight(10) + $l.Qty.ToString('#,##0', $UnitsDe).PadLeft(8) + " " + $it.Uom) -ForegroundColor DarkGray }
    }
    $tot = "     "
    if ($null -ne $inv.Packages) { $tot += (Format-CooPal $inv.Packages) + " packages   " }
    if ($null -ne $inv.Net) { $tot += "net " + (Format-CooKg $inv.Net) + " kg   " }
    if ($null -ne $inv.Gross) { $tot += "gross " + (Format-CooKg $inv.Gross) + " kg" }
    Write-Host $tot -ForegroundColor Gray
    if ($null -ne $inv.Net -and $null -ne $inv.Gross -and $inv.Net -gt $inv.Gross) {
        Write-Host "     Net weight is higher than gross weight on the invoice - check the IHK draft." -ForegroundColor Red
    }
}

function Show-CooPlan($plan, [string]$pdfPath, $fileCerts) {
    $inv = $plan.Invoice
    if ($plan.EaPerPal) { Write-Host ("     " + $plan.EaPerPal.ToString('#,##0.##', $UnitsDe) + " EA per pallet (rule of three)") -ForegroundColor DarkGray }
    Write-Host ""
    Write-Host "   Italian certificates in the ZIP" -ForegroundColor Yellow
    if ($plan.CertInfo.Count -eq 0) { Write-Host "     (none)" -ForegroundColor DarkGray }
    foreach ($ci in $plan.CertInfo) {
        $c = $ci.Cert
        $line = "     " + $c.Number + "  " + $c.Doc + "  " + (Format-CooPal ([double]$c.Pallets)) + " pallets   net " + (Format-CooKg ([double]$c.Net)) + "   gross " + (Format-CooKg ([double]$c.Gross))
        Write-Host $line -ForegroundColor Gray
        if ($c.Swapped) { Write-Host "       net and gross were swapped on the certificate, corrected" -ForegroundColor DarkYellow }
        $chk = $ci.Check
        if ($chk -and $chk.Problems.Count -gt 0) {
            $pc = if ($ci.Status -match '^already') { 'Yellow' } else { 'Red' }
            Write-Host ("       does not fit " + $chk.Product + ":") -ForegroundColor $pc
            foreach ($p in $chk.Problems) { Write-Host ("         " + $p) -ForegroundColor $pc }
            if ($chk.Ref -lt 3) { Write-Host ("         weights not checked: fewer than 3 earlier certificates of " + $chk.Product) -ForegroundColor DarkGray }
        } elseif ($chk -and $chk.Product -and -not $chk.PalBy) {
            Write-Host ("       not checked: " + $chk.Product + " is not in the catalog and has fewer than 3 earlier certificates in '" + $CooItalyDirName + "'") -ForegroundColor DarkGray
        } elseif ($chk -and $chk.Product -and $chk.Ref -lt 3) {
            Write-Host ("       pallets fit the catalog, weights not checked: fewer than 3 earlier certificates of " + $chk.Product) -ForegroundColor DarkGreen
        } elseif ($chk -and $chk.Product) {
            Write-Host ("       pallets fit the " + $chk.PalBy + ", weights fit the " + $chk.Ref + " earlier certificates of " + $chk.Product) -ForegroundColor DarkGreen
        } elseif ($chk -and $ci.Status -notmatch '^could not') {
            Write-Host "       not checked: several articles or quantities missing" -ForegroundColor DarkGray
        }
        $color = if ($ci.Status -eq 'new') { 'Green' } elseif ($ci.Status -match '^already') { 'DarkGray' } else { 'Yellow' }
        Write-Host ("       " + $ci.Status) -ForegroundColor $color
        foreach ($r in @($ci.Rows)) {
            Write-Host ("         " + $r.Lot.PadRight(10) + (Format-CooPal $r.Pal).PadLeft(7) + " PAL" + (Format-CooKg $r.Net).PadLeft(12) + (Format-CooKg $r.Gross).PadLeft(12)) -ForegroundColor Green
        }
    }
    Write-Host ""
    if ($plan.DeExisting.Count -gt 0) {
        Write-Host ("   'COO DE' already has " + $plan.DeExisting.Count + " row(s) for " + $plan.Nr + ", nothing is added there") -ForegroundColor Yellow
        $show = $plan.DeExisting
        $color = 'DarkGray'
    } else {
        Write-Host ("   New rows for 'COO DE'   (Antrags-Nr. " + $plan.Nr + ")") -ForegroundColor Yellow
        $show = $plan.DeNew
        $color = 'Green'
    }
    Write-Host ("     " + "Lot".PadRight(10) + "PAL".PadLeft(7) + "Net kg".PadLeft(12) + "Gross kg".PadLeft(12) + "   " + "COO IT".PadRight(28) + "left kg".PadLeft(10)) -ForegroundColor DarkGray
    foreach ($r in $show) {
        $cov = $plan.Coverage[(ConvertTo-CooKey $r.Lot)]
        $certs = ''; $left = ''
        $lc = $color
        if ($cov) {
            $certs = ($cov.Certs -join ', ')
            $left = Format-CooKg $cov.Left
            if ($cov.Certs.Count -eq 0 -or $cov.Left -lt -0.005) { $lc = 'Red' }
        }
        if ($certs.Length -gt 28) { $certs = $certs.Substring(0, 25) + '...' }
        Write-Host ("     " + ([string]$r.Lot).PadRight(10) + (Format-CooPal $r.Pal).PadLeft(7) + (Format-CooKg $r.Net).PadLeft(12) + (Format-CooKg $r.Gross).PadLeft(12) + "   " + $certs.PadRight(28) + $left.PadLeft(10)) -ForegroundColor $lc
    }
    if ($plan.DeExisting.Count -gt 0) {
        if ($plan.ExistingDiffers) {
            Write-Host "     These rows differ from the invoice, the invoice gives:" -ForegroundColor Red
            foreach ($r in $plan.Computed) {
                Write-Host ("     " + ([string]$r.Lot).PadRight(10) + (Format-CooPal $r.Pal).PadLeft(7) + (Format-CooKg $r.Net).PadLeft(12) + (Format-CooKg $r.Gross).PadLeft(12)) -ForegroundColor Red
            }
        } else {
            Write-Host "     They match the invoice." -ForegroundColor DarkGreen
        }
    }
    foreach ($n in $plan.Notes) { Write-Host ("     " + $n) -ForegroundColor DarkYellow }
    foreach ($w in $plan.Warnings) { Write-Host ("     " + $w) -ForegroundColor Red }
    Write-Host ""
    if ($pdfPath) {
        $exists = if (Test-Path -LiteralPath $pdfPath) { "   (replaces the existing file)" } else { "" }
        Write-Host ("   IHK form : " + $CooFormDirName + "\" + [System.IO.Path]::GetFileName($pdfPath) + $exists) -ForegroundColor Gray
    }
    foreach ($f in $fileCerts) { Write-Host ("   File     : " + $CooItalyDirName + "\" + $f.Target) -ForegroundColor Gray }
}

function Get-CooFormPath([string]$cooDir, [string]$nr) {
    # An existing form for this number is replaced under its name, otherwise the current naming is used
    $dir = Join-Path $cooDir $CooFormDirName
    $old = @(Get-ChildItem -LiteralPath $dir -Filter '*.pdf' -ErrorAction SilentlyContinue | Where-Object { $_.Name -match ('(?<!\d)' + $nr + '(?!\d)') -and $_.Name -notmatch '(?i)cancel' } | Sort-Object LastWriteTime -Descending)
    if ($old.Count -gt 0) { return $old[0].FullName }
    return (Join-Path $dir ("COO " + $nr + "_IHK Formulare.pdf"))
}

function Get-CooCertsToFile($case, [string]$cooDir) {
    # New Italian certificates go to "Coo Italy" as "CO Italia_Lot <lots>_<number>.pdf", unless that certificate is already there
    $dir = Join-Path $cooDir $CooItalyDirName
    $have = @(Get-ChildItem -LiteralPath $dir -Filter '*.pdf' -ErrorAction SilentlyContinue)
    $hashes = $null
    $out = New-Object System.Collections.Generic.List[object]
    foreach ($c in $case.Certs) {
        if (@($have | Where-Object { $_.Name -match [regex]::Escape($c.Number) }).Count -gt 0) { continue }
        if ($null -eq $hashes) { $hashes = @{}; foreach ($f in $have) { try { $hashes[(Get-FileHash -LiteralPath $f.FullName -Algorithm MD5).Hash] = $true } catch { } } }
        if ($hashes.ContainsKey((Get-FileHash -LiteralPath $c.File -Algorithm MD5).Hash)) { continue }
        $name = "CO Italia_Lot " + (@($c.Lots | ForEach-Object { $_.Lot }) -join ' + ') + "_" + $c.Number + ".pdf"
        $out.Add(@{ Cert = $c; Source = $c.File; Target = $name; Path = (Join-Path $dir $name) })
    }
    return ,$out
}

function Invoke-CooZip($sel, [string]$cooDir, [string]$wbPath) {
    $case = $null
    $h = $null
    try {
        Write-Host ("   ZIP       : " + $sel.File.Name) -ForegroundColor DarkGray
        $case = Read-CooZip $sel.File.FullName
        if ($case.Invoices.Count -eq 0) {
            if ($case.Finals.Count -gt 0) {
                Write-Host "   This ZIP holds documents already issued by the IHK:" -ForegroundColor Yellow
                foreach ($x in $case.Finals) { Write-Host ("     " + $x) -ForegroundColor DarkGray }
                Write-Host "   Unpack them into the Downloads folder, then they are offered for filing." -ForegroundColor DarkGray
            } else {
                Write-Host "   No Axium sales invoice found in the ZIP." -ForegroundColor Red
                foreach ($x in $case.Other) { Write-Host ("     not used: " + $x) -ForegroundColor DarkGray }
            }
            return
        }
        if ($case.Invoices.Count -gt 1) {
            Write-Host ("   The ZIP has " + $case.Invoices.Count + " invoices, only " + $case.Invoices[0].Number + " is used.") -ForegroundColor Yellow
        }
        $inv = $case.Invoices[0]
        $nr = $sel.Nr
        if (-not $nr -and $case.DraftNr) {
            $nr = $case.DraftNr
            Write-Host "   The draft number is taken from the IHK draft in the ZIP." -ForegroundColor DarkGray
        }
        while (-not $nr) {
            $t = Read-Host "   Draft number (8 digits, x = cancel)"
            if ($t -match '^\s*x\s*$') { return }
            if ($t -match '^\s*(\d{8})\s*$') { $nr = $matches[1] }
        }
        Write-Host ("   Draft no. : " + $nr) -ForegroundColor Cyan
        Show-CooInvoice $inv
        foreach ($o in $case.Other) { Write-Host ("   not used  : " + $o) -ForegroundColor DarkGray }

        $eg = @($inv.Items | Where-Object { $_.Origin -eq 'EG' })
        $forEgypt = ($eg.Count -gt 0)
        if ($forEgypt -and $eg.Count -lt $inv.Items.Count -and $case.Certs.Count -eq 0) {
            Write-Host ""
            Write-Host "   The invoice has goods of Egyptian and of other origin, and the ZIP has no Italian certificates." -ForegroundColor Yellow
            $a = Read-Host "   Is this draft for the Egyptian goods? (Y/N)"
            $forEgypt = ($a -match '^\s*[yj]')
        }
        if (-not $forEgypt) {
            Write-Host ""
            Write-Host $light -ForegroundColor DarkCyan
            $orgs = @($inv.Items | ForEach-Object { $_.Origin } | Select-Object -Unique)
            $names = @($orgs | ForEach-Object { if ($IsoCountry.ContainsKey($_)) { $IsoCountry[$_] } else { $_ } })
            Write-Host ("   Origin " + ($names -join ', ') + ": nothing to enter in " + $CooWorkbookName + ", no IHK form needed.") -ForegroundColor Green
            Write-Host "   Check the IHK draft against the invoice above: origin, lots and quantities, net and gross weight." -ForegroundColor Gray
            if ($orgs -contains 'IT') {
                Write-Host "   For Italian goods the draft needs the declaration of pure Italian origin (manufacturer CEDIC S.R.L.)." -ForegroundColor DarkGray
            }
            return
        }

        $totals = Get-CooEgyptTotals $inv $case.Certs
        if (@($inv.Items | Where-Object { $_.Origin -ne 'EG' }).Count -gt 0 -or -not $totals) {
            Write-Host ""
            if (@($inv.Items | Where-Object { $_.Origin -ne 'EG' }).Count -gt 0) {
                Write-Host "   The invoice also has goods of other origin, its totals cannot be used." -ForegroundColor Yellow
            } else {
                Write-Host "   Pallets or weights could not be read from the invoice." -ForegroundColor Yellow
            }
            Write-Host "   Enter the values of the Egyptian goods from the IHK draft (Enter = suggestion, x = cancel):" -ForegroundColor Gray
            $t = @{ Packages = $null; Net = $null; Gross = $null }
            foreach ($k in @(@('Packages', 'Pallets'), @('Net', 'Net weight kg'), @('Gross', 'Gross weight kg'))) {
                $def = $null
                if ($totals) { $def = $totals[$k[0]] }
                while ($null -eq $t[$k[0]]) {
                    $p = "     " + $k[1].PadRight(16)
                    if ($null -ne $def) { $p += " [" + $def.ToString('0.##', $UnitsDe) + "]" }
                    $a = Read-Host $p
                    if ($a -match '^\s*x\s*$') { return }
                    if (-not $a.Trim() -and $null -ne $def) { $t[$k[0]] = [double]$def }
                    elseif ($a.Trim()) { $t[$k[0]] = ConvertFrom-CooNumber $a.Trim() }
                }
            }
            $totals = $t
        }

        $history = @()
        if ($case.Certs.Count -gt 0) { $history = Get-CooHistory $cooDir }

        $lock = Join-Path $cooDir ('~$' + $CooWorkbookName)
        if (Test-Path -LiteralPath $lock) {
            Write-Host ""
            Write-Host ("   " + $CooWorkbookName + " is open (by you or a colleague). Close it and run this again.") -ForegroundColor Red
            Write-Host "   If nobody has it open, an interrupted run may have left a hidden Excel: end EXCEL.EXE in the Task Manager." -ForegroundColor DarkGray
            return
        }
        $spin = Start-Spin ("opening " + $CooWorkbookName + " in Excel...")
        try { $h = Open-CooWorkbook $wbPath } finally { Stop-Spin $spin }
        if ($h.Wb.ReadOnly) {
            Write-Host ("   " + $CooWorkbookName + " is open elsewhere (read-only). Close it and run this again.") -ForegroundColor Red
            Write-Host "   If nobody has it open, an interrupted run may have left a hidden Excel: end EXCEL.EXE in the Task Manager." -ForegroundColor DarkGray
            return
        }
        foreach ($sn in @('COO Italy', 'COO DE', 'Formular IHK')) {
            try { [void]$h.Wb.Worksheets.Item($sn) } catch { Write-Host ("   Sheet '" + $sn + "' not found in " + $CooWorkbookName + ".") -ForegroundColor Red; return }
        }
        $spin = Start-Spin "checking the workbook..."
        try { $plan = Get-CooPlan $case $nr $h.Wb $totals } finally { Stop-Spin $spin }
        $pdfPath = Get-CooFormPath $cooDir $nr
        $fileCerts = Get-CooCertsToFile $case $cooDir
        $catalog = Get-CooCatalog
        $palByLot = Get-CooPalletsByLot $inv $catalog
        $need = 0.0
        foreach ($it in $inv.Items) {
            if (-not $catalog[[string]$it.Item]) { $need = $null; break }
            $need += $it.Qty / $catalog[[string]$it.Item]
        }
        if ($null -ne $need -and $inv.Packages -and $inv.Packages -ne [math]::Ceiling($need - 0.01)) {
            $plan.Warnings.Add("Invoice: " + $inv.Packages + " packages, by the catalog " + [math]::Ceiling($need - 0.01) + " pallets - check the pallet count of the invoice")
        }
        $bad = New-Object System.Collections.Generic.List[string]
        foreach ($ci in $plan.CertInfo) {
            if ($ci.Status -match '^origin') { continue }
            $ci.Check = Test-CooCert $ci.Cert $history $palByLot
            if ($ci.Check.Problems.Count -gt 0 -and $ci.Status -notmatch '^already') { $bad.Add($ci.Cert.Number) }
        }
        Show-CooPlan $plan $pdfPath $fileCerts

        if ($bad.Count -gt 0) {
            Write-Host ""
            Write-Host $light -ForegroundColor DarkCyan
            Write-Host ("   STOP: " + ($bad -join ', ') + " does not fit the catalog or the earlier certificates (see above).") -ForegroundColor Red
            Write-Host "   Usually the Italian chamber has to cancel and reissue it: ask Axium for a corrected certificate." -ForegroundColor Gray
            $ans = Read-Host "   Continue anyway with the values on the certificate? (Y/N)"
            if (-not ($ans -match '^\s*[yj]')) {
                Write-Host "   Cancelled, nothing was changed." -ForegroundColor DarkGray
                return
            }
        }

        $rows = $plan.ItNew.Count + $plan.DeNew.Count
        if ($plan.DeNew.Count -eq 0 -and $plan.DeExisting.Count -eq 0) {
            Write-Host ""
            Write-Host "   No rows for 'COO DE' could be worked out, so no IHK form is made. Please enter it by hand." -ForegroundColor Red
            $pdfPath = ''
            if ($plan.ItNew.Count -eq 0 -and $fileCerts.Count -eq 0) { return }
        }
        Write-Host ""
        Write-Host $light -ForegroundColor DarkCyan
        $what = New-Object System.Collections.Generic.List[string]
        if ($rows -gt 0) { $what.Add("write " + $rows + " row(s) to " + $CooWorkbookName) }
        if ($pdfPath) { $what.Add("save the IHK form") }
        if ($fileCerts.Count -gt 0) { $what.Add("file " + $fileCerts.Count + " Italian certificate(s)") }
        $q = ($what -join ', ')
        $ans = Read-Host ("   " + $q.Substring(0, 1).ToUpper() + $q.Substring(1) + "? (Y/N)")
        if (-not ($ans -match '^\s*[yj]')) {
            Write-Host "   Cancelled, nothing was changed." -ForegroundColor DarkGray
            return
        }

        if ($rows -gt 0) {
            $bdir = Join-Path $AppDir '_coo_backup'
            try {
                if (-not (Test-Path -LiteralPath $bdir)) { New-Item -ItemType Directory -Path $bdir | Out-Null }
                Copy-Item -LiteralPath $wbPath -Destination (Join-Path $bdir ([System.IO.Path]::GetFileNameWithoutExtension($CooWorkbookName) + '_' + (Get-Date -Format 'yyyy-MM-dd_HHmmss') + '.xlsx')) -ErrorAction Stop
                @(Get-ChildItem -LiteralPath $bdir -Filter '*.xlsx' | Sort-Object LastWriteTime -Descending | Select-Object -Skip 20) | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
            } catch {
                Write-Host ("   Could not back up " + $CooWorkbookName + ": " + $_.Exception.Message) -ForegroundColor Red
                return
            }
        }
        $res = @{ ItRows = 0; DeRows = 0; DeCheck = @() }
        if ($rows -gt 0 -or $pdfPath) {
            $spin = Start-Spin ("writing " + $CooWorkbookName + " (Excel recalculates, ~30 s)...")
            try {
                $res = Invoke-CooWrite $h $plan ([bool]$pdfPath)
                $h.Wb.Save()
            } finally { Stop-Spin $spin }
        }
        $pdfDone = $false
        if ($pdfPath) {
            $spin = Start-Spin "saving the IHK form as PDF..."
            try {
                Export-CooForm $h $pdfPath
                $pdfDone = $true
            } catch {
                Stop-Spin $spin; $spin = $null
                Write-Host ("   Could not save the IHK form: " + $_.Exception.Message) -ForegroundColor Red
            } finally { Stop-Spin $spin }
        }
        Close-CooWorkbook $h $false
        $h = $null

        Write-Host ""
        if ($res.ItRows -gt 0) { Write-Host ("   COO Italy : " + $res.ItRows + " row(s) added") -ForegroundColor Green }
        if ($res.DeRows -gt 0) { Write-Host ("   COO DE    : " + $res.DeRows + " row(s) added") -ForegroundColor Green }
        foreach ($c in $res.DeCheck) {
            $left = ConvertTo-CooDouble $c.Left
            $color = if ($left -lt -0.005 -or -not $c.Certs) { 'Red' } else { 'DarkGray' }
            Write-Host ("     " + $c.Lot.PadRight(10) + (($c.Certs -replace "`n", ', ')).PadRight(30) + " left " + (Format-CooKg $left) + " kg") -ForegroundColor $color
        }
        if ($pdfDone) { Write-Host ("   IHK form  : " + $CooFormDirName + "\" + [System.IO.Path]::GetFileName($pdfPath)) -ForegroundColor Green }
        foreach ($f in $fileCerts) {
            try {
                Copy-Item -LiteralPath $f.Source -Destination $f.Path -ErrorAction Stop
                Write-Host ("   Filed     : " + $f.Target) -ForegroundColor Green
            } catch {
                Write-Host ("   Could not file " + $f.Target + ": " + $_.Exception.Message) -ForegroundColor Red
            }
        }
        if ($pdfDone) { try { Start-Process -FilePath $pdfPath } catch { } }
    } catch {
        Write-Host ("   ERROR: " + $_.Exception.Message) -ForegroundColor Red
    } finally {
        if ($h) { Close-CooWorkbook $h $false }
        if ($case -and $case.Temp) { try { Remove-Item -LiteralPath $case.Temp -Recurse -Force -ErrorAction SilentlyContinue } catch { } }
    }
}

function Read-CooPdfText([string]$path, $cache) {
    # Text of a PDF for the certificate checks, read once per file version
    $fi = Get-Item -LiteralPath $path
    $key = $fi.FullName + '|' + $fi.LastWriteTimeUtc.Ticks
    if ($cache.ContainsKey($key)) { return $cache[$key] }
    $t = ''
    try { $t = (Get-PdfLines $path) -join "`n" } catch { $t = '' }
    $cache[$key] = $t
    return $t
}

function Get-CooFinalNumber([string]$text) {
    # Number of an issued certificate: IHK-stamped invoice, printout of the electronic certificate
    $m = [regex]::Match($text, '(?i)corresponding\s+to\s+CoO:?\s*(\d{8})')
    if ($m.Success) { return $m.Groups[1].Value }
    $m = [regex]::Match($text, '(?i)(?:Certificate of Origin|Ursprungszeugnisses?)\s+(?:No\.?|Nr\.?)\s*(\d{8})')
    if ($m.Success) { return $m.Groups[1].Value }
    if ($text -match '(?i)cert\.ihk\.de|DIGITALLY SIGNED') {
        $n = Get-CooNumbers $text
        if ($n.Count -gt 0) { return $n[0] }
    }
    return ''
}

function ConvertTo-CooShort([string]$s) {
    return ((($s -replace '\s+', '_') -replace '[\\/:*?"<>|]', '').Trim('_', ' ', '.'))
}

function Get-CooShortName([string]$dir, [string]$folderName) {
    # Customer part of the newest certificate file in the folder, so new files follow the current naming:
    # COO_40780920_Tamer.pdf -> Tamer, Coo_40068271_MPC_UAE.pdf -> MPC_UAE, Coo Seeder Qatar_40017837.pdf -> Seeder_Qatar
    $files = @(Get-ChildItem -LiteralPath $dir -Filter '*.pdf' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending |
        Where-Object { $_.BaseName -notmatch '(?i)cert_doc|digital|IHK|Nachweis|DELETED' })
    foreach ($f in $files) { if ($f.BaseName -cmatch '^COO_\d{8}_(.+)$') { return (ConvertTo-CooShort $matches[1]) } }
    foreach ($f in $files) {
        if ($f.BaseName -match '(?i)^co[oc][ _]*\d{8}[ _]+(.+)$') { return (ConvertTo-CooShort $matches[1]) }
        if ($f.BaseName -match '(?i)^co[oc][ _]+(.+?)[ _]+\d{8}(?:[ _]\d{6})?$') { return (ConvertTo-CooShort $matches[1]) }
    }
    $w = @($folderName -split '[^A-Za-z0-9]+' | Where-Object { $_ })
    if ($w.Count -gt 0) { return $w[0] }
    return 'Customer'
}

function Get-CooCustomerFolders([string]$cooDir) {
    # Subfolders of the COO folder (customer folders) with the words that point to them: the words of the
    # folder name, all names of a country in it (SA -> saudi arabia) and the customer part of its file names
    $res = New-Object System.Collections.Generic.List[object]
    foreach ($d in @(Get-ChildItem -LiteralPath $cooDir -Directory -ErrorAction SilentlyContinue | Sort-Object Name)) {
        if ($d.Name -eq $CooFormDirName -or $d.Name -eq $CooItalyDirName -or $d.Name -match '^[_~.]') { continue }
        $short = Get-CooShortName $d.FullName $d.Name
        $words = New-Object System.Collections.Generic.List[string]
        foreach ($w in (($d.Name + ' ' + $short) -split '[^A-Za-z]+')) {
            if ($w.Length -lt 2) { continue }
            $lw = $w.ToLower()
            if (-not $words.Contains($lw)) { $words.Add($lw) }
            foreach ($code in $CountryNames.Keys) {
                if ($code -eq $w.ToUpper() -or $CountryNames[$code] -contains $lw) {
                    foreach ($v in $CountryNames[$code]) { if (-not $words.Contains($v)) { $words.Add($v) } }
                }
            }
        }
        $res.Add(@{ Name = $d.Name; Path = $d.FullName; Short = $short; Words = $words })
    }
    return ,$res
}

function Find-CooCustomerFolder($folders, [string[]]$names, [string]$text) {
    # A folder word in a file name counts 3, in the document text 1; no clear winner = not recognized
    $nameWords = New-Object System.Collections.Generic.List[string]
    foreach ($n in $names) {
        foreach ($w in (($n -replace '(?i)\.pdf$', '') -split '[^A-Za-z]+')) {
            $lw = $w.ToLower()
            if ($lw.Length -ge 3 -and $lw -notmatch '^(coo|coc|cert|doc|digital|sord|scan|ihk|formular|formulare|deleted|copy|kopie|original|final)$') { $nameWords.Add($lw) }
        }
    }
    $ft = ''
    if ($text) { $ft = ' ' + (Fold-Text $text) + ' ' }
    $best = $null; $bestScore = 0; $second = 0
    foreach ($f in $folders) {
        $score = 0
        foreach ($w in $f.Words) {
            if ($w.Length -lt 3) { continue }
            if ($nameWords.Contains($w)) { $score += 3 }
            elseif ($ft -and $ft -match ('[^a-z]' + [regex]::Escape($w) + '[^a-z]')) { $score += 1 }
        }
        if ($score -gt $bestScore) { $second = $bestScore; $bestScore = $score; $best = $f }
        elseif ($score -gt $second) { $second = $score }
    }
    if ($bestScore -gt 0 -and $bestScore -gt $second) { return $best }
    return $null
}

function Get-CooFinals($folders, $cache) {
    # Issued certificates from the IHK in the Downloads folder (scans named COO_<number>_..., IHK downloads
    # ..._digital_CoO / ..._cert_doc), grouped by certificate number
    $groups = New-Object System.Collections.Generic.List[object]
    $byNr = @{}
    foreach ($f in @(Get-ChildItem -LiteralPath $WorkDir -Filter '*.pdf' -File -ErrorAction SilentlyContinue | Sort-Object Name)) {
        $n = $f.BaseName
        if ($n -match '(?i)IHK Formular|^(PWS|PAC|WP)\d|^DELETED|draft|entwurf') { continue }
        if ($n -notmatch '(?i)(^|[^a-z])co[oc]([^a-z]|$)|cert_doc|digital|ursprung|origin|certificate') { continue }
        $nr = Get-CooNumberFromName $n
        $text = $null
        if (-not $nr) {
            $text = Read-CooPdfText $f.FullName $cache
            if ($text -match '(?i)ENTWURF|DRAFT') { continue }
            $nr = Get-CooFinalNumber $text
            if (-not $nr) { continue }
        }
        if (-not $byNr.ContainsKey($nr)) {
            $byNr[$nr] = @{ Nr = $nr; Files = (New-Object System.Collections.Generic.List[object]); Folder = $null; How = '' }
            $groups.Add($byNr[$nr])
        }
        $byNr[$nr].Files.Add(@{ Path = $f.FullName; Name = $f.Name; Text = $text })
    }
    foreach ($g in $groups) {
        $names = @($g.Files | ForEach-Object { $_.Name })
        $g.Folder = Find-CooCustomerFolder $folders $names ''
        $g.How = 'from the file name'
        if (-not $g.Folder) {
            $sb = New-Object System.Text.StringBuilder
            foreach ($f in $g.Files) {
                if ($null -eq $f.Text) { $f.Text = Read-CooPdfText $f.Path $cache }
                [void]$sb.Append($f.Text)
                [void]$sb.Append("`n")
            }
            $g.Folder = Find-CooCustomerFolder $folders $names $sb.ToString()
            $g.How = 'from the document'
        }
    }
    return ,$groups
}

function Get-CooFinalTargets($group, $folder) {
    # IHK downloads and files already named COO_<number>_<this customer> keep their name, everything else becomes
    # COO_<number>_<customer>.pdf. A file that is already in the folder (same content, any name) is marked 'same';
    # a different file with the target name is never replaced, the new one gets " (2)".
    $out = New-Object System.Collections.Generic.List[object]
    $have = @(Get-ChildItem -LiteralPath $folder.Path -File -ErrorAction SilentlyContinue)
    $used = @{}
    foreach ($f in $group.Files) {
        $len = (Get-Item -LiteralPath $f.Path).Length
        $hash = $null
        $same = $null
        foreach ($x in $have) {
            if ($x.Length -ne $len) { continue }
            if ($null -eq $hash) { $hash = (Get-FileHash -LiteralPath $f.Path -Algorithm MD5).Hash }
            if ((Get-FileHash -LiteralPath $x.FullName -Algorithm MD5).Hash -eq $hash) { $same = $x.Name; break }
        }
        if ($same) {
            $out.Add(@{ File = $f; Name = $same; Target = (Join-Path $folder.Path $same); State = 'same' })
            continue
        }
        $name = $f.Name
        $keep = ($name -match '(?i)_(cert_doc|digital_CoO)')
        if (-not $keep -and $name -cmatch ('^COO_' + $group.Nr + '_(.+)\.pdf$')) {
            # already in the current naming: kept when it names this customer
            foreach ($w in ($matches[1] -split '[^A-Za-z]+')) { if ($w.Length -ge 3 -and $folder.Words.Contains($w.ToLower())) { $keep = $true } }
        }
        if (-not $keep) { $name = 'COO_' + $group.Nr + '_' + $folder.Short + '.pdf' }
        $base = [System.IO.Path]::GetFileNameWithoutExtension($name)
        $k = 1
        while ($used.ContainsKey($name.ToLower()) -or (Test-Path -LiteralPath (Join-Path $folder.Path $name))) {
            $k++
            $name = $base + ' (' + $k + ').pdf'
        }
        $used[$name.ToLower()] = $true
        $out.Add(@{ File = $f; Name = $name; Target = (Join-Path $folder.Path $name); State = 'new' })
    }
    return ,$out
}

function Invoke-CooFile($group, $folders) {
    # Moves the files of one issued certificate into the customer folder. -1 = back without doing anything.
    $folder = $group.Folder
    $how = $group.How
    while ($true) {
        $entries = New-Object System.Collections.Generic.List[object]
        $entries.Add(@{ Text = ("Certificate of origin " + $group.Nr); Header = $true })
        $entries.Add(@{ Text = ""; Header = $true })
        $targets = $null
        if ($folder) {
            $entries.Add(@{ Text = ("Customer folder: " + $folder.Name + "   (" + $how + ")"); Header = $true })
            $targets = Get-CooFinalTargets $group $folder
            foreach ($t in $targets) {
                $txt = "  " + $t.File.Name
                if ($t.State -eq 'same') { $txt += "   already there as " + $t.Name + ", only removed from Downloads" }
                elseif ($t.Name -ne $t.File.Name) { $txt += "   -> " + $t.Name }
                $entries.Add(@{ Text = $txt; Header = $true })
            }
        } else {
            $entries.Add(@{ Text = "Customer not recognized, please choose the folder."; Header = $true })
            foreach ($f in $group.Files) { $entries.Add(@{ Text = ("  " + $f.Name); Header = $true }) }
        }
        $entries.Add(@{ Text = ""; Header = $true })
        if ($folder) { $entries.Add(@{ Text = ("[ Move to " + $folder.Name + " ]"); Header = $false; Act = 'MOVE' }) }
        $entries.Add(@{ Text = "[ Choose customer folder ]"; Header = $false; Act = 'PICK' })
        $entries.Add(@{ Text = "[ Back ]"; Header = $false; Act = 'BACK' })
        $sel = Show-DocMenu "FILE CERTIFICATE OF ORIGIN" $entries.ToArray()
        if ($sel -lt 0 -or $entries[$sel].Act -eq 'BACK') { return -1 }
        if ($entries[$sel].Act -eq 'PICK') {
            if ($folders.Count -eq 0) { continue }
            $items = @($folders | ForEach-Object { $_.Name })
            $c = Show-Menu "CUSTOMER FOLDER FOR CERTIFICATE $($group.Nr)" ($items + @("", "Back"))
            if ($c -ge 0 -and $c -lt $folders.Count) { $folder = $folders[$c]; $how = 'chosen' }
            continue
        }

        Clear-Host
        Show-Header
        Write-Host ""
        $n = 0
        foreach ($t in $targets) {
            if ($t.State -eq 'same') {
                try {
                    Remove-Item -LiteralPath $t.File.Path -Force -ErrorAction Stop
                    Write-Host ("  " + $t.File.Name + ": already in " + $folder.Name + ", removed from Downloads") -ForegroundColor DarkGray
                } catch {
                    Write-Host ("  Could not remove " + $t.File.Name + ": " + $_.Exception.Message) -ForegroundColor Red
                }
                continue
            }
            if (Move-FileSafe $t.File.Path $t.Target) {
                Write-Host ("  Moved " + $t.File.Name + " -> " + $folder.Name + "\" + $t.Name) -ForegroundColor Green
                $n++
            }
        }
        return $n
    }
}

function Invoke-Coo {
    if (-not (Show-CooIntro)) { $script:SkipPause = $true; return }
    Clear-Host
    Show-Header
    Write-Host ""

    $cooDir = Get-OrAskFolder 'COODIR' "Select the COO folder (contains 'COO calculation.xlsx')"
    if (-not $cooDir) { Write-Host "   No COO folder selected. Set it under Settings." -ForegroundColor Yellow; return }
    $wbPath = Join-Path $cooDir $CooWorkbookName
    if (-not (Test-Path -LiteralPath $wbPath)) {
        Write-Host ("   '" + $CooWorkbookName + "' not found in " + $cooDir) -ForegroundColor Red
        Write-Host "   Check the COO folder under Settings." -ForegroundColor DarkGray
        return
    }

    $cache = @{}
    $again = $false
    while ($true) {
        $spin = Start-Spin "looking for draft ZIPs and certificates in the Downloads folder..."
        try {
            $zips = Get-CooZips $cooDir
            $folders = Get-CooCustomerFolders $cooDir
            $finals = Get-CooFinals $folders $cache
        } finally { Stop-Spin $spin }

        $count = $zips.Count + $finals.Count
        if ($count -eq 0) {
            if ($again) { $script:SkipPause = $true; return }
            Write-Host "   Nothing found in the Downloads folder:" -ForegroundColor Yellow
            Write-Host "   - draft e-mail from Axium: save its attachments with 'Download all' as ZIP" -ForegroundColor DarkGray
            Write-Host "   - issued certificate from the IHK: save the PDF" -ForegroundColor DarkGray
            Write-Host ("   into " + $WorkDir) -ForegroundColor DarkGray
            return
        }
        if ($count -eq 1 -and -not $again) {
            if ($zips.Count -eq 1) { Invoke-CooZip $zips[0] $cooDir $wbPath }
            elseif ((Invoke-CooFile $finals[0] $folders) -lt 0) { $script:SkipPause = $true }
            return
        }

        $entries = New-Object System.Collections.Generic.List[object]
        $entries.Add(@{ Text = "Draft e-mails (ZIP)   -> COO calculation.xlsx and IHK form"; Header = $true })
        if ($zips.Count -eq 0) { $entries.Add(@{ Text = "(none)"; Header = $true }) }
        foreach ($z in $zips) {
            $nr = if ($z.Nr) { $z.Nr } else { '????????' }
            $txt = $nr + "   " + $z.File.Name
            if ($z.Done) { $txt += "   [IHK form exists]" }
            $entries.Add(@{ Text = $txt; Header = $false; Act = 'ZIP'; Data = $z; Done = $z.Done })
        }
        $entries.Add(@{ Text = ""; Header = $true })
        $entries.Add(@{ Text = "Issued certificates   -> customer folder"; Header = $true })
        if ($finals.Count -eq 0) { $entries.Add(@{ Text = "(none)"; Header = $true }) }
        foreach ($g in $finals) {
            $dest = if ($g.Folder) { $g.Folder.Name } else { '(customer not recognized)' }
            $what = if ($g.Files.Count -eq 1) { $g.Files[0].Name } else { [string]$g.Files.Count + " files" }
            $entries.Add(@{ Text = ($g.Nr + "   -> " + $dest + "   (" + $what + ")"); Header = $false; Act = 'FILE'; Data = $g })
        }
        $entries.Add(@{ Text = ""; Header = $true })
        $entries.Add(@{ Text = "Back"; Header = $false; Act = 'BACK' })

        $sel = Show-DocMenu "CERTIFICATE OF ORIGIN" $entries.ToArray()
        if ($sel -lt 0 -or $entries[$sel].Act -eq 'BACK') { $script:SkipPause = $true; return }
        $again = $true
        $e = $entries[$sel]
        Clear-Host
        Show-Header
        Write-Host ""
        if ($e.Act -eq 'ZIP') {
            Invoke-CooZip $e.Data $cooDir $wbPath
        } elseif ((Invoke-CooFile $e.Data $folders) -lt 0) {
            continue
        }
        Write-Host ""
        Write-Host $light -ForegroundColor DarkCyan
        Write-Host "   Press any key to continue..." -ForegroundColor DarkGray
        [void][Console]::ReadKey($true)
    }
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
        $entries.Add(@{ Text = ("Halle M scan folder".PadRight(24) + ":  " + (Format-Setting $s['SCANDIR'] 46)); Header = $false; Act = 'SCANDIR'; Done = [bool]$s['SCANDIR'] })
        $cooText = if ($s['COODIR']) { Format-Setting $s['COODIR'] 46 } else { "(optional)" }
        $entries.Add(@{ Text = ("COO folder".PadRight(24) + ":  " + $cooText); Header = $false; Act = 'COODIR'; Done = $true })
        $bIdx = $script:DefaultBanner
        if ($s['BANNER'] -match '^\d+$') { $bIdx = [int]$s['BANNER'] }
        if ($bIdx -lt 0 -or $bIdx -ge $BannerStyles.Count) { $bIdx = $script:DefaultBanner }
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
            'COODIR'   { $p = Browse-ForFolder "Select the COO folder (contains 'COO calculation.xlsx')"; if ($p) { Set-Setting 'COODIR' $p } }
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

$FuMenuLabel = $FuPrefix + " scan"
$FuMoveLabel = "Auto move " + $FuPrefix + " documents"
$CooMenuLabel = "Certificate of Origin   (beta)"
$mainItems = @("Auto rename/create documents", "Annotate WP documents", "Print", "Auto move to folders", $FuMenuLabel, $FuMoveLabel, $CooMenuLabel, "Settings", "", "Quit")

$cfgWork = Get-Setting 'WORKDIR'
if ($cfgWork -and (Test-Path -LiteralPath $cfgWork)) { $WorkDir = $cfgWork.TrimEnd('\') }

try {
    if (-not (Test-SetupComplete)) { Invoke-Settings $true }

    Invoke-Housekeeping
    Invoke-LocalUpdate

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
            $CooMenuLabel           { Invoke-Coo }
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
