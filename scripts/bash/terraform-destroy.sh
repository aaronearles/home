#!/bin/bash
terraform -chdir=$1 destroy --auto-approve