set-strictmode -version 2.0

function Get-CordovaPluginFileHash($baseFolder, $relativePath, $filter)
{
    $fileHash = @{}
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
        $xml.plugin.platform.AppendChild($sourceNode) | Out-Null        
        
        Close-CordovaPlugin-Xml $pluginPath $xml
}

function Add-CordovaPlugin-ModuleToXml($pluginPath, $srcAttribute, $moduleName)
{
        $xml =  Open-CordovaPlugin-Xml $pluginPath
        
        $moduleNode = $xml.CreateElement("js-module", $xml.DocumentElement.NamespaceURI)
        $moduleNode.SetAttribute("src",  $srcAttribute)
        $moduleNode.SetAttribute("name", $moduleName)
        $xml.plugin.platform.AppendChild($moduleNode) | Out-Null        
        
        Close-CordovaPlugin-Xml $pluginPath $xml
}

function Remove-CordovaPlugin-SourceToXml($pluginPath, $srcAttribute)
{
        $xml =  Open-CordovaPlugin-Xml $pluginPath
        
        $sourceNode = $xml.plugin.platform.'source-file' | where-object { $_.src -eq $srcAttribute }
        if ($sourceNode -ne $null)
        {
            $result = $xml.plugin.platform.RemoveChild($sourceNode)
            if ($result -ne $null)
            {
                write-host "Node deleted"
            } else {
                write-host "Node failed to delete"
            }
        } else {
            write-host "Node not found"
        }

        Close-CordovaPlugin-Xml $pluginPath $xml
}

function Close-CordovaPlugin-Xml($pluginPath, $xml)
{
    $xml.Save($pluginPath)
}

function Update-CordovaPlugin($sourceBase, $sourceReleativePath, $pluginBase, $pluginRelativePath, $fileType, $jsmodule)
{
    Write-Host "------------------------------------------------------------"
    Write-Host "Sync'ing" (Join-Path $sourceReleativePath $fileType)
    Write-Host "------------------------------------------------------------"

    $sourceHash = Get-CordovaPluginFileHash $sourceBase $sourceReleativePath $fileType

    $pluginHash = Get-CordovaPluginFileHash $pluginBase $pluginRelativePath $fileType

    $toBeAddedHash = $sourceHash.GetEnumerator() | Where-Object { $pluginHash.ContainsKey($_.Key) -eq $false}
    $toBeDeletedHash = $pluginHash.GetEnumerator() | Where-Object { $sourceHash.ContainsKey($_.Key) -eq $false}
    $toBeCopiedHash = (Get-CordovaPluginDifferentFiles $sourceHash $pluginHash).GetEnumerator()

    #Write-Host "------------------------------------------------------------"
    #Write-Host "To be Added"
    #Write-Host "------------------------------------------------------------"
    $toBeAddedHash | ForEach-Object { 
        $from = join-path (Join-Path $sourceBase $sourceReleativePath) $_.Key
        $to = Join-Path (Join-Path $pluginBase $pluginRelativePath) $_.Key
        write-host "Copying $from to $to"
        copy-item -force ($from) ($to) 

        $pluginPath = Join-Path $pluginBase "plugin.xml"
        $srcAttribute = (Join-Path $pluginRelativePath $_.Key).Replace('\','/')
        $targetAttribute = $sourceReleativePath.Replace('\','/')
        
        if ($jsmodule -ne $null)
        {
            Add-CordovaPlugin-ModuleToXml $pluginPath $srcAttribute $jsmodule
        } else {
            Add-CordovaPlugin-SourceToXml $pluginPath $srcAttribute $targetAttribute        
        }
    }

    #Write-Host "------------------------------------------------------------"
    #Write-Host "To be Deleted"
    #Write-Host "------------------------------------------------------------"
    $toBeDeletedHash | ForEach-Object { 
        $toBeDeleted = Join-Path (Join-Path $pluginBase $pluginRelativePath) $_.Key
        write-host "Removing $toBeDeleted"
        remove-item $toBeDeleted

        $pluginPath = Join-Path $pluginBase "plugin.xml"
        $srcAttribute = (Join-Path $pluginRelativePath $_.Key).Replace('\','/')
        
        Remove-CordovaPlugin-SourceToXml $pluginPath $srcAttribute
    }

    #Write-Host "------------------------------------------------------------"
    #Write-Host "To be Copied"
    #Write-Host "------------------------------------------------------------"
    $toBeCopiedHash | ForEach-Object { 
        $from = join-path (Join-Path $sourceBase $sourceReleativePath) $_.Key
        $to = Join-Path (Join-Path $pluginBase $pluginRelativePath) $_.Key
        write-host "Copying $from to $to"
        copy-item -force ($from) ($to) 
    }
}

function Update-CordovaPlugin-InternalTest
{
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
    Update-CordovaPlugin $sourceBase "src\com\red_folder\phonegap\plugin\backgroundservice" $pluginBase "aidl\android" "*.aidl"
    Update-CordovaPlugin $sourceBase "www" $pluginBase "www" "backgroundService.js" -jsmodule "BackgroundService"
    Update-CordovaPlugin $sourceBase "www" $pluginBase "www" "add.js" -jsmodule "BackgroundService"
}

#Update-CordovaPlugin-InternalTest
