# For allowing access to export lists, use SharePoint designer, etc

$orgName = "contoso"
$site = "contosoSite"

Connect-SPOService -Url https://$orgName-admin.sharepoint.com

Set-SPOsite https://$orgName.sharepoint.com/sites/$site -DenyAddAndCustomizePages 0