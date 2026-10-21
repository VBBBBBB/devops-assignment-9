$ErrorActionPreference = 'Stop'

$docx = 'C:\Users\bhamr\anti\Devops\Assignment\Devops Ass 9.docx'
$img = 'C:\Users\bhamr\anti\Devops\Assignment\Ass9\screenshots\06-browser.png'

$work = Join-Path $env:TEMP 'ass9work'
$ex = Join-Path $work 'ex'
Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $work | Out-Null
Copy-Item $docx (Join-Path $work 'backup.docx') -Force

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($docx, $ex)

$docXmlPath = Join-Path $ex 'word\document.xml'
$relsPath = Join-Path $ex 'word\_rels\document.xml.rels'
$UTF8 = New-Object System.Text.UTF8Encoding($false)
$xml = [System.IO.File]::ReadAllText($docXmlPath)

$ms = [regex]::Matches($xml, '<w:p\b[^>]*>.*?</w:p>', [System.Text.RegularExpressions.RegexOptions]::Singleline)

$fig5 = $null
$drawTemplate = $null
foreach ($m in $ms) {
    $text = [regex]::Replace($m.Value, '<[^>]+>', '')
    if (-not $fig5 -and $text -match 'Figure 5:') { $fig5 = $m }
    if (-not $drawTemplate -and $m.Value -match '<w:drawing') { $drawTemplate = $m }
}
if (-not $fig5) { throw 'Figure 5 paragraph not found.' }
if (-not $drawTemplate) { throw 'No drawing template paragraph found.' }

$drawing = ([regex]::Match($drawTemplate.Value, '<w:drawing>.*?</w:drawing>', [System.Text.RegularExpressions.RegexOptions]::Singleline)).Value
if (-not $drawing) { throw 'Could not extract drawing XML.' }

$rels = [System.IO.File]::ReadAllText($relsPath)
$maxId = 0
foreach ($rm in [regex]::Matches($rels, 'Id="rId(\d+)"')) {
    $n = [int]$rm.Groups[1].Value
    if ($n -gt $maxId) { $maxId = $n }
}
$newRid = 'rId' + ($maxId + 1)

$drawing = [regex]::Replace($drawing, 'r:embed="rId\d+"', "r:embed=`"$newRid`"")
$drawing = [regex]::Replace($drawing, 'id="\d+"', 'id="900001"')

$heading = '<w:p><w:pPr><w:spacing w:before="160" w:after="40"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="22"/></w:rPr><w:t xml:space="preserve">Screenshot 6 - Application Response in Browser</w:t></w:r></w:p>'
$command = '<w:p><w:pPr><w:spacing w:after="40"/></w:pPr><w:r><w:t xml:space="preserve">Execution Command / View: Browser -&gt; http://localhost:8888</w:t></w:r></w:p>'
$imagePara = '<w:p><w:pPr><w:spacing w:after="0" w:line="240" w:lineRule="auto"/><w:jc w:val="center"/></w:pPr><w:r>' + $drawing + '</w:r></w:p>'
$caption = '<w:p><w:pPr><w:spacing w:after="120"/><w:jc w:val="center"/></w:pPr><w:r><w:rPr><w:i/><w:sz w:val="19"/></w:rPr><w:t xml:space="preserve">Figure 6: Nginx landing page served through the ClusterIP Service via port-forward.</w:t></w:r></w:p>'

$insertPos = $fig5.Index + $fig5.Length
$block = $heading + $command + $imagePara + $caption
$xml = $xml.Substring(0, $insertPos) + $block + $xml.Substring($insertPos)

[System.IO.File]::WriteAllText($docXmlPath, $xml, $UTF8)

$rel = '<Relationship Id="' + $newRid + '" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/image6.png"/>'
$rels = $rels.Replace('</Relationships>', $rel + '</Relationships>')
[System.IO.File]::WriteAllText($relsPath, $rels, $UTF8)

Copy-Item $img (Join-Path $ex 'word\media\image6.png') -Force

$out = Join-Path $work 'out.docx'
if (Test-Path $out) { Remove-Item $out -Force }
$zip = [System.IO.Compression.ZipFile]::Open($out, 'Create')
Get-ChildItem $ex -Recurse -File | ForEach-Object {
    $name = $_.FullName.Substring($ex.Length + 1).Replace('\', '/')
    $entry = $zip.CreateEntry($name, [System.IO.Compression.CompressionLevel]::Optimal)
    $es = $entry.Open()
    $fs = [System.IO.File]::OpenRead($_.FullName)
    $fs.CopyTo($es)
    $fs.Close(); $es.Close()
}
$zip.Dispose()

Copy-Item $out $docx -Force
Write-Output "Appended Screenshot 6 using $newRid and saved."
