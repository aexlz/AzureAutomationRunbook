param
(
    [Parameter(Mandatory=$true)]
    [String] $UPN
)

#Construct Webhook-Body
$Names  = @(
            @{ UPN=$UPN}
        )

#Validation of URL proper URL-Format        
$body = ConvertTo-Json -InputObject $Names

$webhookURI = "<ENTER the secret WebhookURI here>"
$response = Invoke-WebRequest -Method Post -Uri $webhookURI -Body $body -UseBasicParsing

if ($response.StatusCode -eq "202"){
    Write-Output "Webhook-URL called successfully!"
}else{
    Write-Output "Error! could not call URL!"
    exit
}


#isolate job ID
$jobid = (ConvertFrom-Json ($response.Content)).jobids[0]
$automationAccount = "<ENTER Name of automationAccount here>"
$resourceGroup = "<ENTER Name of resourceGroup here>"

#Loop as long as the status is not Running
$doLoop = $true
While ($doLoop) {
  $job = Get-AzAutomationJob -ResourceGroupName $resourceGroup `
    -AutomationAccountName $automationAccount -Id $jobid
  $status = $job.Status
  $doLoop = (($status -ne "Completed") -and ($status -ne "Failed") -and ($status -ne "Suspended") -and ($status -ne "Stopped"))
}

#Interrupt when not completed
if($status -ne "Completed"){
    Write-Output "The Automation script on Azure did not run properly. Consult the admin!"
    exit
}

# Get output of script
$responseOutput = Get-AzAutomationJobOutput `
    -AutomationAccountName $automationAccount `
    -Id $jobid `
    -ResourceGroupName $resourceGroup `
    -Stream Output
Write-Output $responseOutput.Summary

