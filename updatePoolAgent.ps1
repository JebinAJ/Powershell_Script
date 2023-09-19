$personalAccessToken = "${{ parameters.personalAccessToken }}"
              $organizationName = "${{ parameters.organizationName }}"
              $targetAgentPoolName = "vmss-${{ parameters.environment }}"

              # Construct the API URL to list agent pools
              $apiUrl = "https://dev.azure.com/$organizationName/_apis/distributedtask/pools?api-version=7.2-preview.1"

              # Create a header with the PAT
              $headers = @{
                  Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($personalAccessToken)"))
              }

              # Send a GET request to list agent pools
              $response = Invoke-RestMethod -Method 'Get' -Uri $apiUrl -Headers $headers 

              # Find the agent pool with the target name
              $targetAgentPool = $response.value | Where-Object { $_.name -eq $agentPoolName }

              if ($targetAgentPool -ne $null) {
                  # Write-Host "Agent Pool Name: $($targetAgentPool.name), Agent Pool ID: $($targetAgentPool.id)"

                  # Construct the API URL to list agents in the target pool
                  $agentsApiUrl = "https://dev.azure.com/$organizationName/_apis/distributedtask/pools/$($targetAgentPool.id)/agents?api-version=7.2-preview.1"
                  
                  # Send a GET request to list agents in the target pool
                  $agentsResponse = Invoke-RestMethod -Uri $agentsApiUrl -Headers $headers -Method Get
                  #$agentsResponse.value

                  # Iterate through the agents in the target pool and disable them
                  foreach ($agent in $agentsResponse.value) {
                      # Construct the API URL to update the agent's enabled status
                      $updateAgentApiUrl = "https://dev.azure.com/$organizationName/_apis/distributedtask/pools/$($targetAgentPool.id)/agents/$($agent.id)?api-version=7.2-preview.1"
                      $updateAgentApiUrl
                      # Define the agent update body to disable it
                      $agentUpdateBody = @{
                          id =  $agent.id
                          enabled = $false
                      } | ConvertTo-Json 

                      # Send a PATCH request to disable the agent
                      Invoke-RestMethod -Method 'Patch' -Uri $updateAgentApiUrl -Body $agentUpdateBody -Headers $headers -ContentType 'application/json'

                      Write-Host "Agent '$($agent.name)' in Agent Pool '$agentPoolName' has been disabled."
                  }
              } else {
                  Write-Host "Agent Pool '$agentPoolName' not found."
              }
