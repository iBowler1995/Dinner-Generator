Function Get-Ingredients {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SelectedDinners,
        [Parameter(Mandatory = $true)]
        [string]$JsonFile
    )

    try{
        #Loading the JSON file
        $dinners = Get-Content -Raw -Path $JsonFile | ConvertFrom-Json
    }
    catch {
        Write-Host "Error at line $($_.InvocationInfo.ScriptLineNumber) while loading the JSON file: $($_.Exception.Message)"
    }

    try{
        #Creating a lookup hashtable for faster access
        $dinnerLookup = @{}
        foreach ($dinner in $dinners) {
            $dinnerLookup[$dinner.Name] = $dinner
        }
    }
    catch {
        Write-Host "Error at line $($_.InvocationInfo.ScriptLineNumber) while creating the lookup table: $($_.Exception.Message)"
    }

    #Initializng hash tables for main and staple ingredients
    $aggregatedIngredients = @{}
    $aggregatedStaples = @{}

    try{
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
    }
    catch {
        Write-Host "Error at line $($_.InvocationInfo.ScriptLineNumber) while processing dinner '$dinner': $($_.Exception.Message)"
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