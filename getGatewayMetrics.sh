#!/bin/bash

LOCAL_TIME=`date`


#Functions

mysql_status () {
        local status=$(mysql -Bse "show /*!50000 global */ status like $1" | awk '{ print $2 }')
        export "$2"=$status
}

mysql_variable () {
        local variable=$(mysql -Bse "show /*!50000 global */ variables like $1" | awk '{ print $2 }')
        export "$2"=$variable
}

getMaxMysqlConnections () {

	mysql_variable \'max_connections\' max_mysql_connections
	mysql_status \'Threads_connected\' mysql_mysql_current_threads
	mysql_status \'Max_used_connections\' max_mysql_used_connections

}

Inbound_EST_Connection_Count () {

	LOCAL_PORT=$1

	netstat -an | grep -w $LOCAL_PORT | grep -i established | awk {'print $4'} | grep -w $LOCAL_PORT | cut -d: -f1 | sort | uniq -c | sort -n | awk '{printf $1}'


}

CloseWait_Connection_Count () {

	CloseWait_Connection_Count=`netstat -tapn | grep -i close_wait | wc -l`

}

TimeWait_Connection_Count () {

        netstat -tapn | grep -i time_wait | wc -l

}

grabInboundESTConnections () {

	InEst8443ConnCount=`Inbound_EST_Connection_Count 8443`
	InEst9443ConnCount=`Inbound_EST_Connection_Count 9443`
	InEst8080ConnCount=`Inbound_EST_Connection_Count 8080`
	InEst22ConnCount=`Inbound_EST_Connection_Count 22`
	InEst2124ConnCount=`Inbound_EST_Connection_Count 2124`

	InboundEstConnCountString="InEst8443ConnCount=${InEst8443ConnCount};InEst9443ConnCount=${InEst9443ConnCount};InEst8080ConnCount=${InEst8080ConnCount};InEst22ConnCount=${InEst22ConnCount};InEst2124ConnCount=${InEst2124ConnCount}"

}

grabDiskUsage () {

	#mysql
	diskMysqlUsedPec=`df -h | grep "/var/lib/mysql" | awk '{printf "var_lib_mysql_Util="$(NF-1)}'`

	#home
	diskHomeUsedPec=`df -h | grep "/home" | awk '{printf "home_Util="$(NF-1)}'`

	#opt
	diskOptUsedPec=`df -h | grep "/opt" | grep -v splunk | awk '{printf "opt_Util="$(NF-1)}'`

	#tmp
	diskTmpUsedPec=`df -h | grep "/tmp" | awk '{printf "tmp_Util="$(NF-1)}'`

	#/var/log
	diskVarLogUsedPec=`df -h | grep "/var/log" | grep -v "var/log/audit" | awk '{printf "var_log_Util="$(NF-1)}'`

	#/var/log/audit
	diskVarLogAuditUsedPec=`df -h | grep "/var/log/audit" | awk '{printf "var_log_audit_Util="$(NF-1)}'`

}

grabMemInfo () {

	MemInfo=`free | awk '/Mem/{printf("memUsedPerc=%.2f"), $3/$2*100} /buffers\/cache/{printf("; memBufferPerc=%.2f"), $4/($3+$4)*100} /Swap/{printf("; memSwapPerc=%.2f"), $3/$2*100}'`
}

grabCPUInfo () {

	#CPU_Load
	CPU_Load=`top -bn1 | grep load | awk '{printf "CPU_Load=%.2f\n", $(NF-2)}'`

}

fileHandlerStuff () {

	TotalFilesAllocated=`cat /proc/sys/fs/file-nr | awk '{print $1}'`  #The total allocated file handles.
	NumberOfUnusedFileHandles=`cat /proc/sys/fs/file-nr | awk '{print $2}' ` #Number of currently unused file handles (with the 2.6 kernel).
	MaxPotentialFileHandles=`cat /proc/sys/fs/file-nr | awk '{print $3}'`  #The maximum file handles that can be allocated
	FileDescriptorCount=`ps awwx | grep Gateway.jar | grep -v grep | awk '{print $1}' | xargs -I{} ls -l /proc/{}/fd |wc -l`

fileHandleInfo="TotalFilesAllocated=${TotalFilesAllocated};NumberOfUnusedFileHandles=${NumberOfUnusedFileHandles};MaxPotentialFileHandles=${MaxPotentialFileHandles};FileDescriptorCount=${FileDescriptorCount}"

}

spitOutLog () {

LOG_MESSAGE="SystemStats - $MemInfo; $diskMysqlUsedPec; $diskHomeUsedPec; $diskOptUsedPec; $diskTmpUsedPec; $diskVarLogUsedPec; $diskVarLogAuditUsedPec; $CPU_Load;$InboundEstConnCountString; CloseWait_Connection_Count=$CloseWait_Connection_Count; MaxMysqlConnections=${max_mysql_connections};mysql_mysql_current_threads=${mysql_mysql_current_threads}; max_mysql_used_connections=${max_mysql_used_connections};${fileHandleInfo}"

#curl -X POST -d "${LOG_MESSAGE}" http://localhost:8080/getSystemStats
echo "${LOG_MESSAGE}" >> /opt/SecureSpan/Gateway/node/default/var/logs/TrafficLogger_0_0.log
echo "${LOG_MESSAGE}"
}

invokeJVMMetricsAPI () {

curl http://localhost:8080/metrics/jvm

}

grabCPUInfo
grabMemInfo
grabDiskUsage
grabInboundESTConnections
CloseWait_Connection_Count
getMaxMysqlConnections
fileHandlerStuff
spitOutLog
#invokeJVMMetricsAPI
echo
exit 0
