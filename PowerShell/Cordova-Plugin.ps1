set-strictmode -version 2.0

function Get-CordovaPluginFileHash($baseFolder, $relativePath, $filter)
{
    $fileHash = @{}
    #Get-ChildItem -Recurse -Path (Join-Path $baseFolder $relativePath) -filter $filter | ForEach-Object { $fileHash.Add($_.Directory.ToString().Replace($baseFolder,"") + "\" + $_.Name, $_) }
    Get-ChildItem -Recurse -Path (Join-Path $baseFolder $relativePath) -filter $filter | ForEach-Object { $fileHash.Add($_.Name, $_) }
    $fileHash
}

function Get-CordovaPluginDifferentFiles($fileHash1, $fileHash2)
{
    $resultHash = @{}

    foreach ($file in $fileHash1.GetEnumerator())
    {
        if ($fileHash2.ContainsKey($file.Key))
        {
            $fileName1 = join-path $file.Value.Directory $file.Value.Name
            $fileName2 = join-path $fileHash2.Item($file.key).Directory $fileHash2.Item($file.key).Name

            if ((Compare-Object $(Get-Content $fileName1) $(Get-Content $fileName2)) -ne $null)
            {
                $resultHash.Add($file.Key, $file.Value);
            }
        }
    }

    $resultHash;
}

function Open-CordovaPlugin-Xml($pluginPath)
{
    [xml](Get-Content $pluginPath)
}

function Add-CordovaPlugin-SourceToXml($pluginPath, $srcAttribute, $targetAttribute)
{
        $xml =  Open-CordovaPlugin-Xml $pluginPath
        
        $sourceNode = $xml.CreateElement("source-file", $xml.DocumentElement.NamespaceURI)
        $sourceNode.SetAttribute("src",  $srcAttribute)
        $sourceNode.SetAttribute("target-dir", $targetAttribute)
        $xml.plugin.platform.AppendChild($sourceNode)        
        
        Close-CordovaPlugin-Xml $pluginPath $xml
}

function Close-CordovaPlugin-Xml($pluginPath, $xml)
{
    $xml.Save($pluginPath)
}

function Update-CordovaPlugin($sourceBase, $sourceReleativePath, $pluginBase, $pluginRelativePath, $fileType)
{
    $sourceHash = Get-CordovaPluginFileHash $sourceBase $sourceReleativePath $fileType

    $pluginHash = Get-CordovaPluginFileHash $pluginBase $pluginRelativePath $fileType

    $toBeAddedHash = $sourceHash.GetEnumerator() | Where-Object { $pluginHash.ContainsKey($_.Key) -eq $false}
    $toBeDeletedHash = $pluginHash.GetEnumerator() | Where-Object { $sourceHash.ContainsKey($_.Key) -eq $false}
    $toBeCopiedHash = Get-CordovaPluginDifferentFiles $sourceHash $pluginHash

    Write-Host "------------------------------------------------------------"
    Write-Host "To be Added"
    Write-Host "------------------------------------------------------------"
    $toBeAddedHash | ForEach-Object { 
        $from = join-path (Join-Path $sourceBase $sourceReleativePath) $_.Key
        $to = Join-Path (Join-Path $pluginBase $pluginRelativePath) $_.Key
        write-host "Copying $from to $to"
        copy-item -force ($from) ($to) 

        $pluginPath = Join-Path $pluginBase "plugin.xml"
        $srcAttribute = (Join-Path $pluginRelativePath $_.Key).Replace('\','/')
        $targetAttribute = $sourceReleativePath.Replace('\','/')
        
        Add-CordovaPlugin-SourceToXml $pluginPath $srcAttribute $targetAttribute        
    }

    Write-Host "------------------------------------------------------------"
    Write-Host "To be Deleted"
    Write-Host "------------------------------------------------------------"
    $toBeDeletedHash

    Write-Host "------------------------------------------------------------"
    Write-Host "To be Copied"
    Write-Host "------------------------------------------------------------"
    $toBeCopiedHash
}

# Clear screen
clear-host


# Delete the workspace folder
$original = "C:\tmp\ps-workspace\foldersync\original"
$workspace = "C:\tmp\ps-workspace\foldersync\workspace"
if (test-path $workspace)
{
    Write-Host "Deleting existing workspace"
    Remove-Item -Recurse -Force C:\tmp\ps-workspace\foldersync\workspace
}

# Copy from Original to Workspace
copy-item -Recurse $original $workspace

$sourceBase = "C:\tmp\ps-workspace\foldersync\workspace\source"
$pluginBase = "C:\tmp\ps-workspace\foldersync\workspace\destination"
Update-CordovaPlugin $sourceBase "src\com\red_folder\phonegap\plugin\backgroundservice" $pluginBase "src\android" "*.java"


######-------------------------------------------
<#
$sourceHash.GetEnumerator() | Where-Object { $destinationHash.ContainsKey($_.Key) -and {Compare-Object $(Get-Content $_.Value.Directory + "\" + $_.Name) $(Get-Content $destinationHash.Item($_.Key).Directory + "\" + $destinationHash.Item($_.Key).Name) -eq $null }}

$sourceHash.GetEnumerator() | Where-Object { $destinationHash.ContainsKey($_.Key) } | Compare-Object $(Get-Content -path {$_.Value.Directory.ToString() + "\" + $_.Value.Name}) $(Get-Content -path {$destinationHash.Item($_.Key).Directory.ToString() + "\" + $destinationHash.Item($_.Key).Name})



$sourceHash.GetEnumerator() | Where-Object { $destinationHash.ContainsKey($_.Key) } | Get-CordovaPluginFileDifferences $_.Value.Directory.ToString() + "\" + $_.Value.Name $destinationHash.Item($_.Key).Directory.ToString() + "\" + $destinationHash.Item($_.Key).Name



$sourceHash.GetEnumerator() | Where-Object { $destinationHash.ContainsKey($_.Key) } | Get-CordovaPluginFileDifferences "$_.Value.Directory.ToString()\$_.Value.Name" "$destinationHash.Item($_.Key).Directory.ToString()\$destinationHash.Item($_.Key).Name"


$sourceHash.GetEnumerator() | Where-Object { $destinationHash.ContainsKey($_.Key) } | Get-CordovaPluginFileDifferences (Join-Path $_.Value.Directory $_.Value.Name) (Join-Path $destinationHash.Item($_.Key).Directory $destinationHash.Item($_.Key).Name)


$sourceHash.GetEnumerator() | Where-Object { $destinationHash.ContainsKey($_.Key) } | Get-CordovaPluginFileDifferences $_.Value $_.Value #$destinationHash.Item($_.Key)
#>


######-------------------------------------------

<#
function Get-CordovaPluginDifferentFiles($fileInfo1, $fileInfo2)
{
    $results = @()

    foreach ($file in $fileInfo1.GetEnumerator)
    {
        if ($fileInfo2.ContainsKey($file.Key))
        {
            $results += $file;
        }
    }

    return $results;
}

$sourceHash.GetEnumerator() | Where-Object { $destinationHash.ContainsKey($_.Key) } | Get-CordovaPluginDifferentFiles $_Value {$destinationHash.Item($_.Key)}
#>

<#
function Get-CordovaPluginFileDifferences($file1, $file2)
{
Write-Host ($file1 | Format-List | Out-String)
Write-Host ({$file2} | Format-List | Out-String)
    $filename1 = Join-Path $file1.Directory $file1.Name
    $filename2 = Join-Path $file2.Directory $file2.Name

    Compare-Object $(Get-Content -path $filename1) $(Get-Content -path $filename2)
}
#>

######-------------------------------------------


#$sourceHash.GetEnumerator() | Where-Object { $destinationHash.ContainsKey($_.Key) } | 

######-------------------------------------------

# Get-ChildItem -Recurse -Path "source" -filter "*.java" | select-object "Name", "Directory", @{Name="RelativePath"; expression={$_.Directory.ToString().Replace($PWD.ToString(),"") + "\" + $_.Name}}

#
#$sourceFolder = Get-ChildItem -Recurse -Path "source" -filter "*.java"
#$sourceFolder
#
#$destinationFolder = Get-ChildItem -Recurse -Path "destination" -filter "*.java"
#$destinationFolder
#
#function Is-In
#{
#    [CmdletBinding()]
#    param (
#        [Parameter(Mandatory=$true,
#                   ValueFromPipeline=$true,
#                   Position=0)]
#        $file, 
#        [Parameter(Mandatory=$true,
#                   ValueFromPipeline=$true,
#                   Position=0)]
#        $fileList 
#    )
#
#    process {
#        return $file.Name
#    }
#}

#$sourceFolder | Is-In


######-------------------------------------------


<#
$sourceHash.GetEnumerator() | Where-Object { $destinationHash.ContainsKey($_.Key) } | Join-Path -path $_ -childpath $_.Value.Name

$sourceHash.GetEnumerator() | Join-Path -path {$_.Value.Description} -childpath $_.Value.Name

$sourceHash.GetEnumerator() | Write-Host ({$_.Value} | Format-List | Out-String)


$sourceHash.GetEnumerator() | Where-Object { $destinationHash.ContainsKey($_.Key) } | {Compare-Object $($_) $($_)

$sourceHash.GetEnumerator() | Where-Object { $destinationHash.ContainsKey($_.Key) } 


$tmp = $sourceHash.GetEnumerator() | Where-Object { $destinationHash.ContainsKey($_.Key) } #| select-object @{Name="Fullname"; Value={$_.Value}}

$tmp.GetEnumerator() | Get-Content -path {$_.Value.Directory.ToString() + "\" + $_.Value.Name}


$tmp.GetEnumerator() | select-object Value | Get-Member

$sourceHash.GetEnumerator() | Where-Object { $destinationHash.ContainsKey($_.Key) } | Write-Host $_.Value

foreach ($i in $sourceHash.GetEnumerator())
{
    Write-Host $i.Value.Directory
    Write-Host $i.Value.Name
    #Write-Host ($i.Value | Format-List | Out-String)
}

get-content "Something"



#$sourceList = Get-ChildItem -Recurse -Path $sourceFolder -filter "*.java" | add-member -MemberType ScriptProperty -Name RelativePath –Value {$this.Directory.ToString().Replace($sourceFolder,"") + "\" + $this.Name} -PassThru
#$sourceList
$sourceHash = @{}
Get-ChildItem -Recurse -Path $sourceFolder -filter "*.java" | ForEach-Object { $sourceHash.Add($_.Directory.ToString().Replace($sourceFolder,"") + "\" + $_.Name, $_) }
$sourceHash

$destinationFolder = $PWD.ToString() + "\destination"
$destinationList = Get-ChildItem -Recurse -Path $destinationFolder -filter "*.java" | add-member -MemberType ScriptProperty -Name RelativePath –Value {$this.Directory.ToString().Replace($destinationFolder,"") + "\" + $this.Name} -PassThru
$destinationList


$x = $destinationList | ForEach-Object { $_.RelativePath}

$x

$sourceList | Where-Object { @{Files= $destinationList | ForEach-Object { $_.RelativePath }} -contains $_.RelativePath }

$sourceList | Where-Object { $true}



$sourceList | where-object { $_.RelativePath.Contains("NewFile")} 


Write-Host $sourceList




Get-ChildItem -Recurse -Path $sourceFolder -filter "*.java" | add-member -NotePropertyName Test –NotePropertyValue {{$_.Directory.ToString().Replace($sourceFolder,"") + "\" + $_.Name}} -PassThru | Select-Object Test

Get-ChildItem -Recurse -Path $sourceFolder -filter "*.java" | add-member -MemberType ScriptProperty -Name Test –Value {$this.Directory.ToString().Replace($sourceFolder,"") + "\" + $this.Name} -PassThru | Select-Object Test

@{Test={"a"+1}}


#>

