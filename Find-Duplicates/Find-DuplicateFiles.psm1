function Find-DuplicateFiles {
    [CmdletBinding()]
    param(
        [string[]]$Path = $($pwd.path),
        [switch]$AllDrives,
        [switch]$XML
    )

    begin {
        
        if ($VerbosePreference -ne 'Continue') {
            $ErrorActionPreference = 'SilentlyContinue'
        }
        
        if ($PSVersionTable.PSVersion -gt 7) {
            # $PSStyle.Progress.View = 'Classic'
            $PSStyle.Progress.MaxWidth = 25
        }
        
        [object[]]$temp = @(New-Object -TypeName System.Object | Out-Null)
        [object[]]$duplicates = @(New-Object -TypeName System.Object | Out-Null)
        $start = (Get-Date)
    }
    
    process {
        if ($AllDrives) {
            Get-Volume | Select-Object DriveLetter | Where-Object DriveLetter -match '\w' | ForEach-Object {
                $drive = "$($_.DriveLetter):\"
                Clear-Host
                Write-Host "`n`tSearching $drive ..."
                $files += Get-ChildItem $drive -File -Recurse -ErrorAction SilentlyContinue | Select-Object FullName,Length | Sort-Object Length
            }
        }
        else {
            $Path | ForEach-Object {
                Clear-Host
                Write-Host "`n`tSearching $_ ..."
                $files += Get-ChildItem "$_" -File -Recurse -ErrorAction SilentlyContinue | Select-Object FullName,Length | Sort-Object Length
            }
        }

        Clear-Host
        Write-Host '     Creating database'
        $i = 0
        for ($i=0; $i -le $files.Length; $i++) {
            $percentComplete = [math]::Round(($i / $files.Length) * 100)
            $ProgressParameters = @{
                Activity         = '   '
                Status           = $($(' '*(8-$percentComplete.Length))+$($percentComplete.ToString())+'%')
                PercentComplete  = $percentComplete
            }
            Write-Progress @ProgressParameters

            if ($files[$i].Length -eq $files[$i+1].Length -or $files[$i].Length -eq $files[$i-1].Length) {
                $hash = (Get-FileHash $files[$i].FullName -Algorithm SHA1).Hash
                $temp += $files[$i]
                $temp[$temp.Length-1] | Add-Member -Name 'Hash'-TypeName System.String -MemberType NoteProperty -Value $hash
            }
            
            $i++
        }
        
        Clear-Host
        Write-Host '  Finding duplicate files'
        $files = $null
        Remove-Variable files -Force
        [GC]::Collect()

        $temp = $temp | Sort-Object Hash

        for ($i=0; $i -le $temp.Length; $i++) {
            $percentComplete = [math]::Round(($i / $temp.Length) * 100)

            $ProgressParameters = @{
                Activity         = '   '
                Status           = $($(' '*(8-$percentComplete.Length))+$($percentComplete.ToString())+'%')
                PercentComplete  = $percentComplete
            }
            Write-Progress @ProgressParameters

            if ($temp[$i].Hash -eq $temp[$i+1].Hash -or $temp[$i].Hash -eq $temp[$i-1].Hash) {
                Write-Verbose "Duplicate file found: $($temp[$i].FullName)"
                $duplicates += $temp[$i]
            }
        }    

        Clear-Host
        $temp = $null
        Remove-Variable temp -Force
        [GC]::Collect()

        $elapsed = $(Get-Date) - $start
        Write-Host "Search Time: `n`tHours:$($elapsed.Hours)  Minutes:$($elapsed.Minutes)  Seconds:$($elapsed.Seconds)"

        if ($duplicates) {
            if ($XML) {
                $duplicates | Export-Clixml -Path '.\DuplicateFiles.xml'
            }

            $delete = ($duplicates | Sort-Object Hash | Out-GridView -PassThru -Title 'Select Files to Delete').'Duplicate File'

            if ($delete) {
                $delete | ForEach-Object {Remove-Item "$_" -Force -Verbose}
            }
        }
        else {
            Clear-Host
            Write-Host "`n`tNo duplicate files found"
        }
    }
    end {
        $duplicates,$delete = $null
        Remove-Variable duplicates,delete -Force
        [GC]::Collect()
    }
}