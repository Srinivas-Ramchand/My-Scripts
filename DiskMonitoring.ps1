##################################################################################

#

# SQL servers Disk space monitoring and reporting script : this one will send mail & SMS alert

#

##################################################################################

 

$usersMail = adabalasu@hcl.com # List of users to email your report to (separate by comma)

$fromemail = noreply@volvo.com

$server = "mailgot.it.volvo.com" #enter your own SMTP server DNS name / IP address here

$list = "C:\Temp\servers.txt" #This accepts the argument you add to your scheduled task for the list of servers. i.e. list.txt

$computers = get-content $list #grab the names of the servers/computers to check from the list.txt file.

 

# Set free disk space threshold below in percent (default at 10%)

[decimal]$thresholdspace = 100

#assemble together all of the free disk space data from the list of servers and only include it if the percentage free is below the threshold we set above.

 

#$tableFragmentHTML= Get-WMIObject  -ComputerName $computers Win32_LogicalDisk `

$tableFragmentHTML= Get-WMIObject  -ComputerName $computers Win32_volume `

| select __SERVER, DriveType, VolumeName, Name, @{n='Size (Gb)' ;e={"{0:n2}" -f ($_.Capacity/1gb)}},

                                                @{n='FreeSpace (Gb)';e={"{0:n2}" -f ($_.FreeSpace/1gb)}},

                                                @{n='PercentFree';e={"{0:n2}" -f ($_.FreeSpace/$_.Capacity*100)}}`

| Where-Object {$_.DriveType -eq 3 -and [decimal]$_.PercentFree -lt [decimal]$thresholdspace} `

| ConvertTo-HTML -fragment

 

$tableFragmentText= Get-WMIObject  -ComputerName $computers Win32_volume `

| select __SERVER, DriveType, VolumeName, Name, @{n='Size (Gb)' ;e={"{0:n2}" -f ($_.Capacity/1gb)}},

                                                @{n='FreeSpace (Gb)';e={"{0:n2}" -f ($_.FreeSpace/1gb)}},

                                                @{n='PercentFree';e={"{0:n2}" -f ($_.FreeSpace/$_.Capacity*100)}}`

| Where-Object {$_.DriveType -eq 3 -and [decimal]$_.PercentFree -lt [decimal]$thresholdspace} `

# assemble the HTML for our body of the email report.

$HTMLmessage = @"

<font color=""black"" face=""Arial, Verdana"" size=""3"">

<u><b>Disk Space monitoring for Dealerpoint servers</b></u>

<br>This report was generated because the drive(s) listed below have less than 10 % free space.Please take an action accordingly for Drives threshold vlaue will not be listed below.

<br>

<style type=""text/css"">

body

{

    font: .8em ""Lucida Grande"", Tahoma, Arial, Helvetica, sans-serif;

}

ol{ margin:0;padding: 0 1.5em; }

table

{

    color:#000;background:#FFF;border-collapse:collapse;width:647px;border:5px solid #900;

}

thead{}

thead th{padding:1em 1em .5em;border-bottom:1px dotted #FFF;font-size:120%;text-align:left;}

thead tr{}

td{padding:.5em 1em;}

tfoot{}

tfoot td{padding-bottom:1.5em;}

tfoot tr{}

#middle{background-color:#900;}

</style>

<body BGCOLOR=""white"">

$tableFragmentHTML

</body>

"@

 

$TextMessage = @"

$tableFragmentText

"@

 

# Writing result in a file

$HTMLmessage | Out-File "C:\Temp\monitoring\html_message_mail.html"

# Set up a regex search and match to look for any <td> tags in our body. These would only be present if the script above found disks below the threshold of free space.

# We use this regex matching method to determine whether or not we should send the email and report.

$regexsubject = $HTMLmessage

$regex = [regex] '(?im)<td>'

# if there was any row at all, send the email

if ($regex.IsMatch($regexsubject)) {

    echo "Successfully Completed"

    # First alert by mail with HTML body content

    send-mailmessage -from $fromemail -to $usersMail -subject "Disk Space Monitoring follow-up for Dealerpoint" -BodyAsHTML -body "$HTMLmessage" -priority High -smtpServer "$server"

    # Seconde alert by SMS with text body

    #send-mailmessage -from $fromemail -to $usersPhone -subject "Disk Space Monitoring alert for Dealerpoint, please check your mailbox for more details" -body "$TextMessage" -priority High -smtpServer "$server"

 

}

# End of Script