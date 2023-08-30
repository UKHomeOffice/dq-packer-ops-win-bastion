Import-Module AWSPowerShell

$Namespace = 'Windows-Stopped-Service-Monitor'

[string]$token = Invoke-RestMethod -Headers @{"X-aws-ec2-metadata-token-ttl-seconds" = "21600"} -Method PUT -Uri http://169.254.169.254/latest/api/token
[string]$instanceId = Invoke-RestMethod -Headers @{"X-aws-ec2-metadata-token" = $token} -Method GET -Uri http://169.254.169.254/latest/meta-data/instance_id"


$instanceDimension = New-Object -TypeName Amazon.CloudWatch.Model.Dimension;
$instanceDimension.Name = "InstanceID";
$instanceDimension.Value = $instanceId;

while($true)
{
    $metrics = @();

    $runningServices = Get-Service | Select-Object -Property name, Status, StartType | Where-Object {$_.Status -eq "Stopped" -and $_.StartType -eq "Automatic"}

    $runningServices | % {
        $dimensions = @();

        $serviceDimension = New-Object -TypeName Amazon.CloudWatch.Model.Dimension;
        $serviceDimension.Name = "Service"
        $serviceDimension.Value = $_.Name;

		    $serviceDimensionStatus = New-Object -TypeName Amazon.CloudWatch.Model.Dimension;
        $serviceDimensionStatus.Name = "Status"
        $serviceDimensionStatus.Value = $_.Status;

		    $serviceDimensionType = New-Object -TypeName Amazon.CloudWatch.Model.Dimension;
        $serviceDimensionType.Name = "StartType"
        $serviceDimensionType.Value = $_.StartType;

        $dimensions += $instanceDimension;
        $dimensions += $serviceDimension;
		    $dimensions += $serviceDimensionStatus;
		    $dimensions += $serviceDimensionType;

        $metric = New-Object -TypeName Amazon.CloudWatch.Model.MetricDatum;
        $metric.Timestamp = [DateTime]::UtcNow;
        $metric.MetricName = 'Status';
        $metric.Value = 1;
        $metric.Dimensions = $dimensions;

        $metrics += $metric;
    }

    Write-CWMetricData -Namespace $Namespace -MetricData $metrics;
	exit
}
