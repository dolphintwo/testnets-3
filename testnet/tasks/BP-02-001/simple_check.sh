#!/bin/bash
# crontab全节点状态监控
# */2 * * * *

# 钉钉webhook
hook_url="https://oapi.dingtalk.com/robot/send?access_token=**********"

# 主机信息
Date=`date +%Y-%m-%d`
Date_time=`date "+%Y-%m-%d %H:%M:%S"`
Host_name=`hostname`
IP_addr=`curl -s ifconfig.me`

# 日志目录
log_path="/var/tmp"

# 服务状态
port="8551"
ken_status=`sudo netstat -lntup |grep -w "$port" |wc -l`':ken'
statcode=`echo $ken_status | awk -F ':' '{print $1}'`
name=`echo $ken_status | awk -F ':' '{print $2}'`
touch ${log_path}/ken_state.log
old_statcode=`head -n 1 ${log_path}/ken_state.log`

# 本地高度
hex_local_high=`curl -s -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"klay_blockNumber","params":[],"id":83}' localhost:8551 |jq -r .result`
local_high=$[16#${hex_local_high:2}]
# 浏览器高度
hex_remote_high=`curl -s -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"klay_blockNumber","params":[],"id":83}' https://public-node-api.klaytnapi.com/v1/cypress |jq -r .result`
remote_high=$[16#${hex_remote_high:2}]
# 高度差
high_diff=$[$remote_high - $local_high]
echo $high_diff

function SendDownMessageToDingding(){
    #发送服务宕机消息
    curl -s "${hook_url}" -H 'Content-Type: application/json' -d "{
     'msgtype': 'text',
     'text': {'content': '服务监控\n服务down，请尽快处理！\n巡查时间：${Date_time}\nIP地址：${IP_addr}\n主机名：${Host_name}\n'}
    }"
}

function SendUpMessageToDingding(){
    #发送服务启动消息
    curl -s "${hook_url}" -H 'Content-Type: application/json' -d "{
     'msgtype': 'text',
     'text': {'content': '服务监控\n服务已恢复正常运行！\n巡查时间：${Date_time}\nIP地址：${IP_addr}\n主机名：${Host_name}\n'},
    }"
}

function SendSyncMessageToDingding(){
    #发送区块同步消息
    curl -s "${hook_url}" -H 'Content-Type: application/json' -d "{
     'msgtype': 'text',
     'text': {'content': '服务监控\n高度差大于5！请立即查看问题！\n当前高度差为$high_diff\n巡查时间：${Date_time}\nIP地址：${IP_addr}\n主机名：${Host_name}\n'},
    }"
}

function SendExplorerMessageToDingding(){
    #发送浏览器同步消息
    curl -s "${hook_url}" -H 'Content-Type: application/json' -d "{
     'msgtype': 'text',
     'text': {'content': '服务监控\n浏览器高度落后大于5，请立即查看问题！\n当前高度差为$high_diff\n巡查时间：${Date_time}\nIP地址：${IP_addr}\n主机名：${Host_name}\n'},
    }"
}

function TestMsg(){
    SendDownMessageToDingding
    SendUpMessageToDingding
    SendSyncMessageToDingding
    SendExplorerMessageToDingding
}

# 服务判断
if [ $statcode -lt 1 ]
then
	if [ $old_statcode -lt 1 ]
	then echo "$Date_time [ERROR] Kend is still stopped! Status_code=$statcode"
	else
		echo "$Date_time [ERROR] Kend is stopped! Status_code=$statcode, Send ERROR Message.."
		SendDownMessageToDingding
    fi
else
	if [ $old_statcode -ge 1 ]
	then echo "$Date_time [INFO] Kend is still running normally! Status_code=$statcode"
	else
		echo "$Date_time [INFO] Kend returned to normal function! Status_code=$statcode, Send Back Message.."
		SendUpMessageToDingding
    fi
fi
echo $statcode > ${log_path}/ken_state.log

# 高度判断
if  [ $high_diff -ge 5 ]
then
    echo "$Date_time [ERROR] Klaytn block high diff >= 5! now high_diff=$high_diff, Send Sync Message.."
    SendSyncMessageToDingding
else
    if [ $high_diff -lt -10 ]
    then
        echo "$Date_time [ERROR] Klaytn openapi may error! now high_diff=$high_diff, Send Message.."
        SendExplorerMessageToDingding
    else
        echo "$Date_time [INFO] Klaytn block high is normal! now high_diff=$high_diff"
    fi
fi

#TestMsg