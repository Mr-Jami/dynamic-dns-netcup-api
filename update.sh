#!/bin/bash

# Config
CUSTOMERNR="12345"
APIPASSWORD="abcdefghijklmnopqrstuvwxyz" 
APIKEY="abcdefghijklmnopqrstuvwxyz"
DOMAINLIST="myfirstdomain.com: server, dddns; myseconddomain.com: @, *, some-subdomain"
USE_IPV4=true
USE_IPV6=false
CHANGE_TTL=true
APIURL="https://ccp.netcup.net/run/webservice/servers/endpoint.php?JSON"

# Functions
function log_in() {
  curl -s -X POST -H 'Content-Type: application/json' --data '{"action":"login","param":{"customernumber":"'$CUSTOMERNR'","apikey":"'$APIKEY'","apipassword":"'$APIPASSWORD'"}}' $APIURL | jq -r '.responsedata.apisessionid' 
}

function log_out() {
  curl -s -X POST -H 'Content-Type: application/json' --data '{"action":"logout","param":{"customernumber":"'$CUSTOMERNR'","apikey":"'$APIKEY'","apisessionid":"'$1'"}}' $APIURL | jq '.status' | grep -q '^"success"'
}

function get_ip() {
  local ip=$(curl -s https://api.ipify.org)
  if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "$ip"
  else
    echo "Error getting IP" >&2
    exit 1
  fi
}

function get_ipv6() {
  local ip=$(curl -s https://ipv6.seeip.org) 
  if [[ $ip =~ ^[a-fA-F0-9:]+$ ]]; then
    echo "$ip"
  else
    echo "Error getting IPv6" >&2
    exit 1
  fi
}

function get_domains() {
  echo "${DOMAINLIST//;/ $'\n'}"
} 

function update_dns() {
  local domain=$1
  local subdomain=$2
  local ipv4=$3
  local ipv6=$4
  
  local apisessionid=$(log_in)

  local info=$(curl -s -X POST -H 'Content-Type: application/json' \
    --data '{"action":"infoDnsRecords","param":{"domainname":"'$domain'","customernumber":"'$CUSTOMERNR'","apikey":"'$APIKEY'","apisessionid":"'$apisessionid'"}}' \
    $APIURL)

  local record_exists=false
  if [[ $info =~ "\"hostname\":\"$subdomain\"" ]]; then
    record_exists=true
  fi  

  if [ "$record_exists" = false ]; then
    echo "Creating $subdomain record for $domain"
  else
    echo "Updating $subdomain record for $domain"
  fi

  # Update the record
  curl -s -X POST -H 'Content-Type: application/json' \
    --data '{"action":"updateDnsRecords","param":{"domainname":"'$domain'","customernumber":"'$CUSTOMERNR'","apikey":"'$APIKEY'","apisessionid":"'$apisessionid'","dnsrecordset":{"dnsrecords":[]}}}' \
    $APIURL

  log_out "$apisessionid"
}

# Main script

echo "Starting dynamic DNS update..."

ipv4=$(get_ip)

if [ "$USE_IPV6" = true ]; then
  ipv6=$(get_ipv6) 
fi

for domain_line in $(get_domains); do
  domain=$(echo $domain_line | cut -d':' -f1)
  subdomains=$(echo $domain_line | cut -d':' -f2)
  
  for subdomain in $subdomains; do
    update_dns "$domain" "$subdomain" "$ipv4" "$ipv6"
  done
done

echo "Update complete"
