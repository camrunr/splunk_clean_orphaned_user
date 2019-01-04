#!/bin/bash
ORIG_OWNER=$1
NEW_OWNER=$2
DO_IT=$3

# grab auth
if [ -f /tmp/.splunkadmin ]
then
   AUTH=`cat /tmp/.splunkadmin`
else
   read -p "User: " USER
   read -sp "Pass: " PW
   echo
   AUTH="$USER:$PW"
fi

# where are the apps to check?
SPLUNK_APPS=/app/splunk/etc/apps

# where are the user dirs?
SPLUNK_USERS=/app/splunk/etc/users

# where are we archiving the user dirs?
OLD_DIR=~/old-dir

# only run if the args pass some basic lint
if [[ "$ORIG_OWNER" =~ ^[-_a-zA-Z0-9]{2,}$ ]] && [[ "$NEW_OWNER" =~ ^[-_a-zA-Z0-9]{2,}$ ]]
then
    echo checking meta files with $ORIG_OWNER ...
    for FILE in `egrep "^owner = $ORIG_OWNER$" $SPLUNK_APPS/*/metadata/* | cut -d':' -f 1 | sort | uniq`
    do
       # only make changes if COMMIT was the 3rd option
       if [ "$DO_IT" == "COMMIT" ]
       then
          echo replacing $ORIG_OWNER with $NEW_OWNER in all meta files
          perl -pi -e "s/^owner = $ORIG_OWNER$/owner = $NEW_OWNER/" $FILE
       else
          echo $FILE contains owner = $ORIG_OWNER
       fi
    done

    # only make changes if COMMIT was the 3rd option
    echo checking user dirs for $ORIG_OWNER...
    if [ "$DO_IT" == "COMMIT" ] && [ -e $SPLUNK_USERS/$ORIG_OWNER ]
    then
       if ! [ -e $OLD_DIR ]
       then
          echo making $OLD_DIR directory
          mkdir $OLD_DIR
       fi
       echo creating tarball $OLD_DIR/$ORIG_OWNER.tgz ...
       if tar -C $SPLUNK_USERS -czf $OLD_DIR/$ORIG_OWNER.tgz $ORIG_OWNER
       then
          rm -rf $SPLUNK_USERS/$ORIG_OWNER
       else
          echo tar failed, dir not removed
       fi
       echo removing $ORIG_OWNER from SavedSearchHistory collection cuz bug SPL-134750
       for sid in `splunk _internal call /servicesNS/nobody/system/storage/collections/data/SavedSearchHistory/ -auth $AUTH\
           | grep $ORIG_OWNER | cut -d'"' -f 4 | xxd -plain | tr -d '\n' | sed 's/\(..\)/%\1/g' | sed -e 's/%0a/\n/g'`
         do
            splunk _internal call /servicesNS/nobody/system/storage/collections/data/SavedSearchHistory/$sid -method DELETE
       done

    else
       # well, we're not commit'd but at least check to see what's there
       if [ -e $SPLUNK_USERS/$ORIG_OWNER ]
       then
          echo $SPLUNK_USERS/$ORIG_OWNER exists
       fi
    fi

else
    echo
    echo ERROR invalid orig_owner or new_owner specified
    echo
    echo -e "\tusage: clean_orphaned_user.sh orginial_owner new_owner \[COMMIT\]"
    echo
fi
