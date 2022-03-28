# https://docs.microsoft.com/en-us/azure/storage/tables/table-storage-how-to-use-powershell
# set Storage String

$ctx = New-AzStorageContext -ConnectionString $azstoragestring
$tableName = "LastRead"
New-AzStorageTable –Name $tableName –Context $ctx

$cloudTable = (Get-AzStorageTable –Name $tableName –Context $ctx).CloudTable

$partitionKey1 = "AdvHuntingTables"
Add-AzTableRow  -table $cloudTable -partitionKey $partitionKey1 -rowKey ("1") -property @{"advTableName"="EmailEvents";"LastRead"=""}
Add-AzTableRow  -table $cloudTable -partitionKey $partitionKey1 -rowKey ("2") -property @{"advTableName"="EmailAttachmentInfo";"LastRead"=""}
Add-AzTableRow  -table $cloudTable -partitionKey $partitionKey1 -rowKey ("3") -property @{"advTableName"="EmailUrlInfo";"LastRead"=""}
Add-AzTableRow  -table $cloudTable -partitionKey $partitionKey1 -rowKey ("4") -property @{"advTableName"="EmailPostDeliveryEvents";"LastRead"=""}

$rowReturn = Get-AzTableRow -table $cloudTable -ColumnName "advTableName" -value "EmailEvents" -operator Equal