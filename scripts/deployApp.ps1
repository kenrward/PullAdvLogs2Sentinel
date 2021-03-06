
$today=Get-Date -Format "MM-dd-yyyy"
$deploymentName="ExampleDeployment"+"$today"
$resoureceGroupName = "AA100kewar"
$location = "EastUS"

New-AzResourceGroup -Name $resoureceGroupName -Location $location

# Deploy Bicep
$outputs = New-AzResourceGroupDeployment -Name $deploymentName -ResourceGroupName $resoureceGroupName -TemplateFile ..\main.bicep -TemplateParameterFile ..\parameters.json

# Get Outpus from Deployment
foreach ($key in $outputs.Outputs.keys) {
    switch ($key) {
    "strStrAccount" { $strStrAccount = $outputs.Outputs[$key].value }
    "strFuncAppName" { $funcAppName = $outputs.Outputs[$key].value }
    }
}


# Seed Storage table with initial values
$strkey = Get-AzStorageAccountKey -ResourceGroupName $resoureceGroupName -AccountName $strStrAccount | Where-Object {$_.KeyName -eq "key1"}
$ctx = New-AzStorageContext -StorageAccountName $strStrAccount -StorageAccountKey $strkey.Value
$tableName = "LastRead"
New-AzStorageTable -Name $tableName -Context $ctx

$cloudTable = (Get-AzStorageTable -Name $tableName -Context $ctx).CloudTable

$lastRead = (Get-Date).addDays(-30)

$partitionKey1 = "AdvHuntingTables"
Add-AzTableRow  -table $cloudTable -partitionKey $partitionKey1 -rowKey ("1") -property @{"advTableName"="EmailEvents";"LastRead"=$lastRead}
Add-AzTableRow  -table $cloudTable -partitionKey $partitionKey1 -rowKey ("2") -property @{"advTableName"="EmailAttachmentInfo";"LastRead"=$lastRead}
Add-AzTableRow  -table $cloudTable -partitionKey $partitionKey1 -rowKey ("3") -property @{"advTableName"="EmailUrlInfo";"LastRead"=$lastRead}
Add-AzTableRow  -table $cloudTable -partitionKey $partitionKey1 -rowKey ("4") -property @{"advTableName"="EmailPostDeliveryEvents";"LastRead"=$lastRead}
Add-AzTableRow  -table $cloudTable -partitionKey $partitionKey1 -rowKey ("5") -property @{"advTableName"="CloudAppEvents";"LastRead"=$lastRead}

# Validate the Function App has access to KeyVault
# Publish-AzWebapp -ResourceGroupName $resoureceGroupName -Name $funcAppName -ArchivePath "https://github.com/kenrward/PullAdvLogs2Sentinel/blob/master/Deploy.zip?raw=true"
