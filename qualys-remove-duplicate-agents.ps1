#Author: Julio Viana
#Created: 2021-05-16

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Function FindAssetByName ($AssetName)
{

# Creds
$username = "username"
$password = "password"
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $username,$password)))
$base = "https://qualysapi.qg2.apps.qualys.com"

# Headers
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Requested-With", 'powershell')
$headers.Add("Authorization","Basic {0}" -f $base64AuthInfo)


# List Assets with a Tag
$api = "qps/rest/2.0/search/am/hostasset/"
$body = @"
<?xml version="1.0" encoding="UTF-8" ?>
<ServiceRequest>
    <filters>
        <Criteria field="dnsHostName" operator="EQUALS">$AssetName</Criteria>
    </filters>
</ServiceRequest>
"@
$rsp = Invoke-RestMethod -Headers $headers -Uri "$base/$api" -Method Post -Body $body -ContentType "application/xml" 

return $rsp

}## End Function FindAssetByName



Function PurgeAssetByID ($AssetID)
{

# Creds
$username = "username"
$password = "password"
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $username,$password)))
$base = "https://qualysapi.qg2.apps.qualys.com"

# Headers
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Requested-With", 'powershell')
$headers.Add("Authorization","Basic {0}" -f $base64AuthInfo)


# List Assets with a Tag
$api = "qps/rest/2.0/uninstall/am/asset/$AssetID"
$body = @"
<?xml version="1.0" encoding="UTF-8" ?>
<ServiceRequest>
</ServiceRequest>
"@

$rsp = Invoke-RestMethod -Headers $headers -Uri "$base/$api" -Method Post -Body $body -ContentType "application/xml" 

return $rsp

}## End Function PurgeAssetByID



Function ExportAllAssets
{

# Creds
$username = "username"
$password = "password"

$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $username,$password)))
$base = "https://qualysapi.qg2.apps.qualys.com"

# Headers
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Requested-With", 'powershell')
$headers.Add("Authorization","Basic {0}" -f $base64AuthInfo)

#------------------------------------------------------------------------------------------------------------
# Asset Search Report - All
#------------------------------------------------------------------------------------------------------------

$api = "api/2.0/fo/report/asset/"
$body = "action=search&output_format=xml&use_tags=1&tag_set_by=name&tag_set_include=All+Assets"
$rsp = Invoke-RestMethod -Headers $headers -Uri "$base/$api" -Method Post -Body $body

$assets = @()  
ForEach ($asset in $rsp.ASSET_SEARCH_REPORT.HOST_LIST.HOST) {  
  $obj = New-Object PSObject  
  Add-Member -InputObject $obj -MemberType NoteProperty -Name IP -Value $asset.IP."#cdata-section"
  Add-Member -InputObject $obj -MemberType NoteProperty -Name DNS -Value $asset.DNS."#cdata-section"
  Add-Member -InputObject $obj -MemberType NoteProperty -Name NETBIOS -Value $asset.NETBIOS."#cdata-section"
  Add-Member -InputObject $obj -MemberType NoteProperty -Name OperatingSystem -Value $asset.OPERATING_SYSTEM."#cdata-section"

  $assets += $obj  
}  
$rsp = $assets 

return $rsp

}## End Function ExportAllAssets



$assets = ExportAllAssets

$duplicates = $assets | Where {$_.Netbios} | Group-Object -Property Netbios | Where-Object { $_.Group.OperatingSystem -like '*Windows*' } | Where-Object { $_.count -ge 2 } 

$to_purge = @()
ForEach ($asset in $duplicates) {
  $qualys_agent = FindAssetByName($asset.Name.toLower()) # Needed to retrieve AssetID
  if ($qualys_agent.ServiceResponse.count -eq '0') {$qualys_agent = FindAssetByName($asset.Name.ToUpper())}

  if ($qualys_agent.ServiceResponse.count -gt 0) {
    $to_purge += $qualys_agent.ServiceResponse.data.HostAsset
  }
} 

#Remove most recent Asset ID off the list 
$to_purge = $to_purge | sort name,id
$to_purge = $to_purge| Group-Object -Property name |Foreach-Object { ($_.Group)[0..($_.count-2)] }

$to_purge | ForEach-Object {$rsp = PurgeAssetByID($_.id)}

