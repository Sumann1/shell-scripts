#!/bin/bash

instance_id=$1

echo "Terminating instance:" $instance_id

aws ec2 terminate-instances --instance-ids $instance_id
