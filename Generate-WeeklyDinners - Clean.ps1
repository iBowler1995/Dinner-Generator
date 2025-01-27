[CmdletBinding()]
param(
    [Parameter(Mandatory = $True)]
    [String]$CounthPath, #txt file to track unique dinners
    [Parameter(Mandatory = $true)]
    [String]$DinnerPath, #json file with dinner details
    [Parameter(Mandatory = $True)]
    [String]$Id
)

Function Add-GCalendarEvent{

     <#
		IMPORTANT:
        ===========================================================================
        This script is provided 'as is' without any warranty. Any issues stemming 
        from use is on the user.
        ===========================================================================
		.DESCRIPTION
		Adds an event to your Google calendar.
		===========================================================================
		.PARAMETER StartTime
		Timestamp for event start time, DateTime object.
		.PARAMETER EndTime
		Timestamp for event end time, DateTime object.
        .PARAMETER Summary
        Event name
        .PARAMETER Description
        Event description
        .PARAMETER CalendarId
        Your Google Calendar Id. Open calendar settings and copy CalendarId under "Integrate" section.
		===========================================================================
		.EXAMPLE
		$Timestamp = ((Get-Date).AddDays(3)).Date
        $StartTime = $Timestamp.AddHours(12)
        $EndTime = $StartTime.AddHours(2)
        Add-GCalendarEvent -StartTime $StartTime -EndTime $EndTime -Summary "My Event" -Description "Scheduled with Bill and Ashley." -CalendarId "{mycalendarid}" <--- Adds a calendar event 3 days from now at noon, which lasts 2 hours long.
	#>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [datetime]$StartTime,
        [Parameter(Mandatory = $true)]
        [datetime]$EndTime,
        [Parameter(Mandatory = $true)]
        [string]$Summary,
        [Parameter(Mandatory = $true)]
        [string]$Description,
        [Parameter(Mandatory = $true)]
        [string]$CalendarId
    )
    
    Function Get-GoogleAccessToken{

        <#
            IMPORTANT:
            ===========================================================================
            This script is provided 'as is' without any warranty. Any issues stemming 
            from use is on the user.
            ===========================================================================
            .DESCRIPTION
            Retrieves and returns an access token for Google Calendar API. (Can be edited to change scope)
            ===========================================================================
            .PARAMETER CredentialsFile
            Credentials JSON file for your service account downloaded from Google Cloud Console
            ===========================================================================
            .EXAMPLE
            Get-GoogleAccessToken -Credentials File C:\Temp\Creds.json <--- Gets you your token
        #>
        
        [CmdletBinding()]
        param (

            [Parameter(Mandatory = $True)]
            [String]$CredentialsFile

        )

        #Loading the credentials file
        Try{
            $ServiceAccountCredentials = Get-Content -Raw -Path $CredentialsFile | ConvertFrom-Json
        }
        Catch {
            Write-Host "Error at line $($_.InvocationInfo.ScriptLineNumber) while loading credentials file: $($_.Exception.Message)"
        }

        #Declaring variables
        $ClientEmail = $ServiceAccountCredentials.client_email
        $PrivateKey = $ServiceAccountCredentials.private_key
        $TokenUri = $ServiceAccountCredentials.token_uri
        $Scope = "https://www.googleapis.com/auth/calendar"

        Try{
            #Formatting the private key
            $PrivateKeyFormatted = $PrivateKey -replace "-----BEGIN PRIVATE KEY-----", ""
            $PrivateKeyFormatted = $PrivateKeyFormatted -replace "-----END PRIVATE KEY-----", ""
            $PrivateKeyFormatted = $PrivateKeyFormatted -replace "\s+", ""  #Removes line breaks and whitespace (this was new to me, so I added this comment)
            $PrivateKeyBytes = [Convert]::FromBase64String($PrivateKeyFormatted)
        }
        Catch {
            Write-Host "Error at line $($_.InvocationInfo.ScriptLineNumber) while formatting the priave key: $($_.Exception.Message)"
        }

        #Creating the JSON Web Token header (I can't lie, I had to steal these next few bits from Stack Exchange. This was a new token format for me)
        $Header = @{
            alg = "RS256"
            typ = "JWT"
        }
        $HeaderJson = $Header | ConvertTo-Json -Depth 10 -Compress
        $HeaderBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($HeaderJson))

        #Creating the JWT claims 
        $Now = [int][double]::Parse((Get-Date -UFormat %s))
        $Expiration = $Now + 3600  # Token valid for 1 hour
        $ClaimSet = @{
            iss = $ClientEmail
            scope = $Scope
            aud = $TokenUri
            exp = $Expiration
            iat = $Now
        }
        $ClaimSetJson = $ClaimSet | ConvertTo-Json -Depth 10 -Compress
        $ClaimSetBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($ClaimSetJson))

        Try{
            #Signing the JWT with the private key
            $DataToSign = "$HeaderBase64.$ClaimSetBase64"
            $CryptoServiceProvider = New-Object System.Security.Cryptography.RSACryptoServiceProvider
            $CryptoServiceProvider.ImportPkcs8PrivateKey($PrivateKeyBytes, [ref]0)
        }
        Catch {
            Write-Host "Error at line $($_.InvocationInfo.ScriptLineNumber) while signing token: $($_.Exception.Message)"
        }

        $SignatureBytes = $CryptoServiceProvider.SignData(
            [System.Text.Encoding]::UTF8.GetBytes($DataToSign),
            [System.Security.Cryptography.HashAlgorithmName]::SHA256,
            [System.Security.Cryptography.RSASignaturePadding]::Pkcs1
        )
        $SignatureBase64 = [Convert]::ToBase64String($SignatureBytes)

        #Constructing the token
        $Jwt = "$DataToSign.$SignatureBase64"

        Try{
            #Finally, we request the token and pray we got it right
            $TokenResponse = Invoke-RestMethod -Uri $TokenUri -Method Post -Body @{
                grant_type = "urn:ietf:params:oauth:grant-type:jwt-bearer"
                assertion = $Jwt
            } -ContentType "application/x-www-form-urlencoded"

            $AccessToken = $TokenResponse.access_token

            Return $AccessToken
        }
        Catch {
            Write-Host "Error at line $($_.InvocationInfo.ScriptLineNumber) while submitting token request: $($_.Exception.Message)"
        }

    }

    #Converting timestamps to ISO 8061 and retrieving our access token
    $StartTimeISO = $StartTime.ToString("yyyy-MM-ddTHH:mm:ssK")
    $EndTimeISO = $EndTime.ToString("yyyy-MM-ddTHH:mm:ssK")
    $Token = Get-GoogleAccessToken -CredentialsFile "C:\Temp\API_SA.json"
    
    Try{
        #Creating the JSON payload
        $Event = @{
            summary = $Summary
            description = $Description
            start = @{
                dateTime = $StartTimeISO
            }
            end = @{
                $EndTimeISO
            }
        } | ConvertTo-Json -Depth 10
    }
    Catch {
        Write-Host "Error at line $($_.InvocationInfo.ScriptLineNumber) while creating payload: $($_.Exception.Message)"
    }

    #Creating the URI and headers
    $CreateEventUri = "https://www.googleapis.com/calendar/v3/calendars/$CalendarId/events"
    $Headers = @{
        Authorization = "Bearer $Token"
        "Content-Type" = "application/json"
    }

    Try{
        #Submitting the POST request and creating the event
        $Response = Invoke-RestMethod -Uri $CreateEventUri -Method Post -Headers $Headers -Body $Event

        #Linking to the event for confirmation
        Write-Host "Event created successfully! View it here: $($Response.htmlLink)"
    }
    Catch {
        Write-Host "Error at line $($_.InvocationInfo.ScriptLineNumber) while submitting event request: $($_.Exception.Message)"
    }


}

#############################################################################################################

Function Get-Dinners {
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$DinnerCount,
        [Parameter(Mandatory = $true)]
        [String]$filePath,
        [Parameter(Mandatory = $true)]
        [String]$JsonPath
    )

    #Determining the past dinner selections, to avoid repeats
    $existingNumbers = Get-Content $filePath | ForEach-Object { [int]$_ }

    #Loading dinner JSON and counting dinners
    $dinners = Get-Content -Raw -Path $JsonPath | ConvertFrom-Json
    $totalDinners = $dinners.Count

    #Generating unique random numbers not already in the file, using the number of dinners. JSON is base 0, so the first dinner in the list is 0 in the index
    $randomNumbers = @()
    while ($randomNumbers.Count -lt $DinnerCount) {
        $newNumber = Get-Random -Minimum 0 -Maximum $totalDinners
        if ($newNumber -notin $existingNumbers -and $newNumber -notin $randomNumbers) {
            $randomNumbers += $newNumber
        }
    }

    #Adding the new numbers to our count
    $randomNumbers | ForEach-Object { $_ } | Add-Content -Path $filePath

    #Checking number of dinner selections. After 15, we allow the first 5 to go back into rotation
    if ($existingNumbers.Count -ge 15) {
        $updatedNumbers = $existingNumbers[5..($existingNumbers.length - 1)]
        $updatedNumbers | Set-Content -Path $filePath
    }

    #Getting meals corresponding with the generated numbers
    $selectedDinners = $randomNumbers | ForEach-Object { $dinners[$_].Name }

    #Determining if pulled pork has been selected. If so, we need to make sure there are two pulled pork dinners
    $pulledPorkDinners = $dinners | Where-Object { $_.Tag -eq "PulledPork" }
    $selectedPulledPork = $selectedDinners | Where-Object { $pulledPorkDinners.Name -contains $_ }

    if ($selectedPulledPork.Count -eq 1) {
        $remainingPulledPork = $pulledPorkDinners | Where-Object { $selectedPulledPork -notcontains $_.Name }
        if ($remainingPulledPork.Count -gt 0) {
            $additionalPulledPork = $remainingPulledPork | Get-Random
            Write-Host "Adding an additional pulled pork dinner: $($additionalPulledPork.Name)"

            #Replacing a random non-pulled pork dinner with the additional pulled pork dinner
            $nonPulledPorkDinners = $selectedDinners | Where-Object { $pulledPorkDinners.Name -notcontains $_ }
            if ($nonPulledPorkDinners.Count -gt 0) {
                $dinnerToReplace = $nonPulledPorkDinners | Get-Random
                $selectedDinners[$selectedDinners.IndexOf($dinnerToReplace)] = $additionalPulledPork.Name
                Write-Host "Replaced dinner: $dinnerToReplace with $($additionalPulledPork.Name)"
            }
        }
    }

    #Returning the selected dinners
    return $selectedDinners
}

#############################################################################################################

Function Get-Ingredients {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SelectedDinners,
        [Parameter(Mandatory = $true)]
        [string]$JsonFile
    )

    #Loading the JSON file
    $dinners = Get-Content -Raw -Path $JsonFile | ConvertFrom-Json

    #Creating a lookup hashtable for faster access
    $dinnerLookup = @{}
    foreach ($dinner in $dinners) {
        $dinnerLookup[$dinner.Name] = $dinner
    }

    #Initializng hash tables for main and staple ingredients
    $aggregatedIngredients = @{}
    $aggregatedStaples = @{}

    #Looping through each selected dinner
    foreach ($dinner in $SelectedDinners) {
        Write-Output "Processing Dinner: $dinner"

        #Getting corresponding dinner
        if ($dinnerLookup.ContainsKey($dinner)) {
            $row = $dinnerLookup[$dinner]

            #Looping through ingredients
            foreach ($ingredient in $row.Ingredients) {
                $name = $ingredient.Name
                $quantity = $ingredient.Quantity -as [double]
                $unit = $ingredient.Unit

                #Assigning defaults for quantity and units. This is more of a quirk for me that I added. If I don't specify quantity it assumes a quantity of 1, if I don't specify a unit it sets unit to Null/empty to avoid weird errors.
                if (-not $quantity -or $quantity -eq $null) { $quantity = 1 }
                if (-not $unit) { $unit = "" }

                #Aggregating staple and regular ingredients
                if ($ingredient.Staple -eq $true) {
                    if ($aggregatedStaples.ContainsKey($name)) {
                        $aggregatedStaples[$name].Quantity += $quantity
                    } else {
                        $aggregatedStaples[$name] = @{
                            Quantity = $quantity
                            Unit = $unit
                        }
                    }
                } else {
                    if ($aggregatedIngredients.ContainsKey($name)) {
                        $aggregatedIngredients[$name].Quantity += $quantity
                    } else {
                        $aggregatedIngredients[$name] = @{
                            Quantity = $quantity
                            Unit = $unit
                        }
                    }
                }
            }
        } else {
            Write-Output "No match found for: $dinner"
        }
    }

    #Formatting the ingredient list
    $ingredientsList = $aggregatedIngredients.Keys | Sort-Object | ForEach-Object {
        $item = $aggregatedIngredients[$_]
        "{0} {1} {2}" -f $item.Quantity, $item.Unit, $_
    }

    $StaplesList = $aggregatedStaples.Keys | Sort-Object | ForEach-Object {
        $item = $aggregatedStaples[$_]
        "{0} {1} {2}" -f $item.Quantity, $item.Unit, $_
    }

    

    <#Returning both lists. You can call them like this:
    $ShoppingList = Get-Ingredients {parameters and all that jazz}
    $ShoppingList.Ingredients
    $ShoppingList.Staples
    #>
    return @{
        Ingredients = $ingredientsList
        Staples = $staplesList
    }
}

#############################################################################################################

#Determining next Sunday
$Today = Get-Date
$DaysUntilSunday = [int][DayOfWeek]::Sunday - [int]$Today.DayOfWeek
if ($DaysUntilSunday -le 0) {
    $DaysUntilSunday += 7
}
$NextSunday = $Today.AddDays($DaysUntilSunday).Date

#Defining variables for the functions
$StartTime = $NextSunday.AddHours(12)
$EndTime = $NextSunday.AddHours(13)
$Summary = "Dinners for the week"

#Generating dinners so we can get ingredients
$Dinners = Get-Dinners -FilePath $CounthPath -JsonPath $DinnerPath -DinnerCount 5

#Generating shopping list from ingredients
$ShoppingData = Get-Ingredients -SelectedDinners $dinners -JsonFile $DinnerPath
$Ingredients = $ShoppingData.Ingredients
$Staples = $ShoppingData.Staples

#Building the event description (because I'm picky about how my things are formatted)
$Desc = @()
$Desc += "Dinners:"
$Desc += $Dinners | ForEach-Object { "  - $_" }
$Desc += "Main Ingredients:"
$Desc += $Ingredients | ForEach-Object { "  - $_" }
$Desc += "Staples:"
$Desc += $Staples | ForEach-Object { "  - $_" }
#Joining the array into a single string
$Desc = $Desc -join "`n"

#And finally... the end result of 391 lines of manic coding
Add-GCalendarEvent -StartTime $StartTime -EndTime $EndTime -Summary $Summary -Description $Desc -CalendarId $Id