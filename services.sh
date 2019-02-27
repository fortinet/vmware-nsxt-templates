#!/bin/bash
##################################################################################################################
# Last Update: Feb 27, 2019
# quick curl for rest-api to provide basic services such as insert new service, configure, delete service.
#
# Can only handle one service at a time
#
#
#
##################################################################################################################

read -p "Enter Your NSX Server IP: " NSX
read -p "Enter Your NSX Username: " USER
read -s -p "Enter Your NSX Password: " PASS
MAX_TIME=360
CURL="curl -m $MAX_TIME -s"

# don't change below
#TMPFILE="/usr/tmp/`date +%s`_$$.html"
COOKIE="cookiejar"


##################################################################################################################
# configure the fgt service.
configure_fgtservice() {
    # retrieving the service ID first
    SID=$(curl -q -k -b $COOKIE -H "$(grep X-XSRF-TOKEN headers.txt)" https://$NSX/api/v1/serviceinsertion/services/ |  python -c "import sys,json; print json.load(sys.stdin)['results'][0]['id']")

    echo "Service ID: $SID"

    TARGET_ID=$(curl -k -b $COOKIE -H "\`grep X-XSRF-TOKEN headers.txt\`" https://$NSX/api/v1/serviceinsertion/services/"$SID"/service-instances/ | python -c "import sys,json; print json.load(sys.stdin)['results'][0]['deployed_to'][0]['target_id']")

    echo "Target Logical Router ID: $TARGET_ID"

    RUNID=$(curl -k -b $COOKIE -H "$(grep X-XSRF-TOKEN headers.txt)" https://$NSX/api/v1/serviceinsertion/services/"$SID"/service-instances/ | python -c "import sys,json; print json.load(sys.stdin)['results'][0]['id']")
    echo "Instance Run Time ID: $RUNID"

    sed "s/NEEDTOREPLACEME/$TARGET_ID/" new-section.json.orig > new-section.json
    echo "Insertion new section"
    SECTION_ID=$(curl -k -b $COOKIE -H "$(grep X-XSRF-TOKEN headers.txt)" -H "Content-Type: application/json" -d @new-section.json -X POST https://$NSX/api/v1/serviceinsertion/sections | python -c "import sys,json; print json.load(sys.stdin)['id']")
    echo "Section ID: $SECTION_ID"

    sed "s/NEEDTOREPLACEMEINSTANCE/$RUNID/" new-rule.json.orig > new-rule.json.tmp
    sed "s/NEEDTOREPLACEMELR/$TARGET_ID/" new-rule.json.tmp > new-rule.json
    # Now, after get the section id.  Needs to create rules
    echo "Creating new rule in the section ID $SECTION_ID"
    curl -k -b $COOKIE -H "$(grep X-XSRF-TOKEN headers.txt)" -H "Content-Type: application/json" -d @new-rule.json -X POST https://$NSX/api/v1/serviceinsertion/sections/"$SECTION_ID"/rules

}

##################################################################################################################
# insert new fgt service
insert_fgtservice() {
    #Insertion the service
    curl -k -b $COOKIE -H "$(grep X-XSRF-TOKEN headers.txt)" -H "Content-Type: application/json" -d @new-service.json -X POST https://$NSX/api/v1/serviceinsertion/services

}

##################################################################################################################
# delete existing fgt service
delete_fgtservice() {
    # Find out the Service ID
    SID=$(curl -q -k -b $COOKIE -H "$(grep X-XSRF-TOKEN headers.txt)" https://$NSX/api/v1/serviceinsertion/services/ |  python -c "import sys,json; print json.load(sys.stdin)['results'][0]['id']")

    echo "Service ID: $SID"
    if [ ! -z "$SID" ]; then
        scount=$(curl -k -b $COOKIE -H "$(grep X-XSRF-TOKEN headers.txt)" https://$NSX/api/v1/serviceinsertion/services/"$SID"/service-instances/ | python -c "import sys,json; print json.load(sys.stdin)['result_count']")
        #Deleting the service
        if [ "$scount" -eq '0' ]; then
            echo "Service $SID is not in used"
            echo "Deleting the service"
            curl -k -b $COOKIE -H "$(grep X-XSRF-TOKEN headers.txt)" -H "Content-Type: application/json" -X DELETE https://$NSX/api/v1/serviceinsertion/services/"$SID"?cascade=true
        else
            echo "TODO"
        fi
    else
        echo "No Service Existed"
    fi
}

##################################################################################################################
# help functin
usage ()
{
    echo "usage: rest-api.sh <insert|configure|delete|help>"
    echo "    insert - insert new service"
    echo "    configure - configure an existing deployed service"
    echo "    delete - delete existing service"
    echo "    Once Insert the service, user need to deloy the service manually"

}

##################################################################################################################
type=""
# Main function. parsing out the input
while [ "$1" != "" ]; do
    case $1 in
        insert )
            type=$1
            shift
            ;;
        configure )
            type=$1
            shift
            ;;
        delete )
            type=$1
            shift
            ;;
        help )
            type=$1
            usage
            exit
            ;;
        * )
            usage
            exit 1
    esac
    shift
done

# First, to create the session
# Grabbing COOKIE
$CURL -k -c $COOKIE -D headers.txt -X POST -d "j_username=$USER&j_password=$PASS" https://$NSX/api/session/create
echo "You choosed $type"
if [ "$type" != "" ]; then
    echo "Performing $1 operation"
    if [ "$type" == "insert" ]; then
        echo "Inserting New Service"
        insert_fgtservice
        exit
    elif [ "$type" == "configure" ]; then
        echo "Configuring Existing Service"
        configure_fgtservice
        exit
    elif [ "$type" == "delete" ]; then
        echo "Deleting existing service"
        delete_fgtservice
        exit
    else
        echo "Unknown operation.  EXITING!!!!!"
        exit
    fi
else
    usage
    exit
fi

rm -rf $COOKIE
