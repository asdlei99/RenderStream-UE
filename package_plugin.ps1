# Note: this script is called by Team City (via TC_env_setup.ps1). Please be careful when modifying it!

param(
    [Parameter(Mandatory=$true)][string]$unreal_engine_path, # path to the Unreal engine
    [string]$plugin_folder = $null, # Optional project root path defualt is set to relative to current directory 
    [string[]] [Parameter (Position = 2, ValueFromRemainingArguments )] $RemainingArgs
)
$PsBoundParameters | Format-Table

if ($plugin_folder -eq ""){
    $plugin_folder = Get-Location
    write-host "project too set to $plugin_folder"
}

$plugin_name = "RenderStream-UE"
$build_tool = "$($unreal_engine_path)\Engine\Build\BatchFiles\RunUAT.bat"
$plugin_path = "$($plugin_folder)\$($plugin_name).uplugin"
$zip_path = "$($plugin_folder)\Packaged"
$out_path = "$($plugin_folder)\Packaged\RenderStream-UE"
$local_intermediate = "$($plugin_folder)\Intermediate"

# Ensure spaces in the build_tool path are hard spaces or Invoke-Expression will fail. Important since default location of Unreal is, eg,
# C:/Program Files/Epic Games/UE_4.26
$build_tool = $build_tool -replace ' ','` '

write-host "current paths"
Get-Variable -Scope script

# Remove the project-local intermediate directory, if it exists - this can interfere with a clean build of the plugin.
if (Test-Path $local_intermediate) {
	Remove-Item -Path $local_intermediate -Recurse -Force
}

# Remove the path the build tool creates to package in - this can interfere with a clean build of the plugin, too.
if (Test-Path $zip_path) {
    Remove-Item -Path $zip_path -Recurse -Force
}

$Uplugin = Get-Content $plugin_path | ConvertFrom-Json

$launch_command = "$($build_tool) BuildPlugin -Plugin=""$($plugin_path)"" -Package=""$($out_path)"" -CreateSubFolder -VS2019"
Write-Host "Packaging Unreal plugin"
Write-Host "$launch_command" 
Invoke-Expression -Command "$launch_command" -ErrorAction Stop

if ($LASTEXITCODE -eq 0) {
    Write-Information -MessageData 'Packaging complete. Zipping build contents.' -InformationAction Continue
	
	# Remove the intermediate results from the packaging process - not useful for distribution
	Remove-Item -Path (Join-Path -Path "$out_path" -ChildPath "Intermediate") -Recurse

    $out_file = "$($plugin_name)_{0}.zip" -f "$($Uplugin.VersionName)"
    $destination = Join-Path -Path "$zip_path" -ChildPath "$out_file"
    $compress = @{
        Path = "$out_path"
        CompressionLevel = 'Optimal'
        DestinationPath = "$destination"
    }
    
    Compress-Archive @compress
}
else {
    exit $LASTEXITCODE
}