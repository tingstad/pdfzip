$expect = "Hello bat
"
$output = cmd.exe /c test\test.sh.bat 2>&1 | Out-String
if ($output -ne $expect) {
    Write-Output "> Expected:
$($output)
> to equal:
$($expect)"
    exit 1
} else {
    Write-Output "OK"
}
