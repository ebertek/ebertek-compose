#!/bin/sh
file="/var/packages/ActiveInsight/target/configs/resource_monitor.json"
key="enable_file_activity_module"
if grep "enable_file_activity_module\": true" "$file"; then
	sed -i "s/${key}\": true/${key}\": false/g" "$file"
	synopkg restart ActiveInsight
fi
