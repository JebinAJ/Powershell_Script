# Provide the necessary credentials
$Secret = "parameter.secret"
$AppId = "parameter.appId"
$TenantId = "parameter.tenantId"
$SecurePassword = ConvertTo-SecureString $Secret -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $AppId, $SecurePassword
$myTeamsWebHook = #provide teamswebhookId

# Connect to Azure using the provided service principal credentials
Connect-AzAccount -ServicePrincipal -TenantId $TenantId -Credential $Credential

$AppRegistrations = Get-AzADApplication

# Define the threshold for endDateTime (next 30 days)
$EndDateTimeThreshold = (Get-Date).AddDays(30)

# Initialize an empty array to store the messages
$Messages = @()

# Iterate through each app registration
foreach ($AppRegistration in $AppRegistrations) {
    # Get the PasswordCredentials
    $PasswordCredentials = $AppRegistration.PasswordCredentials

    # Check if any PasswordCredentials are expiring within the threshold
    foreach ($PasswordCredential in $PasswordCredentials) {
        $EndDateTime = [DateTime]::Parse($PasswordCredential.endDateTime)
        if ($EndDateTime -lt $EndDateTimeThreshold) {
            $Message = "App Registration <b>$($AppRegistration.DisplayName)</b>: PasswordCredentialEndDate&Time <b>$($PasswordCredential.endDateTime)</b>"
            $Messages += $Message
        }
    }
}


# Split the messages into smaller chunks
$ChunkSize = 10
$MessageChunks = $Messages | Group-Object -Property { [math]::Floor($Messages.IndexOf($_) / $ChunkSize) } | ForEach-Object { $_.Group }

# Iterate over each message chunk and send separate requests
foreach ($MessageChunk in $MessageChunks) {
    # Create the payload for the Microsoft Teams message
    $Payload = @{
        "@type" = "MessageCard"
        "@context" = "http://schema.org/extensions"
        "themeColor" = "0078D7"
        "summary" = "App Registration PasswordCredentials Expiring Soon"
        "sections" = @(
            @{
                "activityTitle" = "App Registration PasswordCredentials Expiring Soon"
                "activitySubtitle" = "Expiring within the next 30 days"
                "facts" = @(
                    @{
                        "name" = "Expiring Credentials:"
                        "value" = $MessageChunk -join "`n"
                    }
                )
            }
        )
    } | ConvertTo-Json -Depth 4

    # Send the payload to the Microsoft Teams webhook
    Invoke-RestMethod -Uri $myTeamsWebHook -Method Post -Body $Payload -ContentType 'application/json'
}
