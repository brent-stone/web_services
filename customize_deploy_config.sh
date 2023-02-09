#! /bin/bash
# stop execution instantly on non-zero status. This is to know location of error
set -e

############################################################
# Help                                                     #
############################################################
Help()
{
   # Display Help
   echo "Customize the AutoAI deployment configuration."
   echo
   echo "Syntax: customize [-h|-p|-d]"
   echo "options:"
   echo "-h           Print this Help."
   echo "-p {port}    Modify the HTTPS port the servers listen to."
   echo "-d {domain}  Modify the Top Level Domain is served from."
   echo
}

############################################################
# Collect Input and Pass to Initialization Script          #
############################################################

# Set variable default
HTTPS_PORT_NEW=443
DOMAIN_NEW="localhost"

# Get the options
while getopts "hp:d:" option; do
   case $option in
      h) # display Help
         Help
         exit;;
      p) # Customize the deployment HTTPS port
         HTTPS_PORT_NEW=$OPTARG;;
      d) # Customize the Top Level Domain
         DOMAIN_NEW=$OPTARG;;
     \?) # Invalid option
         echo "Error: Invalid option '${OPTARG}'"
         exit;;
   esac
done

RED='\033[0;31m'
NC='\033[0m' # No Color

confirm() {
  # Ensure there's understanding that existing configs and keys will be replaced
  echo -e "Except for passwords and secrets, all current AutoAI deployment configurations \
and keys will be ${RED}deleted and replaced with defaults or provided values.${NC}"
  read -r -p "Proceed? [y/N] " response
  # Exit if response anything other than a string explicitly starting with y or Y
  if ! [[ "$response" =~ [y|Y]+ ]]
  then
      echo "No changes made. Exiting..."
      exit;
  fi
}

# Ensure the reset is acceptable
confirm

# Export the requested customizations
export HTTPS_PORT_NEW
export DOMAIN_NEW

# Run the reset script
/bin/bash ./soft_reset.sh
