Import-LocalizedData -BindingVariable localizedData -FileName VE_XD7Feature.Resources.psd1;

function Get-TargetResource
{
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSDSCUseVerboseMessageInDSCResource', '')]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory)]
        [ValidateSet('Controller','Studio','Storefront','Licensing','Director','FAS')]
        [System.String] $Role,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $SourcePath,

        [Parameter()]
        [AllowNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.CredentialAttribute()]
        $Credential,

        [Parameter()]
        [ValidateSet('Present','Absent')]
        [System.String] $Ensure = 'Present'
    )
    process
    {
        $targetResource = @{
            Role = $Role
            SourcePath = $SourcePath
            Ensure = 'Absent'
        }

        if (TestXDInstalledRole -Role $Role)
        {
            $targetResource['Ensure'] = 'Present'
        }

        return $targetResource
    }
}

function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory)]
        [ValidateSet('Controller','Studio','Storefront','Licensing','Director','FAS')]
        [System.String] $Role,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $SourcePath,

        [Parameter()]
        [AllowNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.CredentialAttribute()]
        $Credential,

        [Parameter()]
        [ValidateSet('Present','Absent')]
        [System.String] $Ensure = 'Present',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String] $LogPath = (Join-Path -Path $env:TMP -ChildPath '\Citrix\XenDesktop Installer'),

        [Parameter()]
        [System.Boolean] $IgnoreHardwareCheckFailure
    )
    process
    {
        $targetResource = Get-TargetResource -SourcePath $SourcePath -Role $Role
        if ($Ensure -eq $targetResource.Ensure)
        {
            Write-Verbose ($localizedData.ResourceInDesiredState -f $Role)
            return $true
        }
        else
        {
            Write-Verbose ($localizedData.ResourceNotInDesiredState -f $Role)
            return $false
        }
    }
}

function Set-TargetResource
{
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'DSCMachineStatus')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', 'global:DSCMachineStatus')]
    param
    (
        [Parameter(Mandatory)]
        [ValidateSet('Controller','Studio','Storefront','Licensing','Director','FAS')]
        [System.String] $Role,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $SourcePath,

        [Parameter()]
        [AllowNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.CredentialAttribute()]
        $Credential,

        [Parameter()]
        [ValidateSet('Present','Absent')]
        [System.String] $Ensure = 'Present',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String] $LogPath = (Join-Path -Path $env:TMP -ChildPath '\Citrix\XenDesktop Installer'),

        [Parameter()]
        [System.Boolean] $IgnoreHardwareCheckFailure
    )
    begin
    {
        if (-not (Test-Path -Path $SourcePath -PathType Container))
        {
            throw ($localizedData.InvalidSourcePathError -f $SourcePath)
        }
    }
    process
    {
        if ($Ensure -eq 'Present')
        {
            Write-Verbose ($localizedData.InstallingRole -f $Role)
            $resolveXDServerSetupArgumentsParams = @{
                Role = $Role
                LogPath = $LogPath
                IgnoreHardwareCheckFailure = $IgnoreHardwareCheckFailure
            }
            $installArguments = ResolveXDServerSetupArguments @resolveXDServerSetupArgumentsParams
        }
        else
        {
            ## Uninstall
            Write-Verbose ($localizedData.UninstallingRole -f $Role)
            $resolveXDServerSetupArgumentsParams = @{
                Role = $Role
                LogPath = $LogPath
                Uninstall = $true
            }
            $installArguments = ResolveXDServerSetupArguments -Role $Role -LogPath $LogPath -Uninstall
        }

        Write-Verbose ($localizedData.LogDirectorySet -f $logPath)
        Write-Verbose ($localizedData.SourceDirectorySet -f $SourcePath)

        $startWaitProcessParams = @{
            FilePath = ResolveXDSetupMedia -Role $Role -SourcePath $SourcePath
            ArgumentList = $installArguments
        }

        if ($PSBoundParameters.ContainsKey('Credential'))
        {
            $startWaitProcessParams['Credential'] = $Credential
        }

        $exitCode = StartWaitProcess @startWaitProcessParams -Verbose:$Verbose
        # Check for reboot
        if (($exitCode -eq 3010) -or ($Role -eq 'Controller'))
        {
            $global:DSCMachineStatus = 1
        }
        elseif ($Role -eq 'Storefront')
        {
            ## Add the Storefront module path to the current session
            if (Test-Path -Path "$env:ProgramFiles\Citrix\Receiver StoreFront\PowerShellSDK\Modules\")
            {
                $env:PSModulePath += ";$env:ProgramFiles\Citrix\Receiver StoreFront\PowerShellSDK\Modules\"
            }
        }
    }
}

## Import the XD7Common library functions
$moduleRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$moduleParent = Split-Path -Path $moduleRoot -Parent
Import-Module (Join-Path -Path $moduleParent -ChildPath 'VE_XD7Common')

Export-ModuleMember -Function *-TargetResource
