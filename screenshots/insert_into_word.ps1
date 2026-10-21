param(
    [Parameter(Mandatory = $true)][string]$DocPath,
    [Parameter(Mandatory = $true)][string[]]$Pairs
)

$ErrorActionPreference = 'Stop'
$imageDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$word = New-Object -ComObject Word.Application
$word.Visible = $false
$word.DisplayAlerts = 0

$doc = $word.Documents.Open($DocPath)
try {
    foreach ($pair in $Pairs) {
        $parts = $pair -split '\|', 2
        $search = $parts[0]
        $image = Join-Path $imageDir $parts[1]
        if (-not (Test-Path -LiteralPath $image)) { throw "Missing image: $image" }

        $rng = $doc.Content
        $find = $rng.Find
        $find.ClearFormatting()
        $find.Text = $search
        $find.Forward = $true
        $find.Wrap = 0
        $find.MatchCase = $false
        if (-not $find.Execute()) { throw "Placeholder not found: '$search'" }

        $rng.Text = ''
        $rng.Collapse(1)
        $shape = $doc.InlineShapes.AddPicture($image, $false, $true, $rng)
        $shape.LockAspectRatio = -1
        $shape.Width = 460
        Write-Output "Inserted $($parts[1]) at '$search'"
    }

    $f2 = $doc.Content.Find
    $f2.ClearFormatting()
    $f2.Replacement.ClearFormatting()
    $f2.Text = '\(paste image[!^13]@'
    $f2.Replacement.Text = ''
    $f2.Forward = $true
    $f2.Wrap = 0
    $f2.MatchWildcards = $true
    $f2.Execute($f2.Text, $false, $false, $true, $false, $false, $true, 0, $false, '', 2) | Out-Null
    Write-Output 'Cleared "(paste image ...)" instruction lines'

    $doc.Save()
    Write-Output 'Saved.'
} finally {
    $doc.Close(0)
    $word.Quit()
}
