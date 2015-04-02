set-strictmode -version 2.0

function Get-CordovaPluginFileHash($baseFolder, $relativePath, $filter)
{
    $fileHash = @{}
    Get-ChildItem -Path (Join-Path $baseFolder $relativePath) -filter $filter | ForEach-Object { $fileHash.Add($_.Name, $_) }
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

function Add-CordovaPlugin-AssetToXml($pluginPath, $srcAttribute, $targetAttribute)
{
        $xml =  Open-CordovaPlugin-Xml $pluginPath
        
        $node = $xml.CreateElement("asset", $xml.DocumentElement.NamespaceURI)
        $node.SetAttribute("src",  $srcAttribute)
        $node.SetAttribute("target", $targetAttribute)
        $xml.plugin.platform.AppendChild($node) | Out-Null        
        
        Close-CordovaPlugin-Xml $pluginPath $xml
}

function Add-CordovaPlugin-SourceToXml($pluginPath, $srcAttribute, $targetAttribute)
{
        $xml =  Open-CordovaPlugin-Xml $pluginPath
        
        $node = $xml.CreateElement("source-file", $xml.DocumentElement.NamespaceURI)
        $node.SetAttribute("src",  $srcAttribute)
        $node.SetAttribute("target-dir", $targetAttribute)
        $xml.plugin.platform.AppendChild($node) | Out-Null        
        
        Close-CordovaPlugin-Xml $pluginPath $xml
}

function Add-CordovaPlugin-ModuleToXml($pluginPath, $srcAttribute, $moduleName)
{
        $xml =  Open-CordovaPlugin-Xml $pluginPath
        
        $node = $xml.CreateElement("js-module", $xml.DocumentElement.NamespaceURI)
        $node.SetAttribute("src",  $srcAttribute)
        $node.SetAttribute("name", $moduleName)
        $xml.plugin.platform.AppendChild($node) | Out-Null        
        
        Close-CordovaPlugin-Xml $pluginPath $xml
}

function Remove-CordovaPlugin-AssetToXml($pluginPath, $srcAttribute)
{
        $xml =  Open-CordovaPlugin-Xml $pluginPath
        
        $node = $xml.plugin.platform.asset | where-object { $_.src -eq $srcAttribute }
        if ($node -ne $null)
        {
            $result = $xml.plugin.platform.RemoveChild($node)
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

function Remove-CordovaPlugin-SourceToXml($pluginPath, $srcAttribute)
{
        $xml =  Open-CordovaPlugin-Xml $pluginPath
        
        $node = $xml.plugin.platform.'source-file' | where-object { $_.src -eq $srcAttribute }
        if ($node -ne $null)
        {
            $result = $xml.plugin.platform.RemoveChild($node)
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

function Remove-CordovaPlugin-ModuleToXml($pluginPath, $srcAttribute)
{
        $xml =  Open-CordovaPlugin-Xml $pluginPath
        
        $node = $xml.plugin.platform.'js-module' | where-object { $_.src -eq $srcAttribute }
        if ($node -ne $null)
        {
            $result = $xml.plugin.platform.RemoveChild($node)
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

function Update-CordovaPlugin-ContentForConfigXml($xmlPath, $srcAttribute)
{
        $xml =  Open-CordovaPlugin-Xml $xmlPath
        
        $node = $xml.widget.content
        if ($node -ne $null)
        {
            $result = $node.SetAttribute("src", $srcAttribute);
            write-host "Node amended"
        } else {
            write-host "Node not found"
        }

        Close-CordovaPlugin-Xml $xmlPath $xml
}

function Update-CordovaPlugin-DependencyForXml($xmlPath, $idAttribute, $urlAttribute)
{
        $xml =  Open-CordovaPlugin-Xml $xmlPath

        $node = $xml.plugin.dependency | where-object { $_.id -eq $idAttribute }
        if ($node -ne $null)
        {
            $result = $node.SetAttribute("url", $urlAttribute)
            write-host "Node amended"
        } else {
            write-host "Node not found"
        }
        
        Close-CordovaPlugin-Xml $xmlPath $xml
}

function Close-CordovaPlugin-Xml($pluginPath, $xml)
{
    $xml.Save($pluginPath)
}

function Commit-CordovaPlugin($pluginBase, $commitMessage)
{
    Push-Location $pluginBase
    git add *
    git commit -m $commitMessage
    Pop-Location
}

function Revert-CordovaPlugin($pluginBase)
{
    Push-Location $pluginBase
    git checkout *
    Pop-Location
}

function Update-CordovaPlugin-Source($sourceBase, $sourceReleativePath, $pluginBase, $pluginRelativePath, $fileType, $jsmodule, [switch]$isModule, [switch]$isAsset, [switch]$isSource)
{
    Write-Host "------------------------------------------------------------"
    Write-Host "Sync'ing" (Join-Path $sourceReleativePath $fileType)
    Write-Host "------------------------------------------------------------"

    $sourceHash = Get-CordovaPluginFileHash $sourceBase $sourceReleativePath $fileType

    $pluginHash = Get-CordovaPluginFileHash $pluginBase $pluginRelativePath $fileType

    $toBeAddedHash = $sourceHash.GetEnumerator() | Where-Object { $pluginHash.ContainsKey($_.Key) -eq $false}
    $toBeDeletedHash = $pluginHash.GetEnumerator() | Where-Object { $sourceHash.ContainsKey($_.Key) -eq $false}
    $toBeCopiedHash = (Get-CordovaPluginDifferentFiles $sourceHash $pluginHash).GetEnumerator()

    $pluginPath = Join-Path $pluginBase "plugin.xml"
 
    #Write-Host "------------------------------------------------------------"
    #Write-Host "To be Added"
    #Write-Host "------------------------------------------------------------"
    $toBeAddedHash | ForEach-Object { 
        $from = join-path (Join-Path $sourceBase $sourceReleativePath) $_.Key
        $to = Join-Path (Join-Path $pluginBase $pluginRelativePath) $_.Key
        
        if ((Test-Path (Join-Path $pluginBase $pluginRelativePath)) -eq $false) {
            New-Item -ItemType Directory -Path (Join-Path $pluginBase $pluginRelativePath) -Force
        }
        
        write-host "Copying $from to $to"
        copy-item -force ($from) ($to) 

        $srcAttribute = (Join-Path $pluginRelativePath $_.Key).Replace('\','/')
        $targetAttribute = $sourceReleativePath.Replace('\','/')

        if ($isModule.IsPresent)
        {        
            if ($jsmodule -ne $null)
            {
                Add-CordovaPlugin-ModuleToXml $pluginPath $srcAttribute $jsmodule
            } else {
                Write-Host "Error: Missing module name - $srcAttribute"
            }
        } else {
            if ($isAsset.IsPresent)
            {
                Add-CordovaPlugin-AssetToXml $pluginPath $srcAttribute $targetAttribute        
            } else {
                Add-CordovaPlugin-SourceToXml $pluginPath $srcAttribute $targetAttribute        
            }
        }
    }

    #Write-Host "------------------------------------------------------------"
    #Write-Host "To be Deleted"
    #Write-Host "------------------------------------------------------------"
    $toBeDeletedHash | ForEach-Object { 
        $toBeDeleted = Join-Path (Join-Path $pluginBase $pluginRelativePath) $_.Key
        write-host "Removing $toBeDeleted"
        remove-item $toBeDeleted

        $srcAttribute = (Join-Path $pluginRelativePath $_.Key).Replace('\','/')
        
        if ($isModule.IsPresent)
        {
            Remove-CordovaPlugin-ModuleToXml $pluginPath $srcAttribute
        } else {
            if ($isAsset.IsPresent)
            {
                Remove-CordovaPlugin-AssetToXml $pluginPath $srcAttribute
            } else {
                Remove-CordovaPlugin-SourceToXml $pluginPath $srcAttribute
            }
        }
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

    Update-CordovaPlugin-DependencyForXml (Join-Path $pluginBase "plugin.xml") "com.red_folder.phonegap.plugin.backgroundservice" "Test"
}

#Update-CordovaPlugin-InternalTest

# Sample usage
#(new-object Net.WebClient).DownloadString("https://raw.githubusercontent.com/Red-Folder/Cordova-Plugin-Build-Tools/master/PowerShell/Cordova-Plugin.ps1") | iex
