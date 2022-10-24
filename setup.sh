#!/bin/sh

clear
account=$(gcloud config get core/account)
project=$(gcloud config get core/project)
region=$(gcloud config get compute/region)
zone=$(gcloud config get compute/zone)
actions=("Change Project ID" "Change Region/Zone")
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

function menu() {
	while true; do
		echo "Current Configuration"
		echo
		echo "Account            : $account"
		echo "Project ID         : $project"
		echo "Region             : $region"
		echo "Zone               : $zone"
		echo
		select action in "${actions[@]}" Quit; do
	    case $REPLY in
  	   	1) clear; projects; break;;
    	 	2) clear; regions; break;;
     		$((${#actions[@]}+1))) break 2;;
     		*) clear; break;;
			esac
		done
	done
}

menu
echo
echo "If the information is correct, run the install script"
exit
