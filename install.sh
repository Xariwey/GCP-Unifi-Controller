#!/bin/bash
#########################################
###                                   ###
###              Optional             ###
###     Fill this values and save     ###
###                                   ###
#########################################
# https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
timezone=
ddnsurl=
dnsname=

#####################################################################################
#####################################################################################
#####################################################################################

###########################################
###                                     ###
###             Warning                 ###
###  Do not change nothing from here on ###
###     Unless u know what ur doing     ###
###                                     ###
###########################################
clear
account=$(gcloud config get core/account)
project=$(gcloud config get core/project)
region=$(gcloud config get compute/region)
zone=$(gcloud config get compute/zone)
bucket=$project-bucket
scripturl=https://raw.githubusercontent.com/Xariwey/GCP-Unifi-Controller/master/startup2.sh
name=unifi-controller
actions=("Change Project ID" "Change Region/Zone" "Continue")
PS3="Select an Option: "

function projects() {
	echo "Current Project ID: $project"
	echo
	echo "Select a Project from the list:"
	select project in $(gcloud projects list --format="value(projectId)"); do
		[ -z $project ] || break
	done
	echo
	echo "Setting Project ID"
	gcloud config set core/project $project
	sleep 2
	clear
}

function regions() {
	echo "Current Region: $region"
	echo
	echo "Select a Global Region from the list:"
	select global in "us" "northamerica" "southamerica" "europe" "asia" "australia" "me"; do
		[ -z $global ] || break
	done
	echo
	echo "Filtering Regions by $global"
	echo
	echo "Select a Region from the list:"
	select region in $(gcloud compute regions list --filter=name=$global --format="value(name)"); do
		[ -z $region ] || break
	done
	echo
	echo "Setting Compute Region"
	gcloud config set compute/region $region
	echo
	zones
}

function zones() {
	echo "Current Zone: $zone"
	echo
	echo "Select a Zone from the list:"
	select zone in $(gcloud compute zones list --filter=region=$region --format="value(name)"); do
		[ -z $zone ] || break
	done
	echo
	echo "Setting Compute Zone"
	gcloud config set compute/zone $zone
	echo
	sleep 2
	clear
}

function install() {
	echo "Starting"
	echo
	echo "Creating Storage Bucket"
	gcloud storage buckets create gs://$bucket \
		--location=$region \
		--default-storage-class=standard \
		--public-access-prevention

	echo
	echo "Creating Firewall Rules for HTTP"
	gcloud compute firewall-rules create "$name-http" \
		--allow=tcp:80,tcp:8880 \
		--description="Ports used for HTTP https://help.ubnt.com/hc/en-us/articles/218506997-UniFi-Ports-Used" \
		--target-tags=$name

	echo
	echo "Creating Firewall Rules for HTTPS"
	gcloud compute firewall-rules create "$name-https" \
		--allow=tcp:443,tcp:8443,tcp:8843,udp:443 \
		--description="Ports used for HTTP and HTTPS https://help.ubnt.com/hc/en-us/articles/218506997-UniFi-Ports-Used" \
		--target-tags=$name

	echo
	echo "Creating Firewall Rules for Device Inform"
	gcloud compute firewall-rules create "$name-inform" \
		--allow=tcp:8080 \
		--description="Port for device and controller communication https://help.ubnt.com/hc/en-us/articles/218506997-UniFi-Ports-Used" \
		--target-tags=$name

	echo
	echo "Creating Firewall Rules for Devie STUN"
	gcloud compute firewall-rules create "$name-stun" \
		--allow=udp:3478 \
		--description="Port used for STUN https://help.ubnt.com/hc/en-us/articles/218506997-UniFi-Ports-Used" \
		--target-tags=$name

	echo
	echo "Creating Firewall Rules for SpeedTest"
	gcloud compute firewall-rules create "$name-throughput" \
		--allow=tcp:6789 \
		--description="Port used for UniFi mobile speed test https://help.ubnt.com/hc/en-us/articles/218506997-UniFi-Ports-Used" \
		--target-tags=$name

	echo
	echo "Creating Firewall Rules for Guest Captive Portal"
	gcloud compute firewall-rules create "$name-captive" \
		--allow=tcp:53,udp:53 \
		--description="Port used for UniFi Guest Portal https://help.ubnt.com/hc/en-us/articles/218506997-UniFi-Ports-Used" \
		--target-tags=$name

	echo
	echo "Creating the VM"
	gcloud compute instances create $name-vm \
		--description="Unifi Server Controller" \
		--machine-type=e2-micro \
		--image-family=debian-12 \
		--image-project=debian-cloud \
		--boot-disk-device-name=$name-bootdisk \
		--boot-disk-type=pd-standard \
		--boot-disk-size=30GB \
		--tags=$name \
		--scopes=default,storage-full \
		--shielded-secure-boot \
		--shielded-vtpm \
		--shielded-integrity-monitoring \
		--reservation-affinity=none \
		--labels=["goog-ops-agent-policy"="v2-x86-template-1-3-0"]
		--metadata=startup-script-url=$scripturl,ddns-url=$ddnsurl,timezone=$timezone,dns-name=$dnsname,bucket=$bucket

	echo
	echo "Reserving IPv4"
	ipv4=$(gcloud compute instances describe $name-vm --format="get(networkInterfaces[0].accessConfigs[0].natIP)")
	gcloud compute addresses create $name-ipv4 \
		--addresses=$ipv4

#	echo
#	echo "Enabling VM Manager"
#	gcloud services enable containeranalysis.googleapis.com
#	curl -sSO https://cloud.google.com/static/stackdriver/docs/set-permissions.sh
#	(bash set-permissions.sh --project=$project)
#
	echo
	echo "Enabling Ops Agent"
	cat > agents_to_install.csv <<_EOF
"projects/${project}/zones/$zone/instances/$name-vm","[{""type"":""ops-agent""}]"
_EOF
	curl -sSO https://dl.google.com/cloudagents/mass-provision-google-cloud-ops-agents.py
#	python3 mass-provision-google-cloud-ops-agents.py --file agents_to_install.csv

	echo
	echo "Creating Auto Patch Deployment for the $name VM"
	cat > $name-vm_patch_deployment.json <<_EOF
{
  "description": "$name VM Auto Patch-Deployments",
  "instanceFilter": {
    "instances": ["zones/$zone/instances/$name-vm"]
  },
  "patchConfig": {
    "rebootConfig": "DEFAULT",
    "apt": {
      "type": "UPGRADE"
    },
    "yum": {
    },
    "zypper": {
    },
    "windowsUpdate": {
    }
  },
  "duration": "3600s",
  "recurringSchedule": {
    "timeZone": {
      "id": "$timezone"
    },
    "timeOfDay": {
      "hours": 4
    },
    "frequency": "WEEKLY",
    "weekly": {
      "dayOfWeek": "MONDAY"
    }
  },
  "rollout": {
    "mode": "ZONE_BY_ZONE",
    "disruptionBudget": {
      "fixed": 1
    }
  },
  "state": "ACTIVE"
}
_EOF
	gcloud compute os-config patch-deployments create $name-vm \
	--file=$name-vm_patch_deployment.json

	echo
	echo "Done go to http://$dnsname to finish the setup"
}

function menu() {
	while true; do
		echo "Current Configuration"
		echo
		echo "Account            : $account"
		echo "Project ID         : $project"
		echo "Region             : $region"
		echo "Zone               : $zone"
		echo "Startup Script URL : $scripturl"
		echo "Timezone           : $timezone"
		echo "DDNS URL           : $ddnsurl"
		echo "Domain Name        : $dnsname"
		echo
		if [ -z $timezone ] || [ -z $ddnsurl ] || [ -z $dnsname ]; then
			echo "Edit this file and fill the optional values to fully setup"
			echo "the Unifi Controller using a Domain Name with SSL"
			echo
		fi

		select action in "${actions[@]}" Quit; do
	    case $REPLY in
  	   	1) clear; projects; break;;
    	 	2) clear; regions; break;;
				$((${#actions[@]})))
					echo
					echo "If the information is correct"
					echo "This will enable and crete the required GCP products."
					echo
					read -t 15 -N 1 -p "Continue (y/N)? " answer
					echo 
					if [ "${answer,,}" == "y" ]
						then install; break 2
					fi; clear; break;;
     		$((${#actions[@]}+1))) break 2;;
     		*) clear; break;;
			esac
		done
	done
}

menu
echo "Exiting"
exit
