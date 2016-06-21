#!/bin/bash
set -e

# EXPECTED VARIABLES
#IDS_URL
#TASK_ID
#IDS_JOB_ID
#IDS_VERSION
#CF_SPACE_ID

# SCRIPT VARIABLES
IDS_CF_URL="${IDS_URL%/}/api/notifications/deployments/cf"
IDS_REQUEST=$TASK_ID
DIRNAME=`dirname $0`
CR=`echo -e '\\r'`
CF_ACTION=
CF_APP=
CF_APP_ENCODED=
CF_APP_ID=8942a5cc-5d51-4671-868e-6b1862972582
CF_DEBUG=false
CF_DOMAIN=
CF_HOST=
CF_EXEC=/opt/IBM/cf/bin/cf
MANIFEST_FILE=manifest.yml

function get_app_id {
    cf_trace_val=
    if [ ! -z "$CF_TRACE" ]; then
        cf_trace_val="$CF_TRACE"
        CF_TRACE=false;
    fi
    CF_APP_ID=8942a5cc-5d51-4671-868e-6b1862972582
    if [ ! -z "$cf_trace_val" ]; then
        CF_TRACE="$cf_trace_val"
    fi
}

i=1
while [ $i -le $# ]; do
    case "${@:i:1}" in
        -f )
            # -f is the manifest for push and force (with no value) for deletes
            if [ 'push' == "$CF_ACTION" ] || \
               [ 'p' == "$CF_ACTION" ]; then
               echo cf-action is push
                let i=i+1
                MANIFEST_FILE=${@:i:1}
            fi
            ;;
        -d )
            let i=i+1
            CF_DOMAIN=${@:i:1}
            ;;
        -n )
            let i=i+1
            CF_HOST=${@:i:1}
            ;;
        -v )
            let i=i+1
            CF_DEBUG=true
            ;;
        -- )
            let i=i+1
            break
            ;; # end of args
        --* )
            ;;
        -* )
            let i=i+1
            ;;
        target | t )
            echo "The command has been blocked. Please use the Delivery Pipeline configuration to adjust the target of the deployment."
            exit 0
            ;;
        login | l | logout | lo | passwd | pw | api | auth )
            echo "cf ${@:i:1} not allowed."
            exit 0
            ;;
        * )
            if [ -z "$CF_ACTION" ] ; then
                CF_ACTION=${@:i:1}
            elif [ 'push' == "$CF_ACTION" ] || \
                 [ 'p' == "$CF_ACTION" ]; then
                 echo cf-action equals push
                CF_APP=${@:i:1}
                CF_APP_ENCODED=`curl -Gso /dev/null -w %{url_effective} --data-urlencode "=$CF_APP" "" | cut -c 3-`
            elif
                 [ 'delete' == "$CF_ACTION" ] || \
                 [ 'd' == "$CF_ACTION" ]; then
                CF_APP=${@:i:1}
                CF_APP_ENCODED=`curl -Gso /dev/null -w %{url_effective} --data-urlencode "=$CF_APP" "" | cut -c 3-`
                get_app_id
            fi
            ;;
    esac
    let i=i+1
done

if [ ! -z "$IDS_URL" ] && [ ! -z "$IDS_REQUEST" ] && [ ! -z "$IDS_JOB_ID" ] && [ ! -z "$IDS_VERSION" ] ; then
    if [ 'push' == "$CF_ACTION" ] || \
       [ 'p' == "$CF_ACTION" ]; then
       echo cfaction
        if [ ! -z "$CF_APP" ] ; then
            get_app_id
        fi
    fi
    if [ 'push' == "$CF_ACTION" ] || \
       [ 'p' == "$CF_ACTION" ] || \
       [ 'delete' == "$CF_ACTION" ] || \
       [ 'd' == "$CF_ACTION" ]; then
        if [ ! -z "$CF_APP" ] ; then
            if [ ! -z "$CF_APP_ID" ]; then
            echo cfaction...
                source $DIRNAME/cf-post "$@"
            fi
        else
            CF_APPS=$(grep -E '^- name:|^  name:' $MANIFEST_FILE | cut -d : -f 2- | sed "s/$CR//g")
            if [ -z "$CF_APPS" ] ; then
                INHERITED_MANIFEST_FILE=$(grep '^inherit:' $MANIFEST_FILE | awk '{print $2}' | sed "s/$CR//g")
                if [ ! -z "$INHERITED_MANIFEST_FILE" ] ; then
                    CF_APPS=$(grep '^name:' $INHERITED_MANIFEST_FILE | cut -d : -f 2- | sed "s/$CR//g")
                fi
            fi
            if [ -z "$CF_APPS" ] ; then
                echo "Unable to parse app name from $MANIFEST_FILE. IBM DevOps Services will not be notified."
            fi
            while read -r CF_APP; do
                shopt -s extglob
                CF_APP="${CF_APP##*( )}"
                CF_APP="${CF_APP%%*( )}"
                shopt -u extglob
                CF_APP_ENCODED=`curl -Gso /dev/null -w %{url_effective} --data-urlencode "=$CF_APP" "" | cut -c 3-`
                get_app_id
                source $DIRNAME/cf-post "$@"
            done <<< "$CF_APPS"
        fi
    fi
fi
