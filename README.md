# Dinner Generator

This project will pick weekly dinners for you and generate a shopping list for them. It then adds those items to a Google calendar as an event.

# Privacy Note
This project does require you to set your Google Calendar to **Public**. This means **anyone** who has your Gmail address can see all of your calendar. I **highly** recommend creating a sub-calendar
for this under your Google Calendar. On the left-hand side of Google Calendar (in a desktop browser), expand **Add calendar** and click **create new calendar**

# Pre-requisites

This script requires **PowerShell 7** or later to run. PowerShell 7 introduces modern .NET APIs that are essential for certain parts of this script, such as handling JWT tokens for authentication. Follow these steps to install and open PowerShell 7:

### Installing PowerShell 7
1. Go to the official [PowerShell GitHub Releases page](https://github.com/PowerShell/PowerShell/releases).
2. Download the latest stable version for your operating system:
   - **Windows**: Look for the `.msi` installer under "Assets" (e.g., `PowerShell-7.x.x-win-x64.msi`).
   - **macOS**: Download the `.pkg` file for macOS.
   - **Linux**: Use the appropriate package for your Linux distribution (e.g., `.deb` for Ubuntu, `.rpm` for Red Hat).
3. Run the installer and follow the on-screen instructions.

### Opening PowerShell 7
1. Once installed, search for **"PowerShell 7"** in your Start Menu (on Windows) or Applications folder (on macOS).
2. Open it, and you’ll see a terminal window with the `pwsh` prompt (e.g., `PS>`).

### There are also a couple steps you need to complete before you can get this up and running. See below:


1. **Create Google Cloud project and download credential file**

   1. **Create a New Project**
      - Go to the [Google Cloud Console](https://console.cloud.google.com/).
      - Click on the project dropdown (top-left corner) and select **New Project**.
      - **Name the project**:
        - Avoid common or ambiguous names like "Calendar API." These can cause issues, such as being repeatedly prompted to configure the consent screen. Instead, choose a unique name, like `MyCalendarAutomationProject`.

   2. **Enable the Google Calendar API**
      - In the project dashboard, go to **APIs & Services** > **Library**.
      - Search for **Google Calendar API** and click on it.
      - Click **Enable**.

   3. **Set Up a Service Account**
      - Go to **IAM & Admin** > **Service Accounts** in the left-hand menu.
      - Click **+ CREATE SERVICE ACCOUNT**.
      - Provide a **name** and **description** (e.g., `calendar-automation`).
      - Click **Create and Continue**.

   4. **Grant Service Account Permissions**
      - On the next screen, assign the **"Editor"** role (or more restrictive roles if applicable).
      - Click **Continue** without assigning additional users or roles (unless needed).
      - Click **Done** to finish creating the service account.

   5. **Generate and Download the Credentials JSON**
      - In the service accounts list, find your service account and click the **three dots** under "Actions."
      - Select **Manage Keys** > **Add Key** > **Create New Key**.
      - Choose **JSON** as the key type and click **Create**.
      - Save the downloaded JSON file securely. You’ll need it for automation.

   6. **Share Your Calendar with the Service Account and set it to Public**
      - Open your Google Calendar.
      - Go to **Settings** > **Calendars** > **Access permissions** for the calendar you want to automate.
      - Add the service account’s email address (found in the JSON file under `client_email`) and set the appropriate permissions (e.g., "Make changes to events").
      - Under Access permissions for events, check the box **Make available to public**

2. **Create a JSON file with meal details** (I've also provided a 

   Construct a JSON file to store the details of each meal. For every meal, include the following attributes:
   - `Name`: The name of the meal.
   - `Ingredients`: A list of ingredients, where each ingredient has:
     - `Name`: The name of the ingredient.
     - `Quantity`: The quantity of the ingredient.
     - `Unit`: The unit of measurement (e.g., "oz," "cups," etc.). Leave empty if not applicable.
     - `Staple`: A true/false value indicating whether the ingredient is a staple item (e.g., salt, pepper, etc.).

   **What are staple ingredients?**
   - Staple ingredients are items you typically have on hand, such as oil, spices, milk, butter, etc. 
   - By marking these items as staples in the JSON, the script can better organize the shopping list by excluding them unless explicitly needed.

   ### Example JSON
   ```json
   [
       {
           "Name": "Beef Stew",
           "Ingredients": [
               { "Name": "Yellow Onion", "Quantity": 1, "Unit": "", "Staple": false },
               { "Name": "Carrot (large)", "Quantity": 2, "Unit": "", "Staple": false },
               { "Name": "Potatoes", "Quantity": 2, "Unit": "", "Staple": false },
               { "Name": "Beef Strips", "Quantity": 10, "Unit": "oz", "Staple": false },
               { "Name": "Chicken Broth", "Quantity": 2, "Unit": "oz", "Staple": false }
           ]
       }
   ]

3. **Create an empty text file for tracking random numbers**

   - Create an empty `.txt` file in your project directory.
   - Name the file appropriately, such as `random_numbers.txt`.
   - This file will be used by the project to track and store random numbers generated during execution.
   

## Usage Example

To use the script, ensure that the following files are in the same directory:
- The script file.
- The credentials JSON file (downloaded from Google Cloud).
- The dinner JSON file (created in Step 2).
- The text file for tracking random numbers (created in Step 3).

```powershell
C:\YourPath\ProjectFolder\DinnerPicker.ps1 -CountPath "DinnerCount.txt" -DinnerPath "dinners.json" -Id "your_calendar_id"
```

> **Tip:** To find your Google Calendar ID:
>
> 1. Open [Google Calendar](https://calendar.google.com/).
> 2. Click on the **gear icon** (⚙️) and go to **Settings**.
> 3. Under the **Settings for my calendars** section, select the calendar you want to use.
> 4. Scroll down to the **Integrate calendar** section to find the **Calendar ID**.
>    - The Calendar ID typically looks like a long string ending with `@group.calendar.google.com`.

### Last note, I've also added the Get-Dinners and Get-Ingredients functions separately, in case you want just them. I also added a version of Get-Dinners that doesn't have
the pulled pork logic. That was just a niche quirk my case required. Just paste over the function in the main script if you want to get rid of it.
