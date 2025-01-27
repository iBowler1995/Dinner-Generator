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

    Try{
        #Determining the past dinner selections, to avoid repeats
        $existingNumbers = Get-Content $filePath | ForEach-Object { [int]$_ }
    }
    Catch {
        Write-Host "Error at line $($_.InvocationInfo.ScriptLineNumber) while getting past dinners: $($_.Exception.Message)"
    }

    Try{
        #Loading dinner JSON and counting dinners
        $dinners = Get-Content -Raw -Path $JsonPath | ConvertFrom-Json
        $totalDinners = $dinners.Count
    }
    Catch {
        Write-Host "Error at line $($_.InvocationInfo.ScriptLineNumber) while loading dinner JSON: $($_.Exception.Message)"
    }

    Try{
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
    }
    Catch {
        Write-Host "Error at line $($_.InvocationInfo.ScriptLineNumber) while generating new dinners or updating used dinners: $($_.Exception.Message)"
    }

    

    #Checking number of dinner selections. After 15, we allow the first 5 to go back into rotation
    if ($existingNumbers.Count -ge 15) {
        $updatedNumbers = $existingNumbers[5..($existingNumbers.length - 1)]
        $updatedNumbers | Set-Content -Path $filePath
    }

    #Getting meals corresponding with the generated numbers
    $selectedDinners = $randomNumbers | ForEach-Object { $dinners[$_].Name }

    Try{
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
    }
    Catch {
        Write-Host "Error at line $($_.InvocationInfo.ScriptLineNumber) while getting seecond pulled pork dinner: $($_.Exception.Message)"
    }


    #Returning the selected dinners
    return $selectedDinners
}