param(
[parameter(Mandatory = $true)]
[string]$ProcName
)
$folderpath="\\qardp01\shared\MIGRATION POSTGRESQL\SRINIVAS\SRIKARA_HIMS_P_M\SRIKARA_PROCS_20251021\"
$pgHost="172.30.28.127"
$port="5432"
$user="postgres"
$db="stpl_hims_p_m_mig"
$schema="stpl_hims_p_m_dbo"
$psql = "C:\Program Files\pgAdmin 4\runtime\psql.exe"
Write-Host "Searching for procedure: $procName" -ForegroundColor Cyan
$target =$ProcName.ToLower()
$file =Get-ChildItem -Path $folderpath |
Where-Object {$_.Name.ToLower()  -like "*$target*"}|
Select-Object -First 1
if(-not $file){
write-Host "error:procedure file '$ProcName' not found in folder"
exit 1
}
write-Host " found: $($file.Name)"-ForegroundColor green
$sqlContent = get-content -Path $file.FullName -Raw
$sqlContent=[regex]::replace($sqlContent, 'ISNULL\s*\(','COALESCE(','IgnoreCase')
$sqlContent=[regex]::replace($sqlContent, 'RAISE\s+NOTICE\s+([0-9]+)\s*;',"RAISE NOTICE '`$1';",'Ignorecase')
$sqlcontent=[regex]::replace($sqlcontent, 'WITH\s*\(\s*NOLOCK\s*\)','','Ignorecase')


$sqlcontent=[regex]::Replace(
$sqlcontent,
'(?im)^[ \t]*pr_get_session_det\$par_OP_MACHINE_NAME[ \t]+VARCHAR;[ \t]*\r?\n',
''
)

$sqlcontent=[regex]::Replace(
$sqlcontent,
'(?im)^[ \t]*pr_get_session_det\$par_OP_CLIENT_NAME[ \t]+VARCHAR;[ \t]*\r?\n',
''
)

$sqlcontent=[regex]::Replace(
$sqlcontent,
'(?im)^[ \t]*pr_get_session_det\$par_OP_GRP_CD[ \t]+VARCHAR;[ \t]*\r?\n',
''
)

$sqlcontent=[regex]::Replace(
$sqlcontent,
'(?im)^[ \t]*pr_get_session_det\$par_OP_ORG_CD[ \t]+VARCHAR;[ \t]*\r?\n',
''
)

$sqlcontent=[regex]::Replace(
$sqlcontent,
'(?im)^[ \t]*pr_get_session_det\$par_OP_LOC_CD[ \t]+VARCHAR;[ \t]*\r?\n',
''
)

$sqlcontent=[regex]::Replace(
$sqlcontent,
'(?im)^[ \t]*pr_get_session_det\$par_OP_TERMINAL[ \t]+VARCHAR;[ \t]*\r?\n',
''
)

$errorvar ='(?m)^[ \t]*pr_ins_errordetails\$ReturnCode\s+INTEGER\s*;\s*\r?\n'
$errorvarreplace =@"

	v_state text;
	v_msg text;
	v_detail text;
	v_hint text;
	v_cont text;
	lv_create_dt TIMESTAMP := NOW();

"@

  if([regex]::IsMatch($sqlcontent,$errorvar,'Ignorecase')){
	write-host " variable match found"
		$sqlcontent=[regex]::Replace($sqlcontent,$errorvar,$errorvarreplace,'IgnoreCase')
		}
  else{
        write-host " variable match not found"
  }
  
$sessionpattren ="\bCALL\b[\s\S]*?\bpr_get_session_det\b\s*\([\s\S]*?\)\s*;"
$sessiondetreplace =@"

	SELECT
		GRP_ID,
		ORG_ID,
		LOC_ID,
		USER_ID
		 
	INTO VAR_LV_GRP_ID,
		VAR_LV_ORG_ID,
		VAR_LV_LOC_ID,
		VAR_LV_USER_ID
		
	FROM
		STPL_HIMS_P_M_DBO.USER_SESSION
	WHERE
		USER_SESSION_ID = (PAR_IP_SESSION_ID);

"@

  if([regex]::IsMatch($sqlcontent,$sessionpattren,'Ignorecase')){
	write-host " session det match found"
		$sqlcontent=[regex]::Replace($sqlcontent,$sessionpattren,$sessiondetreplace,'IgnoreCase')
		}
  else{
        write-host " session det match not found"
  }
 


 
 
$errordetails='(?is)\bEXCEPTION\s+WHEN\s+OTHERS\s+THEN\b.*?(?=\bEND\b|\bEND\s*;)'
$errordetailsreplace =@"

	Exception When Others Then
		get stacked diagnostics
		v_state  = returned_sqlstate,
		v_msg = message_text,
		v_detail = pg_exception_detail,
		v_hint = pg_exception_hint,
		v_cont = pg_exception_context;
		perform stpl_hims_p_m_dbo.pr_ins_errordetails (	par_ip_error_msg  := v_msg::text,
										par_ip_error_code  := ''::text,
										par_ip_error_proc  := 'stpl_hims_p_m_dbo.pr_delete_diagnosis'::text,
										par_errortracer_rev_no := 1,
										par_errortracer_cd  := ''::character varying,
										par_record_status := 'A',
										par_errornumber := v_state::text,
										par_errorstate  := v_cont::text,
										par_errorseverity  := 'primary'::text,
										par_errorline := v_state::text,
										par_error_proc := 'stpl_hims_p_m_dbo.pr_delete_diagnosis'::character varying ,
										par_errormsg  := v_msg::text,
										par_username  := (select rolname From pg_authid Where rolcanlogin limit 1)::character varying,
										par_hostname  := (Select setting From pg_settings Where name = 'port' limit 1)::character varying,
										par_errordate  := lv_create_dt,
										par_ipaddress  := (Select inet_client_addr() limit 1)::character varying,
										par_create_by  := 1::bigint,
										par_create_dt := lv_create_dt,
										par_session_id := 1,
										par_remarks := 'This Is Error Record...'::text 
									 );

"@

  if([regex]::IsMatch($sqlcontent,$errordetails,'Ignorecase')){
	write-host " error details  match found"
		$sqlcontent=[regex]::Replace($sqlcontent,$errordetails,$errordetailsreplace,'IgnoreCase')
		}
  else{
        write-host " error details match not found"
  }
  
$pattern='CONVERT\s*\(\s*VARCHAR\s*\(\d+\)\s*,\s*DATEADD\s*\(\s*MI\s*,\s*''\s*\|\|\s*CAST\s*\(\s*(?<var>[^\)]+?)\s*AS\s*VARCHAR\s*\(\d+\)\s*\)(?:\s*\|\|\s*'')*\s*,\s*(?<col>[^\)]+?)\)\s*,\s*120\s*\)'
if([regex]::IsMatch($sqlcontent,$pattern,'Ignorecase')){
write-host "match found"
$sqlcontent=[regex]::Replace($sqlcontent,$pattern,{
param($m)
$var = $m.Groups['var'].Value.Trim()
$col = $m.Groups['col'].Value.Trim()
$alias = $col.split('.')[-1]

return "to_char($col + (''' || $var || 'minutes'')::interval,''YYYY-MM-DD HH24:MI:SS'')"
},'IgnoreCase')

write-host "replaced applied successfully" -ForegroundColor blue
}else{
write-host "match not found"
}
$patternsimple='CONVERT\s*\(\s*VARCHAR\s*(?:\(\d+\))?\s*,\s*(?<col>[^\),]+)\s*,\s*120\s*\)\s*(?<alias>\w+)'
if([regex]::IsMatch($sqlcontent,$patternsimple,'Ignorecase')){
write-host "match found simple"
$sqlcontent=[regex]::Replace($sqlcontent,$patternsimple,{
param($m)
$col = $m.Groups['col'].Value.Trim()
$alias=$m.Groups['alias'].Value.Trim()

return "to_char($col ,''YYYY-MM-DD HH24:MI:SS'')$alias"
},'IgnoreCase')
}
 $dochandle ='(?is)SELECT\s+t\.DocHandle\s+FROM\s+aws_sqlserver_ext\.sp_xml_preparedocument\s*\(\s*par_XML\s*\)\s+AS\s+t\s+INTO\s+var_I\s*;'
 if([regex]::IsMatch($sqlcontent,$dochandle)){
$content =[regex]::Replace($sqlcontent,$dochandle,'')
write-host " doc handle removed successfully"
 }
 else
 {
write-host " doc handle not removed successfully"
 }
$openxml='(?im)^\s*aws_sqlserver_ext\.openxml\s*\(\s*var_I\s*::\s*BIGINT\s*\)\s*,?\s*$'

  if([regex]::IsMatch($sqlcontent,$openxml)){
$content =[regex]::Replace($sqlcontent,$openxml,'')
write-host "  aws_sqlserver_ext.openxml removed successfully"
 }
 else
 {
write-host " aws_sqlserver_ext.openxml removed successfully"
 }
  
 $sessionlogout ='(?im)^([ \t]*)CALL\s+stpl_hims_p_m_dbo\.pr_upd_session_logout\s*\(.*?\)\s*;'
 

  if([regex]::IsMatch($sqlcontent,$sessionlogout,'Ignorecase')){
	write-host " session logout match found"
		$sqlcontent=[regex]::Replace($sqlcontent,$sessionlogout,
	        '-- $0',
		'IgnoreCase')
		}
  else{
        write-host " session logout match not found"
  }



$finalSQL=@"
SET search_path TO $schema;
$sqlContent
"@
$tempFile=New-TemporaryFile
Set-Content -Path $tempFile -Value $finalSQL -Encoding UTF8
write-Host "executing procedure in pgsql..." -ForegroundColor cyan

& "$psql" -h $pgHost -p $port -U $user -d $db -f $tempFile
if($LASTEXITCODE -EQ 0){
write-Host " SUCCCESSFULLY CREATED PROCEDURE IN YOUR DATABASE '$db' schema '$schema'" -ForegroundColor green
}
else {
write-Host " not CREATED '$db' schema " -ForegroundColor red
}

Remove-Item $tempFile -Force
write-Host " TEMP FILE REMOVED '$db' schema " -ForegroundColor green