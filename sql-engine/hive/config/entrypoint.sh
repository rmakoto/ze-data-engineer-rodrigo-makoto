#!/bin/bash

sh -c ./entrypoint.sh

schematool -dbType postgres -initSchema

exec $@
