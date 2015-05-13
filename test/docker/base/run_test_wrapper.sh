#!/bin/bash
set -e

GALAXY_TEST_DATABASE_TYPE=${GALAXY_TEST_DATABASE_TYPE:-"postgres"}
if [ "$GALAXY_TEST_DATABASE_TYPE" = "postgres" ];
then
    su -c '/usr/lib/postgresql/9.3/bin/pg_ctl -o "-F" start -D /opt/galaxy/db' postgres
    sleep 3
    GALAXY_TEST_DBURI="postgres://root@localhost:5930/galaxy"
elif [ "$GALAXY_TEST_DATABASE_TYPE" = "mysql" ];
then
    sh /opt/galaxy/start_mysql.sh
    GALAXY_TEST_DBURI="mysql://galaxy:galaxy@localhost/galaxy?unix_socket=/var/run/mysqld/mysqld.sock"
elif [ "$GALAXY_TEST_DATABASE_TYPE" = "sqlite" ];
then
    GALAXY_TEST_DBURI="sqlite:////opt/galaxy/galaxy.sqlite"
else
	echo "Unknown database type"
	exit 1
fi
export GALAXY_TEST_DBURI

cd /galaxy
GALAXY_CONFIG_OVERRIDE_DATABASE_CONNECTION="$GALAXY_TEST_DBURI";
export GALAXY_CONFIG_OVERRIDE_DATABASE_CONNECTION

sh manage_db.sh upgrade

if [ -z "$GALAXY_NO_TESTS" ];
then
    sh run_tests.sh $@
else
    GALAXY_CONFIG_MASTER_API_KEY=${GALAXY_CONFIG_MASTER_API_KEY:-"testmasterapikey"}
    GALAXY_CONFIG_FILE=${GALAXY_CONFIG_FILE:-config/galaxy.ini.sample}
    GALAXY_CONFIG_CHECK_MIGRATE_TOOLS=false
    if [ -z "$GALAXY_MULTI_PROCESS" ];
    then
        GALAXY_CONFIG_JOB_CONFIG_FILE=${GALAXY_CONFIG_JOB_CONFIG_FILE:-config/job_conf.xml.sample}
    else
        GALAXY_CONFIG_JOB_CONFIG_FILE=/etc/galaxy/job_conf.xml
    fi
    GALAXY_CONFIG_FILE_PATH=${GALAXY_CONFIG_FILE_PATH:-/tmp/gx1}
    GALAXY_CONFIG_NEW_FILE_PATH=${GALAXY_CONFIG_NEW_FILE_PATH:-/tmp/gxtmp}

    export GALAXY_CONFIG_MASTER_API_KEY
    export GALAXY_CONFIG_FILE
    export GALAXY_CONFIG_CHECK_MIGRATE_TOOLS
    export GALAXY_CONFIG_JOB_CONFIG_FILE
    export GALAXY_CONFIG_FILE_PATH
    export GALAXY_CONFIG_NEW_FILE_PATH

    if [ -z "$GALAXY_MULTI_PROCESS" ];
    then
        sh run.sh $@
    else
        /usr/bin/supervisord
    fi
fi
