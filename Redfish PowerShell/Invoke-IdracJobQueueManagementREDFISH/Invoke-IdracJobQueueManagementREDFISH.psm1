<#
_author_ = Texas Roemer <Texas_Roemer@Dell.com>
_version_ = 1.0

Copyright (c) 2020, Dell, Inc.

This software is licensed to you under the GNU General Public License,
version 2 (GPLv2). There is NO WARRANTY for this software, express or
implied, including the implied warranties of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
along with this software; if not, see
http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
#>




<#
.Synopsis
   Cmdlet used for iDRAC job queue management
.DESCRIPTION
   Cmdlet using Redfish API with OEM extension to manage iDRAC job queue. Supported operations are get current job queue, delete single job ID, clear complete job queue or clear complete job queue/restart Lifecycle Controller services. 
   - idrac_ip: Pass in iDRAC IP address
   - idrac_username: Pass in iDRAC username
   - idrac_password: Pass in iDRAC username password
   - get_job_queue: Pass in 'y' to get current job queue
   - delete_job_id: Delete one job ID, pass in the job ID
   - delete_job_queue: Clear the complete job queue, pass in value 'y'
   - delete_job_queue_restart_LC_services: Clear the complete job queue and restart Lifecycle Controller services, pass in value 'y'. Note: By selecting this option, it will take a few minutes for the Lifecycle Controller to be back in Ready state Note: Recommended to use this option when iDRAC is in a bad state where you are not allowed to set pending or create new jobs.
.EXAMPLE
   .\Invoke-IdracJobQueueManagementREDFISH -idrac_ip 192.168.0.120 -username root -password calvin -get_job_queue y
   This example will get current iDRAC job queue.
.EXAMPLE
   .\Invoke-IdracJobQueueManagementREDFISH -idrac_ip 192.168.0.120 -username root -password calvin -delete_job_id JID_735345376228
   This example will delete job id JID_735345376228 from the job queue
.EXAMPLE
   .\Invoke-IdracJobQueueManagementREDFISH -idrac_ip 192.168.0.120 -username root -password calvin -delete_job_queue y 
   This example will clear the complete iDRAC job queue.
.EXAMPLE
   .\Invoke-IdracJobQueueManagementREDFISH -idrac_ip 192.168.0.120 -username root -password calvin -delete_job_queue_restart_LC_services y 
   This example will clear the complete iDRAC job queue and restart Lifecycle Controller services.
#>

function Invoke-IdracJobQueueManagementREDFISH {








param(
    [Parameter(Mandatory=$True)]
    [string]$idrac_ip,
    [Parameter(Mandatory=$True)]
    [string]$idrac_username,
    [Parameter(Mandatory=$True)]
    [string]$idrac_password,
    [Parameter(Mandatory=$False)]
    [string]$get_job_queue,
    [Parameter(Mandatory=$False)]
    [string]$delete_job_id,
    [Parameter(Mandatory=$False)]
    [string]$delete_job_queue,
    [Parameter(Mandatory=$False)]
    [string]$delete_job_queue_restart_LC_services
    )

# Function to ignore SSL certs

function Ignore-SSLCertificates
{
    $Provider = New-Object Microsoft.CSharp.CSharpCodeProvider
    $Compiler = $Provider.CreateCompiler()
    $Params = New-Object System.CodeDom.Compiler.CompilerParameters
    $Params.GenerateExecutable = $false
    $Params.GenerateInMemory = $true
    $Params.IncludeDebugInformation = $false
    $Params.ReferencedAssemblies.Add("System.DLL") > $null
    $TASource=@'
        namespace Local.ToolkitExtensions.Net.CertificatePolicy
        {
            public class TrustAll : System.Net.ICertificatePolicy
            {
                public bool CheckValidationResult(System.Net.ServicePoint sp,System.Security.Cryptography.X509Certificates.X509Certificate cert, System.Net.WebRequest req, int problem)
                {
                    return true;
                }
            }
        }
'@ 
    $TAResults=$Provider.CompileAssemblyFromSource($Params,$TASource)
    $TAAssembly=$TAResults.CompiledAssembly
    $TrustAll = $TAAssembly.CreateInstance("Local.ToolkitExtensions.Net.CertificatePolicy.TrustAll")
    [System.Net.ServicePointManager]::CertificatePolicy = $TrustAll
}

$global:get_powershell_version = $null

function get_powershell_version 
{
$get_host_info = Get-Host
$major_number = $get_host_info.Version.Major
$global:get_powershell_version = $major_number
}


[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::TLS12
$user = $idrac_username
$pass= $idrac_password
$secpasswd = ConvertTo-SecureString $pass -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($user, $secpasswd)


function get_job_queue
{
$uri = "https://$idrac_ip/redfish/v1/Managers/iDRAC.Embedded.1/Jobs"
try
    {
    if ($global:get_powershell_version -gt 5)
    {
    $result = Invoke-WebRequest -UseBasicParsing -SkipCertificateCheck -SkipHeaderValidation -Uri $uri -Credential $credential -Method Get -ErrorVariable RespErr -Headers @{"Accept"="application/json"}
    }
    else
    {
    Ignore-SSLCertificates
    $result = Invoke-WebRequest -UseBasicParsing -Uri $uri -Credential $credential -Method Get -ErrorVariable RespErr -Headers @{"Accept"="application/json"}
    }
    }
    catch
    {
    Write-Host
    $RespErr
    return
    }

if ($result.StatusCode -eq 200)
{
    #Write-Host "- PASS, GET request passed to get job queue"
}
else
{
    [String]::Format("`n- FAIL, GET request failed to get job queue, statuscode {0} returned",$result.StatusCode)
    return
}

$get_result=$result.Content | ConvertFrom-Json
$get_member_array = $get_result.Members

if ($get_member_array.count -gt 0)
{
Write-Host "`n- Complete job queue details for iDRAC $idrac_ip -`n"
Start-Sleep 5
}
else
{
Write-Host "`n- WARNING, current iDRAC job queue is already cleared, no existing job IDs`n"
return
}



foreach ($i in $get_result.Members)
{
$odata="@odata.id"
$job_id_uri = $i.$odata
$uri = "https://$idrac_ip$job_id_uri"
    try
    {
    if ($global:get_powershell_version -gt 5)
    {
    $result = Invoke-WebRequest -UseBasicParsing -SkipCertificateCheck -SkipHeaderValidation -Uri $uri -Credential $credential -Method Get -ErrorVariable RespErr -Headers @{"Accept"="application/json"}
    }
    else
    {
    Ignore-SSLCertificates
    $result = Invoke-WebRequest -UseBasicParsing -Uri $uri -Credential $credential -Method Get -ErrorVariable RespErr -Headers @{"Accept"="application/json"}
    }
    }
    catch
    {
    Write-Host
    $RespErr
    return
    }

$get_result=$result.Content | ConvertFrom-Json
$get_result
}


}


function delete_job_id 
{

$JsonBody = @{"JobID"=$delete_job_id} | ConvertTo-Json -Compress
$uri = "https://$idrac_ip/redfish/v1/Dell/Managers/iDRAC.Embedded.1/DellJobService/Actions/DellJobService.DeleteJobQueue"

try
{
    if ($global:get_powershell_version -gt 5)
    {
    
    $post_result = Invoke-WebRequest -UseBasicParsing -SkipHeaderValidation -SkipCertificateCheck -Uri $uri -Credential $credential -Body $JsonBody -Method Post -ContentType 'application/json' -Headers @{"Accept"="application/json"} -ErrorVariable RespErr
    }
    else
    {
    Ignore-SSLCertificates
    $post_result = Invoke-WebRequest -UseBasicParsing -Uri $uri -Credential $credential -Method Post -ContentType 'application/json' -Headers @{"Accept"="application/json"} -Body $JsonBody -ErrorVariable RespErr
    }
}
catch
{
Write-Host
$RespErr
return
} 

if ($post_result.StatusCode -eq 200 -or $post_result.StatusCode -eq 200)
{
Write-Host "- PASS, POST command passed to successfully delete job ID $delete_job_id`n"
}
else
{
[String]::Format("- FAIL, POST command failed to delete job ID, statuscode {0} returned. Detail error message: {1}",$post_result.StatusCode, $post_result)
return
}
}

function delete_job_queue_restart_LC_services
{

Write-Host "`n- WARNING, clearing job queue and restarting LC services for iDRAC $idrac_ip, this may take a few minutes for LC services to be back in ready state`n"
Start-Sleep 5
$JsonBody = @{"JobID"="JID_CLEARALL_FORCE"} | ConvertTo-Json -Compress
$uri = "https://$idrac_ip/redfish/v1/Dell/Managers/iDRAC.Embedded.1/DellJobService/Actions/DellJobService.DeleteJobQueue"

try
{
    if ($global:get_powershell_version -gt 5)
    {
    
    $post_result = Invoke-WebRequest -UseBasicParsing -SkipHeaderValidation -SkipCertificateCheck -Uri $uri -Credential $credential -Body $JsonBody -Method Post -ContentType 'application/json' -Headers @{"Accept"="application/json"} -ErrorVariable RespErr
    }
    else
    {
    Ignore-SSLCertificates
    $post_result = Invoke-WebRequest -UseBasicParsing -Uri $uri -Credential $credential -Method Post -ContentType 'application/json' -Headers @{"Accept"="application/json"} -Body $JsonBody -ErrorVariable RespErr
    }
}
catch
{
Write-Host
$RespErr
return
} 

if ($post_result.StatusCode -eq 200 -or $post_result.StatusCode -eq 200)
{
Write-Host "- PASS, POST command passed to successfully clear the job queue and restart LC services.`n"
}
else
{
[String]::Format("- FAIL, POST command failed to clear job queue, statuscode {0} returned. Detail error message: {1}",$post_result.StatusCode, $post_result)
return
}

Start-Sleep 10
Write-Host "- WARNING, script will now loop checking LC status until its back in Ready state`n"
$count = 0
while ($lc_status -ne "Ready")
{
if ($count -eq 30)
{
Write-Host "- FAIL, max retry count has been hit before detecting LC status is ready. Check iDRAC LC logs to debug issue"
return
}

$JsonBody = @{} | ConvertTo-Json -Compress
$uri = "https://$idrac_ip/redfish/v1/Dell/Managers/iDRAC.Embedded.1/DellLCService/Actions/DellLCService.GetRemoteServicesAPIStatus"

try
{
    if ($global:get_powershell_version -gt 5)
    {
    
    $post_result = Invoke-WebRequest -UseBasicParsing -SkipHeaderValidation -SkipCertificateCheck -Uri $uri -Credential $credential -Body $JsonBody -Method Post -ContentType 'application/json' -Headers @{"Accept"="application/json"} -ErrorVariable RespErr
    }
    else
    {
    Ignore-SSLCertificates
    $post_result = Invoke-WebRequest -UseBasicParsing -Uri $uri -Credential $credential -Method Post -ContentType 'application/json' -Headers @{"Accept"="application/json"} -Body $JsonBody -ErrorVariable RespErr
    }
}
catch
{
Write-Host
$RespErr
return
} 

if ($post_result.StatusCode -eq 200 -or $post_result.StatusCode -eq 200)
{
#Write-Host "- PASS, POST command passed to get iDRAC remote service API status"
}
else
{
[String]::Format("- FAIL, POST command failed to get iDRAC remote service API status, statuscode {0} returned. Detail error message: {1}",$post_result.StatusCode, $post_result)
return
}

$get_post_result = $post_result.Content | ConvertFrom-Json
$lc_status = $get_post_result.LCStatus

Write-Host "- WARNING, LC status not in ready state, checking status again"
$count++
Start-Sleep 10
}


$uri = "https://$idrac_ip/redfish/v1/Managers/iDRAC.Embedded.1/Jobs"
try
    {
    if ($global:get_powershell_version -gt 5)
    {
    $result = Invoke-WebRequest -UseBasicParsing -SkipCertificateCheck -SkipHeaderValidation -Uri $uri -Credential $credential -Method Get -ErrorVariable RespErr -Headers @{"Accept"="application/json"}
    }
    else
    {
    Ignore-SSLCertificates
    $result = Invoke-WebRequest -UseBasicParsing -Uri $uri -Credential $credential -Method Get -ErrorVariable RespErr -Headers @{"Accept"="application/json"}
    }
    }
    catch
    {
    Write-Host
    $RespErr
    return
    }

if ($result.StatusCode -eq 200)
{
    #Write-Host "- PASS, GET request passed to get job queue"
}
else
{
    [String]::Format("`n- FAIL, GET request failed to get job queue, statuscode {0} returned",$result.StatusCode)
    return
}

$get_result=$result.Content | ConvertFrom-Json
$get_member_array = $get_result.Members

if ($get_member_array.count -gt 0)
{
Write-Host "- FAIL, job ID not successfully cleared, manually check iDRAC job queue`n"
return
}
else
{
Write-Host "- PASS, iDRAC job queue successfully cleared and LC services back in Ready state`n"
return
}
}



function delete_job_queue 
{

Write-Host "`n- WARNING, clearing job queue for iDRAC $idrac_ip, this may take up to minute to complete depending on how many jobs are in the job queue`n"
Start-Sleep 5
$JsonBody = @{"JobID"="JID_CLEARALL"} | ConvertTo-Json -Compress
$uri = "https://$idrac_ip/redfish/v1/Dell/Managers/iDRAC.Embedded.1/DellJobService/Actions/DellJobService.DeleteJobQueue"

try
{
    if ($global:get_powershell_version -gt 5)
    {
    
    $post_result = Invoke-WebRequest -UseBasicParsing -SkipHeaderValidation -SkipCertificateCheck -Uri $uri -Credential $credential -Body $JsonBody -Method Post -ContentType 'application/json' -Headers @{"Accept"="application/json"} -ErrorVariable RespErr
    }
    else
    {
    Ignore-SSLCertificates
    $post_result = Invoke-WebRequest -UseBasicParsing -Uri $uri -Credential $credential -Method Post -ContentType 'application/json' -Headers @{"Accept"="application/json"} -Body $JsonBody -ErrorVariable RespErr
    }
}
catch
{
Write-Host
$RespErr
return
} 

if ($post_result.StatusCode -eq 200 -or $post_result.StatusCode -eq 200)
{
Write-Host "- PASS, POST command passed to successfully clear the job queue`n"
}
else
{
[String]::Format("- FAIL, POST command failed to clear job queue, statuscode {0} returned. Detail error message: {1}",$post_result.StatusCode, $post_result)
return
}

Start-Sleep 10
$uri = "https://$idrac_ip/redfish/v1/Managers/iDRAC.Embedded.1/Jobs"
try
    {
    if ($global:get_powershell_version -gt 5)
    {
    $result = Invoke-WebRequest -UseBasicParsing -SkipCertificateCheck -SkipHeaderValidation -Uri $uri -Credential $credential -Method Get -ErrorVariable RespErr -Headers @{"Accept"="application/json"}
    }
    else
    {
    Ignore-SSLCertificates
    $result = Invoke-WebRequest -UseBasicParsing -Uri $uri -Credential $credential -Method Get -ErrorVariable RespErr -Headers @{"Accept"="application/json"}
    }
    }
    catch
    {
    Write-Host
    $RespErr
    return
    }

if ($result.StatusCode -eq 200)
{
    #Write-Host "- PASS, GET request passed to get job queue"
}
else
{
    [String]::Format("`n- FAIL, GET request failed to get job queue, statuscode {0} returned",$result.StatusCode)
    return
}

$get_result=$result.Content | ConvertFrom-Json
$get_member_array = $get_result.Members

if ($get_member_array.count -gt 0)
{
Write-Host "- FAIL, job ID not successfully cleared, manually check iDRAC job queue`n"
return
}
else
{
Write-Host "- PASS, iDRAC job queue successfully cleared`n"
return
}
}



# Run code

get_powershell_version


if ($get_job_queue.ToLower() -eq 'y')
{
get_job_queue
}
elseif ($delete_job_id)
{
delete_job_id
}
elseif ($delete_job_queue)
{
delete_job_queue
}
elseif ($delete_job_queue_restart_LC_services)
{
delete_job_queue_restart_LC_services
}
else
{
Write-Host "- FAIL, either missing or incorrect parameters passed in"
return
}


}
