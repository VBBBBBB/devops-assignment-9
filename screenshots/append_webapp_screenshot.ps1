param(
    [Parameter(Mandatory = $true)][string]$DocPath,
    [Parameter(Mandatory = $true)][string]$ImagePath
)

$ErrorActionPreference = 'Stop'

$word = New-Object -ComObject Word.Application
$word.Visible = $false
$word.DisplayAlerts = 0

$doc = $word.Documents.Open($DocPath)
try {
    $rng = $doc.Content
    $f = $rng.Find
    $f.ClearFormatting()
    $f.Text = 'Figure 5:'
    $f.Forward = $true
    $f.Wrap = 0
    $f.MatchCase = $false
    if (-not $f.Execute()) { throw 'Figure 5 paragraph not found.' }

    $p5 = $rng.Paragraphs(1).Range
    $p5.Collapse(0)
    $block = "Screenshot 6 - Application Response in Browser`r" +
             "Execution Command / View: Browser -> http://localhost:8888  (kubectl port-forward svc/student-webapp 8888:80)`r" +
             "<<IMG6>>`r" +
             "Figure 6: Nginx landing page served through the ClusterIP Service via port-forward.`r"
    $p5.InsertAfter($block)

    function Copy-ParaFormat([string]$sourceText, [string]$targetText) {
        $sr = $doc.Content
        $sf = $sr.Find
        $sf.ClearFormatting(); $sf.Text = $sourceText; $sf.Forward = $true; $sf.Wrap = 0; $sf.MatchCase = $false
        if (-not $sf.Execute()) { return }
        $srcStyle = $sr.Paragraphs(1).Style
        $srcBold = $sr.Font.Bold
        $srcSize = $sr.Font.Size
        $srcName = $sr.Font.Name

        $tr = $doc.Content
        $tf = $tr.Find
        $tf.ClearFormatting(); $tf.Text = $targetText; $tf.Forward = $true; $tf.Wrap = 0; $tf.MatchCase = $false
        if (-not $tf.Execute()) { return }
        $tp = $tr.Paragraphs(1).Range
        $tp.Style = $srcStyle
        $tp.Font.Bold = $srcBold
        $tp.Font.Size = $srcSize
        $tp.Font.Name = $srcName
    }

    Copy-ParaFormat 'Screenshot 5 - ' 'Screenshot 6 - '
    Copy-ParaFormat 'Execution Command / View: helm uninstall' 'Execution Command / View: Browser'
    Copy-ParaFormat 'Figure 5:' 'Figure 6:'

    $r2 = $doc.Content
    $f2 = $r2.Find
    $f2.ClearFormatting()
    $f2.Text = '<<IMG6>>'
    $f2.Forward = $true; $f2.Wrap = 0; $f2.MatchCase = $false
    if (-not $f2.Execute()) { throw 'Image placeholder not found.' }
    $r2.Text = ''
    $r2.Collapse(1)
    $shape = $doc.InlineShapes.AddPicture($ImagePath, $false, $true, $r2)
    $shape.LockAspectRatio = -1
    $shape.Width = 460

    $doc.Save()
    Write-Output 'Appended Screenshot 6 and saved.'
} finally {
    $doc.Close(0)
    $word.Quit()
}
