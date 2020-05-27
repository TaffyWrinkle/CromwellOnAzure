#!/bin/bash
# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

set -o errexit
set -o nounset

readonly log_file="/cromwellazure/startup.log"
touch $log_file
exec 1>$log_file
exec 2>&1

function write_log() {
    # Prepend the parameter value with the current datetime, if passed
    echo ${1+$(date --iso-8601=seconds) $1}
}

storage_account_name=$(grep -Po "(?<=DefaultStorageAccountName=).*$" .env)

write_log "CromwellOnAzure startup log"
write_log

write_log "mount_containers.sh:"
cd /cromwellazure
./mount_containers.sh -a $storage_account_name
write_log

write_log "Mounted blobfuse containers:"
findmnt -t fuse
write_log

docker_compose_files=(docker-compose-*.yml)
docker_compose_file_args="$(printf -- "-f \"%s\" " "${docker_compose_files[@]}")"
docker_compose_pull_command="docker-compose $docker_compose_file_args pull --ignore-pull-failures"
docker_compose_up_command="docker-compose $docker_compose_file_args up -d"

write_log "Running $docker_compose_pull_command"
eval $docker_compose_pull_command
write_log

write_log "Running $docker_compose_up_command"
mkdir -p /cromwellazure/cromwell-tmp
eval $docker_compose_up_command
write_log

write_log "Startup complete"

# Keep the process running and call mount periodically to remount volumes that were dropped due to blobfuse crash
while true; do  
    sleep 30  
    mount -a -t fuse || write_log "mount error code: $?" 
done 
