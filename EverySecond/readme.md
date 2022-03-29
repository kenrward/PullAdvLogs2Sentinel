## PROOF of CONCEPT ONLY
This code is a proof of concept to show how data can be pulled from M365 Advanced Hunting API to Azure Sentinel.  It is **NOT** prodcution ready code.  Author assumes no responsibility for its use nor implies any warranty.

# TimerTrigger - PowerShell

The `TimerTrigger` makes it incredibly easy to have your functions executed on a schedule. This sample demonstrates a simple use case of calling your function every 5 minutes.

## How it works

For a `TimerTrigger` to work, you provide a schedule in the form of a [cron expression](https://en.wikipedia.org/wiki/Cron#CRON_expression)(See the link for full details). A cron expression is a string with 6 separate expressions which represent a given schedule via patterns. The pattern we use to represent every 5 minutes is `0 */5 * * * *`. This, in plain text, means: "When seconds is equal to 0, minutes is divisible by 5, for any hour, day of the month, month, day of the week, or year".

## Learn more

This Function app is based off of https://github.com/Azure/Azure-Sentinel/tree/master/DataConnectors/O365%20Data.  It will connect to M365 in **GCC** to pull data from the Advanced Hunting APIs.  This function app will read the table names from Azure Table Storage and pull the events since the `lastRead` time.  If `lastRead` is NULL it will pull data from the last 30 days. The data that is pulled from the API is stored as a Custom Log in Azure Log Analytics.
