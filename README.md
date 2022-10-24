# Script to install Unifi Controller in a GCP - Compute Engine

## Instructions

* Login to GCP if u dont have an accoutn yet then create one,
-- https://console.cloud.google.com
* Create a new Project,
-- https://console.cloud.google.com/projectcreate
* Open a the Shell Console,
-- https://shell.cloud.google.com
* Inside the console clone this Git repository, and cd to it
```sh
$ git clone https://github.com/Xariwey/GCP-Unifi-Controller.git

$ cd GCP-Unifi-Controller
```
* Setup the project enviroment, OPTIONAL
```sh
$ bash setup.sh
```
* Configure, Create, Deploy and Start, the required GCP APIs that the Unifi controller needs to run,
```sh
$ bash install.sh
```
### For instructions on how to manually set up an UniFi controller on Google Cloud Platform see
https://metis.fi/en/2018/02/unifi-on-gcp/

### Credits to Petri
* https://github.com/riihikallio/unifi.git
