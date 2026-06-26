Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ================= FORM =================
$form = New-Object Windows.Forms.Form
$form.Text = "K8s Java Dump Tool (Final Debug + Namespace Safe)"
$form.Size = New-Object Drawing.Size(640,560)
$form.StartPosition = "CenterScreen"

# ================= HELPERS =================
function Add-Label($text,$x,$y){
    $l = New-Object Windows.Forms.Label
    $l.Text = $text
    $l.Location = "$x,$y"
    $l.Size = "180,20"
    $form.Controls.Add($l)
}
function Add-Textbox($x,$y){
    $t = New-Object Windows.Forms.TextBox
    $t.Location = "$x,$y"
    $t.Size = "320,20"
    $form.Controls.Add($t)
    return $t
}
function Add-Combo($x,$y){
    $c = New-Object Windows.Forms.ComboBox
    $c.Location = "$x,$y"
    $c.Size = "320,20"
    $c.DropDownStyle = "DropDownList"
    $form.Controls.Add($c)
    return $c
}
function Log($msg){ $status.AppendText("$msg`r`n") }

# ================= DEFAULT OUTPUT FOLDER =================
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $scriptRoot) { $scriptRoot = Get-Location }
$defaultOutputFolder = '.\dumps\'
$defaultResolvedOutputFolder = Join-Path $scriptRoot $defaultOutputFolder
if (!(Test-Path $defaultResolvedOutputFolder)) { New-Item -ItemType Directory -Path $defaultResolvedOutputFolder | Out-Null }

# ================= COPY FUNCTION =================
function Copy-FromPod ($ns, $pod, $container, $remoteFile, $localDir) {

    $fileName = [System.IO.Path]::GetFileName($remoteFile)
    $dest = Join-Path $localDir $fileName
    $relativeDest = ".\$fileName"

    if (-not (Test-Path $localDir)) {
        New-Item -ItemType Directory -Path $localDir | Out-Null
    }

    $currentLocation = Get-Location
    try {
        Push-Location -Path $localDir

        if ($container) {
            $cmd = "kubectl cp -n $ns -c $container $pod`:$remoteFile `"$relativeDest`""
        } else {
            $cmd = "kubectl cp -n $ns $pod`:$remoteFile `"$relativeDest`""
        }

        Log "--------------------------------------------"
        Log "EXECUTING COPY:"
        Log "$cmd"
        Log "--------------------------------------------"

        $output = Invoke-Expression "$cmd 2>&1"
        $exitCode = $LASTEXITCODE

        Log "OUTPUT → $output"
        Log "EXIT CODE → $exitCode"
    } finally {
        Pop-Location
    }

    if (Test-Path $dest) {
        $size = (Get-Item $dest).Length
        Log "✅ Downloaded: $dest ($size bytes)"
        return $true
    } else {
        Log "❌ File NOT downloaded"
        return $false
    }
}

# ================= UI =================
Add-Label "Kubeconfig:" 10 20
$txtKube = Add-Textbox 220 20

Add-Label "Namespace:" 10 50
$cbNS = Add-Combo 220 50

Add-Label "Pod:" 10 80
$cbPod = Add-Combo 220 80

Add-Label "Container:" 10 110
$cbContainer = Add-Combo 220 110

Add-Label "Java Process:" 10 140
$cbPID = Add-Combo 220 140

Add-Label "Output Folder:" 10 170
$txtOut = Add-Textbox 220 170
$txtOut.Text = $defaultOutputFolder

Add-Label "Thread Dump Count:" 10 200
$txtCount = Add-Textbox 220 200
$txtCount.Text="3"

Add-Label "Interval (sec):" 10 230
$txtInterval = Add-Textbox 220 230
$txtInterval.Text="10"

# Buttons
$btnKube = New-Object Windows.Forms.Button
$btnKube.Text="Browse"
$btnKube.Location="560,20"
$form.Controls.Add($btnKube)

$btnOut = New-Object Windows.Forms.Button
$btnOut.Text="Browse"
$btnOut.Location="560,170"
$form.Controls.Add($btnOut)

# Status
$status = New-Object Windows.Forms.TextBox
$status.Multiline=$true
$status.ScrollBars="Vertical"
$status.Size="600,200"
$status.Location="10,270"
$form.Controls.Add($status)

# ================= LOAD =================
$btnKube.Add_Click({
    $dlg = New-Object Windows.Forms.OpenFileDialog
    if($dlg.ShowDialog() -eq "OK"){
        $txtKube.Text=$dlg.FileName
        $env:KUBECONFIG=$dlg.FileName

        $ns=kubectl get ns -o jsonpath="{.items[*].metadata.name}"
        $cbNS.Items.Clear()
        $ns.Split(" ") | % { $cbNS.Items.Add($_) }
    }
})

$cbNS.Add_SelectedIndexChanged({
    $ns=$cbNS.SelectedItem
    $pods=kubectl get pods -n $ns -o jsonpath="{.items[*].metadata.name}"
    $cbPod.Items.Clear()
    $pods.Split(" ") | % { $cbPod.Items.Add($_) }
})

$cbPod.Add_SelectedIndexChanged({
    $ns=$cbNS.SelectedItem
    $pod=$cbPod.SelectedItem

    $containers=kubectl get pod $pod -n $ns -o jsonpath="{.spec.containers[*].name}"
    $cbContainer.Items.Clear()
    $cbContainer.Items.Add("") | Out-Null
    $containers.Split(" ") | % { $cbContainer.Items.Add($_) }
})

$cbContainer.Add_SelectedIndexChanged({
    $ns=$cbNS.SelectedItem
    $pod=$cbPod.SelectedItem
    $container=$cbContainer.SelectedItem

    $kexec="kubectl exec -n $ns $pod"
    if($container){ $kexec+=" -c $container" }

    $cbPID.Items.Clear()
    $list=Invoke-Expression "$kexec -- sh -c `"ps -eo pid,args | grep java | grep -v grep`""

    if($list){
        $list -split "`n" | % {
            $line=$_.Trim()
            if($line){ $cbPID.Items.Add($line) }
        }
    }

    if($cbPID.Items.Count -gt 0){ $cbPID.SelectedIndex=0 }
})

$btnOut.Add_Click({
    $dlg = New-Object Windows.Forms.FolderBrowserDialog
    if($dlg.ShowDialog() -eq "OK"){
        $txtOut.Text=$dlg.SelectedPath
    }
})

# ================= EXECUTION =================
$btnRun = New-Object Windows.Forms.Button
$btnRun.Text="Run Collection"
$btnRun.Location="260,500"

$btnRun.Add_Click({

    $ns=$cbNS.SelectedItem
    $pod=$cbPod.SelectedItem
    $container=$cbContainer.SelectedItem
    $output=$txtOut.Text

    if(!$ns -or !$pod){ Log "❌ Namespace & Pod required"; return }
    if ([System.IO.Path]::IsPathRooted($output)) {
        $resolvedOutput = $output
    } else {
        $resolvedOutput = Join-Path $scriptRoot $output
    }
    if (!(Test-Path $resolvedOutput)) { New-Item -ItemType Directory -Path $resolvedOutput | Out-Null }

    $selected=$cbPID.SelectedItem
    if(!$selected){ Log "❌ Select Java process"; return }

    $javaPid=($selected -split " ")[0]
    Log "Using PID: $javaPid"

    $kexec="kubectl exec -n $ns $pod"
    if($container){ $kexec+=" -c $container" }

    $ts=Get-Date -Format "yyyyMMdd_HHmmss"

    # THREAD DUMPS
    $count=[int]$txtCount.Text
    $interval=[int]$txtInterval.Text

    for($i=1;$i -le $count;$i++){

        $thread="/tmp/threaddump_${ts}_$i.txt"

        Log "Creating thread dump $i..."
        Invoke-Expression "$kexec -- sh -c `"jcmd $javaPid Thread.print > $thread 2>&1`""

        Start-Sleep 2

        $exists=Invoke-Expression "$kexec -- sh -c `"ls $thread 2>/dev/null`""

        if($exists){
            Copy-FromPod $ns $pod $container $thread $resolvedOutput
        }

        if($i -lt $count){ Start-Sleep -Seconds $interval }
    }

    # HEAP + GZIP
    $heap="/tmp/heapdump_$ts.hprof"
    $heapGz="$heap.gz"

    Log "Creating heap..."
    Invoke-Expression "$kexec -- sh -c `"jcmd $javaPid GC.heap_dump $heap`""

    Start-Sleep 5

    Log "Compressing heap..."
    Invoke-Expression "$kexec -- sh -c `"gzip -c $heap > $heapGz`""

    $exists=Invoke-Expression "$kexec -- sh -c `"ls $heapGz 2>/dev/null`""

    if($exists){
        Copy-FromPod $ns $pod $container $heapGz $resolvedOutput
    }

    # LOGS
    $logFile=Join-Path $resolvedOutput "podlogs_$ts.txt"
    kubectl logs -n $ns $pod > $logFile

    Log "✅ COMPLETED (FILES PRESERVED IN /tmp)"
})

$form.Controls.Add($btnRun)
$form.ShowDialog()